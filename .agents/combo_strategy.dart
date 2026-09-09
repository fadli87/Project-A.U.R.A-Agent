/// Combo strategy logic — port dari `internal/handlers/chat/combo.go`
/// (9router-go), disederhanakan jadi pure Dart tanpa dependency HTTP/DB.
///
/// Dipakai untuk memilih & merotasi urutan model (mis. "openai/gpt-4o",
/// "anthropic/claude-sonnet-4-6", "gemini/gemini-3.8-flash") saat A.U.R.A
/// punya lebih dari satu model remote yang bisa dipakai bergantian.
library combo_strategy;

/// Strategi rotasi model dalam satu combo.
enum ComboStrategy {
  /// Coba model pertama; kalau gagal, lanjut ke model berikutnya (default).
  fallback,

  /// Rotasi murni: setiap turn baru pindah ke model berikutnya.
  roundRobin,

  /// Rotasi dengan "menempel" [stickyLimit] turn berturut-turut sebelum
  /// pindah ke model berikutnya.
  sticky,

  /// Tidak dirotasi — urutan tetap seperti input (mis. untuk strategi
  /// berbasis kapasitas/quota yang di-handle di layer lain).
  capacity,
}

/// State rotasi untuk satu combo (identik dengan `comboStickyState` di Go).
///
/// Satu instance per nama combo — simpan di memori (mis. dalam
/// [ComboStrategyManager]) atau persist ke DB lokal kalau butuh survive
/// restart app.
class ComboStickyState {
  /// Index "pointer" rotasi berikutnya.
  int index = 0;

  /// Berapa kali model saat ini sudah dipakai berturut-turut.
  int consecutiveUseCount = 0;

  /// Index model yang benar-benar melayani turn saat ini (bisa beda dari
  /// [index] kalau turn masih berlangsung / mid-turn tool-call).
  int servingIndex = 0;
}

/// Kapabilitas yang bisa dibutuhkan oleh sebuah request.
enum ModelCapability { vision, pdf, audioInput, videoInput, tools }

/// Fungsi untuk mengecek apakah sebuah model entry ("provider/model")
/// punya kapabilitas tertentu. Implementasikan ini sesuai catalog model
/// A.U.R.A sendiri (mirip `providers.GetCapabilitiesForModel` di Go).
typedef CapabilityChecker = bool Function(
  String modelEntry,
  ModelCapability capability,
);

/// ---------------------------------------------------------------------
/// Capability detection — port dari DetectRequiredCapabilities /
/// scanMessageContent / scanContentBlock.
/// ---------------------------------------------------------------------
class CapabilityDetector {
  /// Deteksi kapabilitas yang dibutuhkan dari body request (format bebas:
  /// OpenAI `messages`, Claude `messages`, atau Responses API `input`).
  ///
  /// Hanya menyisir pesan user PALING AKHIR (turn terbaru) — sama seperti
  /// versi Go, supaya lampiran gambar/PDF di turn lama tidak terus memaksa
  /// model tertentu dipakai di turn-turn berikutnya.
  static Set<ModelCapability> detectRequired(Map<String, dynamic> body) {
    final required = <ModelCapability>{};

    final messages = body['messages'];
    if (messages is List) {
      _scanTrailingUserMessage(messages, required);
    }

    final input = body['input'];
    if (input is List) {
      _scanTrailingUserMessage(input, required);
    }

    final tools = body['tools'];
    if (tools is List) {
      for (final t in tools) {
        if (t is Map &&
            (t['type'] == 'function' ||
                t['function'] != null ||
                t['functionDeclarations'] != null)) {
          required.add(ModelCapability.tools);
          break;
        }
      }
    }

    return required;
  }

  static void _scanTrailingUserMessage(
    List<dynamic> messages,
    Set<ModelCapability> required,
  ) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg is Map && msg['role'] == 'user') {
        _scanMessageContent(msg, required);
        break;
      }
    }
  }

  static void _scanMessageContent(
    Map<dynamic, dynamic> msg,
    Set<ModelCapability> required,
  ) {
    final content = msg['content'];
    if (content is List) {
      for (final block in content) {
        _scanContentBlock(block, required);
      }
    }
    // content berupa String murni -> tidak ada modality yang bisa dideteksi.
  }

  static void _scanContentBlock(
    dynamic block,
    Set<ModelCapability> required,
  ) {
    if (block is! Map) return;

    switch (block['type']) {
      case 'image_url':
      case 'image':
      case 'input_image':
        required.add(ModelCapability.vision);
        break;
      case 'file':
      case 'document':
      case 'input_file':
        required.add(ModelCapability.pdf);
        break;
      case 'audio_url':
      case 'audio':
      case 'input_audio':
        required.add(ModelCapability.audioInput);
        break;
      case 'video_url':
      case 'video':
      case 'input_video':
        required.add(ModelCapability.videoInput);
        break;
    }

    _checkMimeType(block['mimeType'], required);

    for (final key in const ['inlineData', 'fileData']) {
      final nested = block[key];
      if (nested is Map) {
        _checkMimeType(nested['mimeType'], required);
      }
    }
  }

  static void _checkMimeType(dynamic mime, Set<ModelCapability> required) {
    if (mime is! String) return;
    if (mime.startsWith('image/')) {
      required.add(ModelCapability.vision);
    } else if (mime.startsWith('audio/')) {
      required.add(ModelCapability.audioInput);
    } else if (mime.startsWith('video/')) {
      required.add(ModelCapability.videoInput);
    } else if (mime == 'application/pdf') {
      required.add(ModelCapability.pdf);
    }
  }

  /// Reorder [comboModels] secara stabil: model yang memenuhi SEMUA
  /// [required] capability dipindah ke depan, sisanya tetap di urutan asli
  /// setelahnya. Port dari `ReorderByCapabilities`.
  static List<String> reorderByCapabilities(
    List<String> comboModels,
    Set<ModelCapability> required,
    CapabilityChecker hasCapability,
  ) {
    if (required.isEmpty || comboModels.length <= 1) return comboModels;

    final tier0 = <String>[];
    final tier1 = <String>[];

    for (final model in comboModels) {
      final allMatch = required.every((cap) => hasCapability(model, cap));
      (allMatch ? tier0 : tier1).add(model);
    }

    return [...tier0, ...tier1];
  }
}

/// ---------------------------------------------------------------------
/// Turn detection — port dari detectNewTurn / contentHasText.
///
/// Kenapa ini penting: model "thinking" (mis. Gemini) butuh tool-call di
/// turn yang sama diproses oleh model yang SAMA persis. Kalau combo pindah
/// model di tengah rangkaian tool-call, riwayatnya jadi tidak valid.
/// ---------------------------------------------------------------------
bool detectNewTurn(Map<String, dynamic> body) {
  final messages = body['messages'];
  if (messages is! List) return true;

  for (var i = messages.length - 1; i >= 0; i--) {
    final msg = messages[i];
    if (msg is! Map) continue;

    if (msg['role'] == 'tool') return false;
    if (msg['role'] != 'user') continue;

    return _contentHasText(msg['content']);
  }
  return true;
}

bool _contentHasText(dynamic content) {
  if (content is String) return content.isNotEmpty;
  if (content is List) {
    for (final part in content) {
      if (part is Map && part['text'] is String && (part['text'] as String).isNotEmpty) {
        return true;
      }
    }
  }
  return false;
}

/// ---------------------------------------------------------------------
/// ComboStrategyManager — port dari applyComboStrategy / ApplyComboStrategy.
///
/// Simpan satu instance ini selama app hidup (mis. sebagai singleton /
/// Riverpod provider), supaya state sticky per combo tetap konsisten
/// antar-request.
/// ---------------------------------------------------------------------
class ComboStrategyManager {
  final Map<String, ComboStickyState> _stickyState = {};

  /// Hitung ulang urutan [models] berdasarkan [strategy].
  ///
  /// - [comboName] : identitas combo (dipakai sebagai key state; boleh kosong
  ///   untuk combo tunggal / default).
  /// - [stickyLimit] : untuk strategi `sticky`, berapa turn berturut-turut
  ///   sebelum pindah model. Untuk `roundRobin`, otomatis dianggap 1.
  /// - [newTurn] : true kalau ini awal percakapan baru (bukan lanjutan
  ///   tool-call mid-turn) — biasanya hasil dari [detectNewTurn].
  List<String> apply({
    required ComboStrategy strategy,
    required List<String> models,
    String comboName = '',
    int stickyLimit = 1,
    bool newTurn = true,
  }) {
    if (models.length <= 1) return models;

    switch (strategy) {
      case ComboStrategy.roundRobin:
        return _applySticky(models, comboName, 1, newTurn);
      case ComboStrategy.sticky:
        return _applySticky(
          models,
          comboName,
          stickyLimit <= 1 ? 1 : stickyLimit,
          newTurn,
        );
      case ComboStrategy.fallback:
      case ComboStrategy.capacity:
        return List<String>.from(models);
    }
  }

  List<String> _applySticky(
    List<String> models,
    String comboName,
    int stickyLimit,
    bool newTurn,
  ) {
    final key = comboName.isEmpty ? '__default__' : comboName;
    final state = _stickyState.putIfAbsent(key, () => ComboStickyState());

    var servingIndex = state.index % models.length;

    if (newTurn) {
      state.consecutiveUseCount++;
      if (state.consecutiveUseCount >= stickyLimit) {
        state.index = (servingIndex + 1) % models.length;
        state.consecutiveUseCount = 0;
      }
      state.servingIndex = servingIndex;
    } else {
      servingIndex = state.servingIndex;
    }

    return List<String>.generate(
      models.length,
      (i) => models[(servingIndex + i) % models.length],
    );
  }

  /// Reset state rotasi satu combo (mis. dipanggil kalau user ganti/hapus
  /// konfigurasi combo dari UI).
  void resetState(String comboName) {
    final key = comboName.isEmpty ? '__default__' : comboName;
    _stickyState.remove(key);
  }
}
