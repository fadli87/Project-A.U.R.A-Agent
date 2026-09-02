# 🤖 OPTIMASI UNTUK MODEL LLM < 4B PARAMETER DI MOBILE

> **Target**: Antigravity (Agy)  
> **Kasus Penggunaan**: Mobile device dengan memori terbatas (model LLM < 4B parameter)  
> **Tujuan**: Memastikan AI Coach tetap berfungsi dengan baik nonostante batasan parameter model  
> **File yang Terkait**: 
> - `aura_trading/lib/ai/prompts/trading_coach_prompt.dart`
> - `aura_trading/lib/ai/trading_tools.dart`
> - `aura_trading/lib/ai/context_builder.dart`
> - `aura_mobile/lib/src/providers/inference_provider.dart`
> - `aura_desktop/lib/src/providers/inference_provider.dart`

---

## 🎯 Tantangan Utama untuk Model < 4B

Model dengan parameter di bawah 4B (seperti Phi-2, TinyLlama, atau quantized versi model lebih besar) memiliki keterbatasan:
1. **Kapasitas Konteks yang Lebih Kecil** → Sulit menahan banyak data sekaligus
2. **Kemampuan Reasoning yang Terbatas** → Kesulitan dalam multi-tool calling atau analisis kompleks
3. **Sensitivitas terhadap Format Prompt** → Memerlukan instruksi yang sangat spesifik dan terstruktur
4. **Kurangnya Kemampuan Abstrak** → Kesulitan dengan konsep yang terlalu abstrak atau implicit

Namun, dengan optimasi yang tepat, model di kisaran 2-4B parameter masih bisa memberikan nilai yang signifikan untuk use case trading assistant kita.

---

## 🔧 Strategi Optimasi Utama

### 1. **Sistem Klasifikasi Intent berbasis Rule (Mengganti Natural Language Understanding)**
Alih-alih mengandalkan LLM untuk memahami niat pengguna dan memilih tool yang tepat, kita implementasikan klasifikasi berbasis rule di lapisan aplikasi sebelum memanggil LLM.

**Implementasi di `inference_provider.dart`**:
```dart
// Tambahkan di dalam class InferenceNotifier
enum TradingIntent { priceCheck, technicalAnalysis, riskCalculation, accountInfo, generalChat }

TradingIntent _classifyIntent(String prompt) {
  final lowerPrompt = prompt.toLowerCase();
  
  // Price check intent
  if (lowerPrompt.contains('harga') || 
      lowerPrompt.contains('price') || 
      lowerPrompt.contains('berapa') ||
      lowerPrompt.contains('nilai') ||
      lowerPrompt.contains('quote')) {
    return TradingIntent.priceCheck;
  }
  
  // Technical analysis intent
  if (lowerPrompt.contains('rsi') || 
      lowerPrompt.contains('macd') || 
      lowerPrompt.contains('ema') ||
      lowerPrompt.contains('indikator') ||
      lowerPrompt.contains('trend') ||
      lowerPrompt.contains('support') ||
      lowerPrompt.contains('resistance')) {
    return TradingIntent.technicalAnalysis;
  }
  
  // Risk calculation intent
  if (lowerPrompt.contains('lot') || 
      lowerPrompt.contains('risiko') || 
      lowerPrompt.contains('modal') ||
      lowerPrompt.contains('sl') ||
      lowerPrompt.contains('stop loss') ||
      lowerPrompt.contains('take profit') ||
      lowerPrompt.contains('tp') ||
      lowerPrompt.contains('risk reward')) {
    return TradingIntent.riskCalculation;
  }
  
  // Account info intent
  if (lowerPrompt.contains('saldo') || 
      lowerPrompt.contains('equity') || 
      lowerPrompt.contains('margin') ||
      lowerPrompt.contains('posisi') ||
      lowerPrompt.contains('account') ||
      lowerPrompt.contains('profit') ||
      lowerPrompt.contains('loss')) {
    return TradingIntent.accountInfo;
  }
  
  return TradingIntent.generalChat;
}

// Ubah method generate() untuk menggunakan klasifikasi ini
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
  // 1. KLASIFIKASI NIAAT PENGGUNA
  final intent = _classifyIntent(prompt);
  
  // 2. PERSIAPKAN KONTEKS BERDASARKAN NIAAT (LEBIH EFISIEN)
  String liveContext = '';
  if (intent != TradingIntent.generalChat) {
    liveContext = await _fetchLiveTradingContext();
    // Untuk intent spesifik, kita bisa memfilter konteks lebih lanjut
    if (intent == TradingIntent.priceCheck) {
      liveContext = _extractPriceRelevantContext(liveContext);
    } else if (intent == TradingIntent.technicalAnalysis) {
      liveContext = _extractTechnicalRelevantContext(liveContext);
    } // dst...
  }
  
  // 3. SISIPKAN KONTEKS KE SYSTEM PROMPT
  final baseSystemPrompt = TradingCoachPrompt.systemPrompt;
  final systemPromptWithLiveContext = baseSystemPrompt.replaceAll('{live_context}', liveContext);
  
  // 4. LANJUTKAN DENGAN PROSES NORMAL
  // ... [sisa kode generate tetap sama] ...
}

// Tambahkan helper methods untuk memfilter konteks
String _extractPriceRelevantContext(String fullContext) {
  // Hanya ambil bagian yang relevan untuk price check
  // Contoh: hanya ambil watchlist prices dan timestamp
  final lines = fullContext.split('\n');
  final relevantLines = lines.where((line) => 
    line.contains('HARGA PASAR') || 
    line.contains('Timestamp') ||
    line.contains('AKUN MT5') == false && 
    line.contains('POSISI TERBUKA') == false
  ).join('\n');
  return relevantLines.isNotEmpty ? relevantLines : fullContext;
}

String _extractTechnicalRelevantContext(String fullContext) {
  // Untuk analisis teknikal, kita mungkin butuh informasi tentang symbol yang sedang dianalisis
  // Ini bisa diperkaya nanti dengan parameter symbol dari prompt
  return fullContext; // Untuk saat ini, gunakan semua context
}
```

### 2. **Kurangi Ukuran Konteks yang Dikirim ke LLM**
Modifikasi `context_builder.dart` untuk menghasilkan output yang lebih kompakt ketika digunakan di mobile:

```dart
// Di context_builder.dart, tambahkan parameter untuk mode ringkas
class AiTradingContext {
  // ... [field existing tetap sama] ...
  
  const AiTradingContext({
    this.account,
    required this.openPositions,
    required this.watchlistPrices,
    required this.timestamp,
    this.isCompact = false, // BARU: flag untuk mode ringkas
  });

  // Ubah method toPromptContext() untuk mendukung mode kompakt
  String toPromptContext({bool compact = false}) {
    if (compact) {
      return _toCompactPromptContext();
    }
    return toPromptContext(); // implementasi asli
  }

  String _toCompactPromptContext() {
    final sb = StringBuffer();
    
    // Hanya include information yang absolut esensial
    if (account != null) {
      sb.writeln('AKUN: Balance: \$${
        account.balance.toStringAsFixed(0)}, Equity: \$${
        account.equity.toStringAsFixed(0)}, Free Margin: \$${
        account.freeMargin.toStringAsFixed(0)}');
      sb.writeln('Margin Level: ${_marginLevel()}%');
    }
    
    if (openPositions.isNotEmpty) {
      sb.writeln('POSISI: ${openPositions.length} terbuka');
      // Tampilkan hanya posisi pertama sebagai representasi
      final p = openPositions.first;
      final pnlPrefix = p.profit >= Decimal.zero ? '+' : '';
      sb.writeln('${p.symbol} ${p.type} ${p.volume} lot @ ${p.openPrice} | SL: ${p.sl} | TP: ${p.tp} | PnL: $pnlPrefix\$${p.profit.toStringAsFixed(0)}');
    }
    
    if (watchlistPrices.isNotEmpty) {
      // Tampilkan hanya 2 simbol pertama untuk hemat ruang
      final limited = watchlistPrices.take(2).toList();
      sb.writeln('HARGA: ${limited.map((e) => '${e.key}: \$${e.value.price.toStringAsFixed(0)}').join(' | ')}');
    }
    
    sb.write('Waktu: ${timestamp.split(' ')[1]}'); // Hanya tampilkan waktu
    return sb.toString();
  }
}
```

Lalu ubah pemanggilan di `inference_provider.dart`:
```dart
final liveContext = await _fetchLiveTradingContext();
final compactLiveContext = liveContext.isNotEmpty 
    ? AiTradingContext.fromJson(jsonDecode(liveContext)).toPromptContext(compact: true) 
    : liveContext;
// Gunakan compactLiveContext untuk system prompt
```

### 3. **Sederhanakan Format Panggilan Tool**
Alih-alih membiarkan LLM menghasilkan JSON yang kompleks untuk tool calls, implementasikan sistem yang lebih sederhana:

**Sebelum (LLM harus menghasilkan JSON semacam):**
```json
{
  "tool": "calculatePositionSize",
  "arguments": {
    "equity": 10000,
    "riskPct": 2.0,
    "entryPrice": 2650.0,
    "stopLoss": 2630.0,
    "isGold": true
  }
}
```

**Sesudah (gunakan format yang lebih mudah di-parse):**
```
TOOL: calculatePositionSize
equity: 10000
riskPct: 2.0
entryPrice: 2650.0
stopLoss: 2630.0
isGold: true
```

Lalu di `trading_tools.dart`, modifikasi method `execute` untuk menangani format ini:
```dart
@override
Future<String> execute(Map<String, dynamic> args) async {
  // Cek apakah ini adalah format sederhana dari string
  if (args.containsKey('rawCommand')) {
    final raw = args['rawCommand'] as String;
    return _parseSimpleToolCall(raw);
  }
  
  // ... [kode existing tetap sama] ...
}

Future<String> _parseSimpleToolCall(String raw) {
  // Parsing format: 
  // TOOL: toolName
  // param1: value1
  // param2: value2
  final lines = raw.split('\n');
  final toolNameLine = lines.firstWhere((l) => l.startsWith('TOOL: '), orElse: () => '');
  
  if (toolNameLine.isEmpty) {
    return jsonEncode({'status': 'error', 'message': 'Format tool call tidak valid'});
  }
  
  final toolName = toolNameLine.replaceFirst('TOOL: ', '').trim();
  final params = <String, dynamic>{};
  
  for (final line in lines.skip(1)) {
    if (line.contains(':')) {
      final parts = line.split(':', 2);
      final key = parts[0].trim();
      final value = parts[1].trim();
      
      // Konversi tipe data dasar
      if (value == 'true') params[key] = true;
      else if (value == 'false') params[key] = false;
      else if (double.tryParse(value) != null) {
        params[key] = double.parse(value);
      } else if (int.tryParse(value) != null) {
        params[key] = int.parse(value);
      } else {
        params[key] = value;
      }
    }
  }
  
  // Sekarang panggil method yang sesuai berdasarkan toolName
  switch (toolName) {
    case 'getCurrentPrice':
      return getCurrentPrice(params);
    case 'getTechnicalIndicators':
      return getTechnicalIndicators(params);
    case 'calculatePositionSize':
      return calculatePositionSize(params);
    case 'getAccountContext':
      return getAccountContext(params);
    default:
      return jsonEncode({'status': 'error', 'message': 'Tool tidak dikenal: $toolName'});
  }
}
```

### 4. **Optimasi System Prompt untuk Model Kecil**
Perbarui `trading_coach_prompt.dart` dengan versi yang lebih ringkas dan terstruktur:

```dart
static const String systemProtocol = '''
Anda adalah AURA Trading Coach. Aturan:
1. JAWAB HANYA BERDASARKAN DATA YANG DISETIRKAN (jangan masukkan data dari ingatan)
2. JIKA TIDAK ADA DATA, KATAKAN "Saya tidak memiliki data terkini"
3. FOKUS PADA PENDIDIKAN DAN MANAJEMEN RISIKO
4. JANGAN BERI SINYAL BELI/JUAL SEKALIGUS
5. GUNAKAN BAHASA INDONESIA YANG JELAS

[JIKA ADA KONTEKS LIVE]
{live_context}

CONTOH CARA BERJALAN:
User: "Berapa harga XAUUSD sekarang?"
AI: [lihat konteks] "Harga XAUUSD saat ini adalah $2650.00"

User: "Hitung lot size untuk XAUUSD dengan entry 2650, SL 2630, modal 10000, risiko 2%"
AI: [hitung] "Lot size yang disarankan: 0.10 lot. Maksimal risiko: $20.00"

User: "Apa itu RSI?"
AI: "RSI (Relative Strength Index) adalah indikator momentum yang mengukur kecepatan dan perubahan pergerakan harga. Nilai di atas 70 menunjukkan kondisi overbought, di bawah 30 menunjukkan oversold."
''';
```

### 5. **Implementasi Fallback ke Rule-Based Response**
Untuk pertanyaan umum yang tidak memerlukan data live, buat sistem respons berbasis rule yang tidak memanggil LLM sama sekali:

```dart
// Di inference_provider.dart, tambahkan sebelum memanggil LLM
Future<bool> _canAnswerWithRuleBased(String prompt) async {
  final lowerPrompt = prompt.toLowerCase();
  
  // Pertanyaan tentang konsep dasar yang bisa dijawab dari knowledge base statis
  final conceptQuestions = [
    'apa itu rsi',
    'apa itu macd',
    'apa itu ema',
    'apa itu support dan resistance',
    'cara menghitung lot size',
    'apa itu stop loss',
    'apa itu take profit',
    'apa itu risk reward ratio',
    'apa itu margin level',
    'apa itu equity',
    'apa itu balance'
  ];
  
  return conceptQuestions.any((q) => lowerPrompt.contains(q));
}

Future<String> _getRuleBasedAnswer(String prompt) async {
  final lowerPrompt = prompt.toLowerCase();
  
  if (lowerPrompt.contains('apa itu rsi')) {
    return 'RSI (Relative Strength Index) adalah indikator momentum yang mengukur kecepatan dan perubahan pergerakan harga pada skala 0-100. Nilai di atas 70 menunjukkan kondisi overbought (mungkin terjadi koreksi harga turun), di bawah 30 menunjukkan oversold (mungkin terjadi koreksi harga naik). Umumnya, level 30 dan 70 digunakan sebagai ambang overbought/oversold.';
  }
  
  if (lowerPrompt.contains('apa itu macd')) {
    return 'MACD (Moving Average Convergence Divergence) adalah indikator trend yang menunjukkan hubungan antara dua moving average harga. MACD terdiri dari: MACD line (12-period EMA - 26-period EMA), Signal line (9-period EMA dari MACD line), dan histogram (perbedaan antara MACD line dan signal line). Khi MACD line melintasi signal line ke atas, dianggap sinyal bullish; ke bawah, sinyal bearish.';
  }
  
  // ... [tambahkan konsep dasar lain] ...
  
  return ''; // Kembalikan string kosong jika tidak cocok dengan pola manapun
}

// Di method generate():
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
  // 1. CEK APAKAH BOLEH DIJAWAB DENGAN RULE-BASED
  if (await _canAnswerWithRuleBased(prompt)) {
    final answer = await _getRuleBasedAnswer(prompt);
    if (answer.isNotEmpty) {
      // Langsung kirim jawaban tanpa memanggil LLM
      state = state.copyWith(
        status: InferenceStatus.completed,
        text: answer,
        metrics: const InferenceMetrics(),
      );
      return;
    }
  }
  
  // 2. LANJUTKAN KE ALUR NORMAL (dengan semua optimasi di atas)
  // ... [kode yang sudah kita modifikasi] ...
}
```

### 6. **Pemilihan Model yang Tepat untuk Mobile**
Rekomendasikan model spesifik yang terbukti bekerja baik dengan tool calling di kisaran < 4B:

| Model | Ukuran | Kelebihan | Catatan |
|-------|--------|-----------|---------|
| **Phi-3-mini** | 3.8B | Sangat baik dalam following instructions, reasoning, dan code generation. Dirancang khusus untuk edge devices. | Pilihan pertama untuk mobile |
| **TinyLlama** | 1.1B | Sangat kecil, cukup untuk tugas sangat sederhana | Mungkin terlalu kecil untuk tool trading kompleks |
| **StableLM Zephyr 3B** | 3B | Seimbang antara kemampuan dan ukuran | Bagus untuk instruksi folg following |
| **MobileLLaMA** | 1.3B | Dirancang spesifik untuk mobile | Kurang teruji untuk tool calling |
| **Gemma 2B** | 2B | Dari Google, kualitas baik | Butuh evaluasi spesifik untuk tool calling |

**Recomendasi spesifik**: **Phi-3-mini (3.8B)** dalam format GGUF dengan quantisasi **q4_k_m** (best balance of quality and size untuk mobile).

---

## 📊 Estimasi Pengurunan Resource

Dengan semua optimasi di atas, kita dapat mengurangi beban pada model LLM secara signifikan:

| Aspek | Tanpa Optimasi | Dengan Optimasi | Pengurangan |
|-------|----------------|-----------------|-------------|
| Konteks yang dikirim ke LLM | ~600-800 token | ~150-250 token | **60-70%** |
| Kompleksitas reasoning yang diperlukan | Tinggi (multi-tool inference) | Rendah (rule-based intent + simple tool calls) | **70-80%** |
| Jumlah token yang dihasilkan LLM | 100-300+ | 50-150 (jawaban lebih fokus) | **50%** |
| Total beban komputasional | Tinggi | Rendah | **65-75%** |

---

## ✅ Checklist Verifikasi untuk Antigravity

| Test Case | Expected Behavior |
|-----------|-------------------|
| **Tanya tentang konsep dasar (misal: "apa itu RSI?")** | Jawaban diberikan langsung tanpa memanggil LLM (rule-based response) |
| **Tanya harga saat ini (misal: "harga XAUUSD?")** | Sistem klasifikasi mengenali sebagai `priceCheck`, hanya mengirim konteks harga yang diperlukan |
| **Tanya teknikal (misal: "apa RSI XAUUSD sekarang?")** | Sistem mengirim konteks teknikal yang ringkas |
| **Tanya risk calculation (misal: "hitung lot size untuk XAUUSD...")** | Sistem menggunakan format tool call sederhana yang mudah di-parse |
| **Model < 4B berjalan lancar** | Tidak ada lag signifikan, respons dalam < 3 detik pada device mobile |
| **Fallback ke rule-based bekerja** | Saat LLM offline atau error, sistem masih bisa menjawab pertanyaan konseptual dasar |

---

## 🚀 Langkah Eksekusi untuk Antigravity

```bash
# 1. Implementasikan semua perubahan di atas ke file yang relevan
# 2. Pastikan Anda telah memilih dan mengkonfigurasi model Phi-3-mini (3.8B GGUF q4_k_m)
# 3. Jalankan build_runner jika ada perubahan provider
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_trading
flutter pub run build_runner build --delete-conflicting-outputs  # Jika diperlukan

# 4. Jalankan MT5 Bridge Python
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/tools/mt5_bridge
python mt5_service.py

# 5. Test di mobile emulator/device
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_mobile
flutter run  # Gunakan device sesungguhnya atau emulator dengan spesifikasi yang realistis
```

---

## ⚠️ Catatan Penting untuk Antigravity

1. **Jangan ubah `aura_core`** — fokus hanya pada `aura_trading`, `aura_mobile`, `aura_desktop`.
2. **Prinsip 5 tetap ketat**: Tidak ada auto-execute MT5. Selalu butuh konfirmasi pengguna via dialog.
3. **Kompatibilitas mundur**: Semua optimasi di atas harus masih bekerja dengan model LLM yang lebih besar (7B+), hanya saja optimasi ini akan kurang terasa dampaknya pada model besar.
4. **Monitoring kualitas response**: Setelah implementasi, lakukan testing manual untuk memastikan kualitas respons tidak menurun secara signifikan dibalik versi non-optimasi.
5. **Adaptasi simbol**: Pastikan format simbol (XAUUSD vs XAU/USD) konsisten di seluruh sistem tergantung pada broker MT5 yang digunakan.

---

*Implementasi ini dirancang spesifik untuk menjamin bahwa AURA Trading Assistant tetap berfungsi dengan baik bahkan ketika menggunakan model LLM dengan parameter di bawah 4B pada perangkat mobile, dengan tidak menyakiti fungsi inti maupun prinsip keamanan yang telah kita bangun bersama.* 