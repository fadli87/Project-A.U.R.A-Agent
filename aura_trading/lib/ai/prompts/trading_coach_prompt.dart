/// System Prompts and Sub-4B optimizations for AURA Trading Coach Persona.
class TradingCoachPrompt {
  /// Standard full system prompt for Desktop and larger LLM models.
  static const String systemPrompt = '''
Anda adalah AURA Trading Coach — pendamping AI cerdas, disiplin, dan berfokus pada edukasi serta Manajemen Risiko untuk trading Forex, Gold (XAU/USD), dan Saham IDX.

**ATURAN WAJIB — GROUNDING DATA:**
Anda HANYA boleh menjawab pertanyaan tentang kondisi pasar, harga, atau analisis berdasarkan hasil pemanggilan tool yang tersedia (getCurrentPrice, getTechnicalIndicators, calculatePositionSize, getAccountContext) atau data konteks live yang disisipkan. JANGAN PERNAH menjawab dari "ingatan" atau pengetahuan umum Anda tentang harga pasar real-time.

Jika pengguna bertanya sesuatu yang memerlukan data pasar DAN Anda tidak memiliki data terkini, Anda HARUS menjawab: "Saya tidak memiliki data pasar terkini untuk menjawab itu."

**PRINSIP KEAMANAN UTAMA — MANUSIA ADALAH PEMICU AKHIR (HUMAN-IN-THE-LOOP):**
Anda TIDAK BOLEH menempatkan order live MT5 secara otomatis. Jika pengguna meminta membuka atau menutup posisi, selalu pandu pengguna untuk menggunakan tombol konfirmasi fisik ("Kirim ke MT5" di Risk Card atau tombol "Tutup Posisi" di tab MT5) setelah pengguna memeriksa risiko secara mandiri.

Prinsip Utama Anda:
1. **RISK FIRST**: Selalu utamakan manajemen risiko di atas potensi profit. Ingatkan penggunanya tentang Lot sizing, Stop Loss, Margin Level, dan Risk/Reward Ratio.
2. **AKUN MT5 LIVE AWARENESS**: Jika konteks akun MT5 live disisipkan (Balance, Equity, Free Margin, Posisi Terbuka), rujukan data tersebut untuk memberikan analisa manajemen risiko yang dipersonalisasi.
3. **EDUKATIF & EMBRACING**: Menjelaskan konsep teknikal (RSI, MACD, EMA) atau fundamental dengan bahasa Indonesia yang jelas, ramah, dan aplikatif.
4. **NEUTRAL & NON-PRESCRIPTIVE**: Jangan memberikan sinyal beli/jual secara buta. Selalu berikan analisis objektif dengan skenario risikonya.

DISCLAIMER: Seluruh analisis ini bersifat edukatif dan simulasi manajemen risiko, bukan nasihat keuangan profesional. Keputusan trading sepenuhnya berada di tangan Anda.
''';

  /// Ultra-compact system prompt specifically designed for mobile Sub-4B models (< 4B parameters).
  static const String compactSystemPrompt = '''
Anda adalah AURA Trading Coach (Edukasi & Manajemen Risiko).
Aturan Wajib:
1. JAWAB HANYA BERDASARKAN DATA YANG DIBERIKAN (jangan buat asumsi harga pasar).
2. JIKA TIDAK ADA DATA, KATAKAN: "Saya tidak memiliki data pasar terkini."
3. RISK FIRST: Selalu prioritaskan Stop Loss, Lot sizing aman, dan rasio Risk/Reward.
4. TIDAK ADA EKSEKUSI OTOMATIS: Arahkan pengguna ke tombol konfirmasi manual di aplikasi.
5. Bahasa Indonesia yang ringkas, jelas, dan edukatif.
''';

  /// Instant rule-based answers for fundamental trading concepts without needing LLM inference.
  /// Saves 100% compute, battery, and eliminates token overflow on edge devices.
  static String? getRuleBasedAnswer(String prompt) {
    final lower = prompt.toLowerCase().trim();

    if (lower.contains('apa itu rsi') || lower.contains('pengertian rsi') || lower == 'rsi') {
      return '📊 **RSI (Relative Strength Index)** adalah indikator momentum yang mengukur kecepatan & perubahan pergerakan harga pada skala 0–100.\n• **> 70**: Overbought (area jenuh beli, potensi koreksi turun).\n• **< 30**: Oversold (area jenuh jual, potensi pantulan naik).\n• **50**: Garis tengah pemisah tren bullish/bearish.';
    }

    if (lower.contains('apa itu macd') || lower.contains('pengertian macd') || lower == 'macd') {
      return '📈 **MACD (Moving Average Convergence Divergence)** adalah indikator pengikut tren & momentum.\n• **MACD Line melintas di atas Signal Line**: Golden cross (sinyal potensi tren naik).\n• **MACD Line melintas di bawah Signal Line**: Death cross (sinyal potensi tren turun).\n• **Histogram**: Menggambarkan akselerasi kekuatan momentum.';
    }

    if (lower.contains('apa itu ema') || lower.contains('pengertian ema') || lower.contains('exponential moving average')) {
      return '📉 **EMA (Exponential Moving Average)** adalah rata-rata pergerakan harga yang memberikan bobot lebih besar pada data harga terbaru.\n• **EMA 20**: Menunjukkan tren jangka pendek.\n• **EMA 50**: Menunjukkan tren jangka menengah.\n• **Bullish Cross**: EMA 20 memotong ke atas EMA 50.';
    }

    if (lower.contains('apa itu stop loss') || lower.contains('pengertian stop loss') || lower == 'sl') {
      return '🛡️ **Stop Loss (SL)** adalah batasan harga otomatis untuk menutup posisi guna membatasi kerugian maksimal jika pergerakan pasar berlawanan dengan prediksi Anda. Selalu pasang Stop Loss sebelum memasuki pasar demi melindungi modal!';
    }

    if (lower.contains('apa itu take profit') || lower.contains('pengertian take profit') || lower == 'tp') {
      return '🎯 **Take Profit (TP)** adalah batasan harga otomatis untuk mengunci keuntungan ketika target pergerakan harga yang diantisipasi telah tercapai.';
    }

    if (lower.contains('risk reward') || lower.contains('rasio rr') || lower.contains('risk:reward')) {
      return '⚖️ **Risk/Reward Ratio (RRR)** adalah perbandingan antara besaran risiko yang rela Anda tanggung (Stop Loss) dengan target potensi keuntungan (Take Profit).\n• Disiplin trading yang sehat merekomendasikan minimal **1:1.5** atau **1:2** (risiko \$10 untuk potensi \$20).';
    }

    if (lower.contains('apa itu margin level') || lower.contains('margin level')) {
      return '🏦 **Margin Level** adalah rasio antara Equity terhadap Margin yang digunakan, dinyatakan dalam persentase: `(Equity / Margin) x 100%`.\n• **> 500%**: Akun sangat sehat.\n• **< 100%**: Margin Call (Anda tidak bisa membuka posisi baru).\n• **< 20-50%**: Stop Out (broker akan menutup paksa posisi secara otomatis).';
    }

    if (lower.contains('cara hitung lot') || lower.contains('rumus lot') || lower.contains('kalkulasi lot')) {
      return '📐 **Rumus Lot Size Forex/Gold:**\n`Lot = (Modal x % Risiko) / (Jarak SL dalam Pips x Nilai per Pip)`\n\nContoh: Modal \$1,000, Risiko 2% (\$20), SL 20 pips pada EUR/USD (\$10/pip standard lot):\n`Lot = \$20 / (20 x \$10) = 0.10 Lot`.\n\nGunakan tab **Watchlist & RiskCard** di aplikasi AURA untuk menghitungnya secara instan dan presisi!';
    }

    return null;
  }
}
