# 🤖 IMPLEMENTATION GUIDE: AI Coach dengan Konteks MT5 Live (Update untuk Antigravity)

> **Target**: Antigravity (Agy)  
> **Prioritas**: 🔴 **Tinggi** — *Closing the loop* antara AI Analysis dan Real Account State  
> **File Terkait**: 
> - `aura_trading/lib/ai/prompts/trading_coach_prompt.dart`  
> - `aura_mobile/lib/src/providers/inference_provider.dart`  
> - `aura_desktop/lib/src/providers/inference_provider.dart`  
> - `aura_trading/lib/ai/context_builder.dart` (SUDAH ADA)  
> - `aura_trading/lib/ai/trading_tools.dart` (SUDAH ADA method `getAccountContext`)  

---

## 🎯 Tujuan
Agar **AI Coach (Local LLM)** bisa menjawab pertanyaan kontekstual seperti:
- *"Fadli, kamu masih punya posisi XAUUSD BUY 0.10 lot terbuka dengan floating -$45. Apakah aman menambah posisi?"*
- *"Equity kamu $9,850, margin used $1,200. Risk exposure saat ini 12%. Saran?"*
- *"Posisi GBPUSD SELL 0.05 lot sudah profit $80. Mau di-trail SL ke breakeven?"*

---

## ✅ 1. Status Implementasi Saat Ini (Sudah Dikerjakan)

| Komponen | File | Status |
|----------|------|--------|
| **Context Builder** | `aura_trading/lib/ai/context_builder.dart` | ✅ **LENGKAP** - Menyediakan `aiTradingContextProvider` yang fetch paralel data MT5 (account, posisi) dan watchlist prices |
| **Trading Tools** | `aura_trading/lib/ai/trading_tools.dart` | ✅ **LENGKAP** - Sudah ada method `getAccountContext` yang mengembalikan JSON dengan account info dan posisi terbuka |
| **System Prompt** | `aura_trading/lib/ai/prompts/trading_coach_prompt.dart` | ❌ **BELUM DIUBAH** - Masih menggunakan prompt statis tanpa placeholder `{live_context}` |
| **Inference Provider (Mobile)** | `aura_mobile/lib/src/providers/inference_provider.dart` | ❌ **BELUM DIUBAH** - Belum wiring untuk inject live context ke system prompt |
| **Inference Provider (Desktop)** | `aura_desktop/lib/src/providers/inference_provider.dart` | ❌ **BELUM DIUBAH** - Belum wiring untuk inject live context ke system prompt |

---

## 🔧 2. Perubahan yang Perlu Dikerjakan Antigravity

### ✅ Perubahan 1: Update System Prompt (trading_coach_prompt.dart)
**File**: `aura_trading/lib/ai/prompts/trading_coach_prompt.dart`  
**Ubah**: Tambahkan placeholder `{live_context}` di awal system prompt

**Sebelum:**
```dart
static const String systemPrompt = '''
Anda adalah AURA Trading Coach — pendamping AI cerdas, disiplin, dan berfokus pada edukasi serta Manajemen Risiko untuk trading Forex, Gold (XAU/USD), dan Saham IDX.

**ATURAN WAJIB — GROUNDING DATA:** [...]
**PRINSIP KEAMANAN UTAMA — MANUSIA ADALAH PEMICU AKHIR (HUMAN-IN-THE-LOOP):''
...
''';
```

**Sesudah:**
```dart
static const String systemPrompt = '''
Anda adalah AURA Trading Coach — pendamping AI cerdas, disiplin, dan berfokus pada edukasi serta Manajemen Risiko untuk trading Forex, Gold (XAU/USD), dan Saham IDX.

**KONTEKS LIVE (OTOMATIS DIINJEK):**
{live_context}

**ATURAN WAJIB — GROUNDING DATA:** [...]
**PRINSIP KEAMANAN UTAMA — MANUSIA ADALAH PEMICU AKHIR (HUMAN-IN-THE-LOOP):''
...
''';
```

### ✅ Perubahan 2: Wiring ke Inference Provider (Mobile & Desktop)
**Files**: 
- `aura_mobile/lib/src/providers/inference_provider.dart`
- `aura_desktop/lib/src/providers/inference_provider.dart`

**Tambahkan Import** (di bagian atas file):
```dart
import 'package:aura_trading/aura_trading.dart';
```

**Ubah Class `InferenceNotifier`** - Tambahkan method helper dan modifikasi `generate()`:

**Tambahkan method ini di dalam class `InferenceNotifier`** (di atas atau bawah method `build()`):
```dart
/// Mengambil konteks live MT5 dan market data untuk disisipkan ke system prompt AI Coach.
Future<String> _fetchLiveTradingContext() async {
  try {
    // Akses provider dari aura_trading package melalui ref.watch
    final context = await ref.read(aiTradingContextProvider.future);
    return context.toPromptContext();
  } catch (e) {
    // Fallback jika terjadi error (misal: MT5 offline)
    return '''
=== AKUN MT5 (LIVE) ===
Status: Tidak dapat mengakses data live MT5. Pastikan bridge python berjalan dan MT5 terminal terbuka.
=== POSISI TERBUKA ===
Data tidak tersedia
=== HARGA PASAR (WATCHLIST) ===
Data tidak tersedia

Timestamp Data: Data tidak tersedia
''';
  }
}
```

**Ubah method `generate()`** - Sisipkan konteks live ke system prompt:

**Cari method `generate()`** dan ubah bagian di dalamnya seperti ini:

**Sebelum (hanya contoh struktur):**
```dart
@override
Future<void> generate({
  required String prompt,
  String? systemPrompt,
  int maxTokens = 512,
  double temperature = 0.7,
  double topP = 0.9,
  int topK = 40,
  double repeatPenalty = 1.1,
}) async {
  // ... kode existing untuk memanggil model inference
}
```

**Sesudah:**
```dart
@override
Future<void> generate({
  required String prompt,
  String? systemPrompt,
  int maxTokens = 512,
  double temperature = 0.7,
  double topP = 0.9,
  int topK = 40,
  double repeatPenalty = 1.1,
}) async {
  // 1. AMBIL KONTEKS LIVE MT5 DAN MARKET DATA
  final liveContext = await _fetchLiveTradingContext();

  // 2. SISIPKAN KONTEKS LIVE KE SYSTEM PROMPT TRADING COACH
  final baseSystemPrompt = TradingCoachPrompt.systemPrompt;
  final systemPromptWithLiveContext = baseSystemPrompt.replaceAll('{live_context}', liveContext);

  // 3. GABUNGKAN DENGAN SYSTEM PROMPT CUSTOM JIKA ADA (OPSIONAL)
  final effectiveSystemPrompt = systemPrompt != null && systemPrompt.isNotEmpty
      ? '$systemPromptWithLiveContext\n\nCustom Instructions: $systemPrompt'
      : systemPromptWithLiveContext;

  // 4. LANJUTKAN DENGAN PROSES GENERATE NORMAL (tanpa perubahan lain)
  final modelState = ref.read(modelProvider);
  if (!modelState.isReady || modelState.activeModel == null) {
    state = state.copyWith(
      status: InferenceStatus.error,
      errorMessage: 'Tidak ada model GGUF yang aktif. Silakan muat model terlebih dahulu.',
    );
    return;
  }

  // Cancel any previous stream
  await stop();

  // Recall relevant semantic memories for this prompt
  final memories = await ref.read(memoryProvider.notifier).recall(prompt, topK: 3);
  final memoryContext = await MemoryNotifier.formatMemoriesForPrompt(memories);

  // Inject memories into system prompt if available
  String effectiveSystemPromptWithMemory = effectiveSystemPrompt;
  if (memoryContext.isNotEmpty) {
    effectiveSystemPromptWithMemory = memoryContext + (effectiveSystemPromptWithMemory.isNotEmpty ? '\n$effectiveSystemPromptWithMemory' : '');
  }

  // Cloud Routing Check (Fase 14) - tetap seperti sebelumnya
  if (state.useCloudAssistant) {
    // ... kode existing untuk cloud assistant tetap sama
    return;
  }

  // Hybrid Routing Check (Fase 12) - tetap seperti sebelumnya
  bool isDesktopUsed = false;
  String desktopUrl = '';
  
  if (settings.useDesktopAssistant && settings.desktopIp.isNotEmpty) {
    desktopUrl = 'http://${settings.desktopIp}:${settings.desktopPort}';
    try {
      final pingRes = await http.get(
        Uri.parse('$desktopUrl/v1/models'),
        headers: {
          if (settings.desktopPin.isNotEmpty) 'Authorization': 'Bearer ${settings.desktopPin}',
        },
      ).timeout(const Duration(seconds: 2));
      if (pingRes.statusCode == 200) {
        isDesktopUsed = true;
      }
    } catch (_) {
      // Fail silent -> fallback to local
    }
  }

  if (isDesktopUsed) {
    // ... kode existing untuk desktop assistant tetap sama
    return;
  }

  // LOCAL INFERENCE - INI BAGIAN YANG PERLU DIUBAH
  final formattedPrompt = formatPrompt(
    prompt,
    systemPrompt: effectiveSystemPromptWithMemory.isNotEmpty ? effectiveSystemPromptWithMemory : null,
  );

  state = InferenceState(
    status: InferenceStatus.generating,
    prompt: prompt,
    text: '',
    metrics: const InferenceMetrics(),
    useCloudAssistant: state.useCloudAssistant,
  );

  _stopwatch = Stopwatch()..start();
  int tokenCount = 0;
  Duration? timeToFirstToken;

  final controller = ref.read(modelProvider.notifier).controller;

  try {
    final tokenStream = controller.generate(
      prompt: formattedPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: topP,
      topK: topK,
      repeatPenalty: repeatPenalty,
    );

    final buffer = StringBuffer();

    _streamSub = tokenStream.listen(
      (token) {
        tokenCount++;
        if (tokenCount == 1 && _stopwatch != null) {
          timeToFirstToken = _stopwatch!.elapsed;
        }

        buffer.write(token);
        final elapsed = _stopwatch?.elapsed ?? Duration.zero;
        final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
        final tps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

        final processedText = EmojiParser.replaceShortcodes(buffer.toString());

        state = state.copyWith(
          text: processedText,
          metrics: InferenceMetrics(
            tokensGenerated: tokenCount,
            tokensPerSecond: tps,
            elapsedDuration: elapsed,
            timeToFirstToken: timeToFirstToken,
          ),
        );
      },
      onDone: () {
        _stopwatch?.stop();
        final elapsed = _stopwatch?.elapsed ?? Duration.zero;
        final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
        final finalTps = elapsedSeconds > 0 ? (tokenCount / elapsedSeconds) : 0.0;

        state = state.copyWith(
          status: InferenceStatus.completed,
          text: EmojiParser.replaceShortcodes(buffer.toString()),
          metrics: state.metrics.copyWith(
            tokensGenerated: tokenCount,
            tokensPerSecond: finalTps,
            elapsedDuration: elapsed,
          ),
        );
      },
      onError: (error) {
        _stopwatch?.stop();
        state = state.copyWith(
          status: InferenceStatus.error,
          errorMessage: 'Inference Error: ${error.toString()}',
        );
      },
      cancelOnError: true,
    );
  } catch (e) {
    _stopwatch?.stop();
    state = state.copyWith(
      status: InferenceStatus.error,
      errorMessage: 'Gagal memulai inferensi: ${e.toString()}',
    );
  }
}
```

---

## ✅ 3. Verifikasi bahwa `aiTradingContextProvider` Bisa Diakses

Untuk memastikan bahwa `ref.read(aiTradingContextProvider.future)` bekerja di `inference_provider.dart`, pastikan:

1. **Di `aura_trading/lib/aura_trading.dart`** (File ekspor package) sudah ada:
   ```dart
   export 'ai/context_builder.dart' show aiTradingContextProvider;
   // ATAU
   export 'presentation/providers/mt5_provider.dart' show aiTradingContextProvider;
   ```

2. **Di `aura_mobile/pubspec.yaml` dan `aura_desktop/pubspec.yaml`** sudah ada dependensi:
   ```yaml
   dependencies:
     aura_trading:
       path: ../aura_trading
   ```

3. **Provider `aiTradingContextProvider` di `context_builder.dart`** didefinisikan sebagai:
   ```dart
   final aiTradingContextProvider =
       FutureProvider.autoDispose<AiTradingContext>((ref) async {
     // ... implementasi yang sudah ada
   });
   ```

---

## ✅ 4. Checklist Verifikasi untuk Antigravity

| Test Case | Expected Behavior |
|-----------|-------------------|
| **Tanya saat MT5 Offline** | AI harus menanggapi bahwa tidak bisa akses data live, tetapi tetap bisa memberikan edukasi umum (misal: penjelasan RSI) tanpa memberikan saran trading spesifik. |
| **Tanya saat ada posisi XAUUSD BUY 0.10 lot floating -$50** | AI harus menyebutkan posisi tersebut dalam jawaban, misal: "Saya lihat kamu punya posisi XAUUSD BUY 0.10 lot dengan floating loss -$50. Margin level kamu berapa? Jika ada posisi lain, pastikan total risiko tidak melebihi 2% dari equity." |
| **Tanya "Bisa buy GBPUSD?" saat margin level 150%** | AI harus memperingatkan tentang margin level yang rendah dan tidak menyarankan posisi baru tanpa penutupan posisi existente atau penambahan margin. |
| **Tanya "SL di mana untuk XAUUSD buy sekarang?"** | AI boleh memberikan saran berdasarkan struktur harga terkini (jika ada data candlestick dari context builder), tapi harus tetap menekankan bahwa keputusan akhir ada pada pengguna. |
| **System prompt terlihat dalam log** | Saat memeriksa log inference atau inspect state, system prompt yang dikirim ke LLM harus mengandung data akun dan posisi aktual dari MT5 (misal: "Balance: $10,250.50", "Position: #12345 XAUUSD BUY 0.10 lot"). |

---

## 🚀 5. Langkah Eksekusi untuk Antigravity

```bash
# 1. Pastikan semua file di atas sudah sesuai dengan petunjuk ini
# 2. Jalankan build_runner jika ada perubahan provider (biasanya tidak diperlukan karena kita hanya mengakses provider yang sudah ada)
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_trading
flutter pub run build_runner build --delete-conflicting-outputs  # Hanya jika diperlukan

# 3. Jalankan MT5 Bridge Python (di terminal terpisah)
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/tools/mt5_bridge
python mt5_service.py

# 4. Test di aplikasi desktop atau mobile
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_desktop  # atau ../aura_mobile
flutter run -d windows  # atau flutter run untuk mobile
```

---

## ⚠️ Catatan Penting untuk Antigravity

1. **Jangan ubah `aura_core`** — hanya kerja di `aura_trading`, `aura_mobile`, `aura_desktop`.
2. **Decimal wajib** untuk semua kalkulasi uang/lot (sudah benar di kode).
3. **Prinsip 5 non-negotiable**: Tidak ada auto-execute. Selalu dialog konfirmasi untuk order MT5.
4. **Token budget**: Konteks live ~300-500 token. Masih aman untuk context window 4k-8k dari model Lokal seperti Qwen2.5-7B atau Gemma2-9B.
5. **Privacy**: Data akun live HANYA dikirim ke **Local LLM** (tidak ke cloud kecuali user aktifkan cloud assistant toggle secara eksplisit).
6. **Fallback penting**: Jika terjadi error saat mengambil context (misal: MT5 bridge offline), sistem harus tetap memberikan respons yang berguna tanpa crash.

*Implementasi ini membuat AI Coach benar-benar "aware" kondisi real account — diferensiasi utama AURA vs chatbot biasa. Dengan ini, Fadli akan mendapatkan pendamping trading yang benar-benar paham situasi akun live-nya.* 