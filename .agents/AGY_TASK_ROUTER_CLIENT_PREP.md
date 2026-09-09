# Task untuk Agy: Klarifikasi & Persiapan Sebelum Menulis `router_client.dart`

## Konteks
`implementation_plan2.md` sudah oke secara struktur, tapi ada 5 gap desain
yang harus dijawab/diputuskan DULU sebelum mulai nulis kode
`router_client.dart` dan wiring ke `inference_provider.dart`. Ini file
pertama di modul `llm_router` yang beneran manggil jaringan (bukan
pure-logic lagi), jadi keputusan di sini nentuin arsitektur untuk
seterusnya — jangan ditulis sambil jalan, jawab dulu semua poin di bawah.

Jawaban dari task ini (baik berupa keputusan desain maupun file yang
diminta) dikirim balik ke chat ini untuk direview sebelum lanjut ke
implementasi `router_client.dart` yang sebenarnya.

## 1. Logika "kapan turun ke lokal" (Rule 17)

`ErrorClassification.shouldFallback` di `retry_backoff.dart` SELALU
bernilai `true` di semua rule — itu didesain untuk "pindah ke model lain
DALAM combo cloud" (dengan cooldown), BUKAN untuk "menyerah dari cloud dan
turun ke GGUF lokal". Dua hal ini beda level keputusan dan jangan
ketuker.

**Yang perlu diputuskan & didokumentasikan:**
- Kondisi pasti apa yang memicu fallback ke lokal:
  - Semua provider dalam combo sudah dicoba dan gagal (bukan cuma satu)?
  - `backoffLevel` sudah mencapai `backoffMaxLevel` (15)?
  - Error yang sifatnya nggak bisa di-retry sama sekali (mis. 401 invalid
    API key, bukan rate limit)?
  - Kombinasi dari beberapa kondisi di atas?
- Berapa kali percobaan/berapa lama total waktu maksimal sebelum nyerah ke
  lokal (biar user nggak nunggu kelamaan)?
- Tulis keputusan ini sebagai fungsi terpisah, mis.
  `shouldFallbackToLocal(ErrorClassification, int attemptCount, ...)` — 
  JANGAN taruh logic ini di dalam `retry_backoff.dart` yang sudah
  di-review dan lolos test; taruh di `router_client.dart` sebagai logic
  baru yang khusus mengonsumsi hasil `classifyError`.

## 2. Stall timeout untuk mobile chat UX

`defaultStallTimeout` (6 menit) itu warisan dari konteks server proxy Go,
kelamaan untuk chat UI mobile.

**Yang perlu diputuskan:**
- Angka timeout yang dipakai di `router_client.dart` (usul: 20-45 detik,
  tapi putuskan sendiri sesuai UX yang diinginkan — boleh beda per jenis
  provider/model kalau perlu, mis. model reasoning butuh lebih lama)
- Pastikan ini di-override eksplisit lewat parameter `timeout` saat
  memanggil `.withStallDetection()`, JANGAN pakai default 6 menit apa
  adanya

## 3. Lifecycle streaming session (`sessionKey`)

`_streamStates` dan `_pendingStreamFragments` di `format_translator.dart`
adalah **map statis in-memory**, di-keyed oleh `sessionKey` string bebas —
kalau lifecycle-nya nggak jelas, bisa numpuk (memory leak kecil) atau
collision antar percakapan.

**Yang perlu diputuskan & didokumentasikan:**
- `sessionKey` yang dipakai: id percakapan (conversation id) yang sudah
  ada di sistem penyimpanan chat A.U.R.A? UUID baru per-request? Sebutkan
  sumbernya secara konkret.
- Kapan `ensureStreamClosed(sessionKey)` dipanggil — WAJIB dipanggil kalau
  user cancel/keluar dari layar chat di tengah streaming, atau kalau
  koneksi network putus sebelum `finish_reason` diterima
- Kapan `clearStreamState(sessionKey)` dipanggil untuk cleanup normal
  setelah stream selesai dengan bersih
- Apakah ada skenario 2 percakapan jalan bersamaan (multi-conversation
  aktif sekaligus)? Kalau ada, pastikan `sessionKey` unik per percakapan,
  bukan satu key global.

## 4. Format chat internal A.U.R.A — cek dulu sebelum asumsi

Plan bilang "Formats requests with `translateClaudeToOpenAI` ... when
calling OpenAI or Gemini endpoints" — ini cuma valid KALAU representasi
chat internal A.U.R.A sudah berformat Claude-style content blocks.

**Yang perlu dilakukan (bukan diasumsikan):**
- Buka dan laporkan isi `aura_core/lib/src/.../chat_models.dart` (atau file
  model chat manapun yang dipakai `aura_mobile` untuk merepresentasikan
  pesan percakapan) — kirim struktur class-nya (field-field-nya saja,
  nggak perlu full file kalau panjang) sebagai bagian dari jawaban task
  ini.
- Kalau format internal A.U.R.A ternyata BUKAN Claude-style blocks
  (misalnya OpenAI-style langsung, atau format custom sendiri), maka:
  - `translateClaudeToOpenAI` cuma dipakai kalau/ketika A.U.R.A nanti mau
    expose endpoint Claude-compatible ke luar — TIDAK dipakai untuk
    manggil Gemini/OpenAI dari internal
  - `router_client.dart` perlu fungsi konversi baru: dari format chat
    internal A.U.R.A → format request tiap provider (OpenAI-style,
    Gemini-style) — ini pure logic baru yang belum ada portingannya dari
    9router-go, jadi tulis dari nol dan tandai jelas di komentar bahwa ini
    BUKAN port dari Go

## 5. HTTP client untuk `router_client.dart`

**Yang perlu diputuskan:**
- Pakai `package:http`, `dio`, atau `HttpClient` native? Cek dulu
  `pubspec.yaml` di `aura_core`/`aura_mobile` — kalau salah satu sudah
  jadi dependency yang dipakai di tempat lain, pakai itu, jangan nambah
  dependency baru tanpa alasan kuat (ingat: `llm_router` tadinya
  zero-dependency, tapi karena `router_client.dart` memang butuh network
  I/O beneran, ini pengecualian yang wajar — bukan pelanggaran prinsip
  "pure Dart" untuk modul logic lainnya)
- **WAJIB**: HTTP client di-inject lewat constructor (constructor
  parameter), JANGAN dibuat langsung (`= http.Client()`) di dalam class
  `LlmRouterClient`. Ini supaya `router_client_test.dart` bisa pasang mock
  client tanpa hit jaringan asli. Contoh pola:
  ```dart
  class LlmRouterClient {
    final http.Client httpClient; // atau tipe sesuai library yg dipilih

    LlmRouterClient({http.Client? httpClient})
        : httpClient = httpClient ?? http.Client();
  }
  ```

## Deliverable dari task ini
Jangan langsung nulis `router_client.dart`. Kirim dulu balasan berisi:
1. Keputusan tertulis untuk poin #1, #2, #3, #5 di atas
2. Struktur `chat_models.dart` (field-field class-nya) untuk poin #4
3. Kalau ada pertanyaan/ambiguitas lain yang ditemukan saat menyiapkan
   jawaban di atas, tulis juga di sini — jangan diputuskan sepihak

Setelah itu direview dan disepakati, baru lanjut ke implementasi
`router_client.dart` + `router_client_test.dart` sesuai
`implementation_plan2.md`.
