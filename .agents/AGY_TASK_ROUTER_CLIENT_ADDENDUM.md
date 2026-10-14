# Addendum — Koreksi Desain `router_client.dart`

Lanjutan dari `router_client_design.md` (spesifikasi hasil evaluasi 5 gap
sebelumnya). Sebelum mulai coding, perbaiki 2 hal blocking (#1, #2) dan
putuskan 3 hal lain (#3, #4, #5) di bawah ini.

## 🔴 BLOCKING #1 — Kontradiksi elapsed timeout vs stall timeout

Elapsed cap ("Cumulative Elapsed Timeout") di tabel fallback-trigger diset
**15 detik**, tapi stall timeout per model di bagian 2 diset **30 detik**
(60 detik untuk reasoning model). Ini kontradiktif: kalau combo punya 2+
model, model pertama aja bisa makan waktu sampai 30 detik sebelum
dianggap stall, padahal elapsed cap sudah nyerah di detik ke-15 —
akibatnya model kedua dst di combo nggak pernah kebagian giliran dicoba.

**Perbaiki dengan salah satu dari ini (pilih salah satu, dokumentasikan
keputusannya):**

- **Opsi A — elapsed cap per-model, bukan cumulative total combo:**
  Ganti kriteria `comboExhausted`/`elapsedTimeout` supaya elapsed diukur
  per attempt-ke-satu-model, bukan akumulasi keseluruhan combo. Fallback
  ke lokal baru terjadi kalau SEMUA model di combo sudah masing-masing
  kena stall/gagal, bukan kalau total waktu gabungan sudah lewat 15 detik.

- **Opsi B — naikkan elapsed cap jadi selaras dengan stall timeout:**
  Set elapsed cap total jadi cukup longgar untuk minimal 1-2 model sempat
  dicoba penuh (mis. `stallTimeout * min(comboLength, 2)` atau angka tetap
  yang lebih besar, mis. 45-60 detik).

Rekomendasi: **Opsi A** lebih konsisten sama semangat "combo exhausted"
yang sudah ada di tabel (baris `Combo Exhausted` jadi otomatis konsisten
dengan elapsed-per-model, nggak perlu 2 kriteria terpisah yang bisa
tabrakan).

## 🔴 BLOCKING #2 — Tool-calling hilang/rusak di kedua fungsi konversi

### 2a. `ChatMessage` kurang field `toolCallId`
OpenAI API mewajibkan `tool_call_id` di setiap message role `"tool"`,
untuk mengaitkan hasil eksekusi ke tool call yang mana (penting kalau ada
lebih dari satu tool call dalam satu turn). Field ini tidak ada di
`ChatMessage`.

**Perbaikan:** tambah field ke `ChatMessage`:
```dart
class ChatMessage {
  // ...field yang sudah ada...
  final String? toolCallId;   // TAMBAHAN — id dari tool_call yang direspon
}
```
(Field ini datanya dari provider saat assistant message memuat tool call
— setiap tool call di `toolCallJson` biasanya punya `id` masing-masing;
saat menyimpan `ChatMessage` bertipe tool response berikutnya, simpan id
itu di sini.)

### 2b. `convertAuraToOpenAIMessages` — sertakan `tool_call_id`
```dart
case MessageRole.tool:
  result.add({
    'role': 'tool',
    'tool_call_id': msg.toolCallId ?? '',   // TAMBAHAN
    'content': msg.toolResult ?? msg.content,
  });
  break;
```

### 2c. `convertAuraToGeminiPayload` — tangani role tool & tool call assistant
Saat ini semua non-assistant di-map jadi role `'user'` dengan teks polos —
`MessageRole.tool` dan assistant message yang sebenarnya tool call jadi
salah bentuk. Gemini API punya format khusus:
- Assistant tool call → part `functionCall`: `{'functionCall': {'name': ..., 'args': {...}}}`
- Tool result → role `'user'` dengan part `functionResponse`:
  `{'functionResponse': {'name': ..., 'response': {...}}}`

Perbaiki jadi:
```dart
Map<String, dynamic> convertAuraToGeminiPayload(
  List<ChatMessage> messages, {
  String? systemPrompt,
  double temperature = 0.7,
  int maxTokens = 1024,
}) {
  final contents = <Map<String, dynamic>>[];

  for (final msg in messages) {
    switch (msg.role) {
      case MessageRole.system:
        continue; // sudah ditangani via systemInstruction terpisah
      case MessageRole.tool:
        contents.add({
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                // 'name' idealnya diambil dari tool call yang direspon
                // (butuh disimpan di ChatMessage saat tool call terjadi,
                // mis. field toolName, bukan cuma toolCallId)
                'name': msg.toolCallId ?? '',
                'response': {'result': msg.toolResult ?? msg.content},
              }
            }
          ],
        });
        break;
      case MessageRole.assistant:
        if (msg.toolCallJson != null && msg.toolCallJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(msg.toolCallJson!);
            // sesuaikan bentuk decoded (List tool calls / single object)
            // jadi parts functionCall Gemini di sini
            contents.add({
              'role': 'model',
              'parts': [
                {'functionCall': decoded}
              ],
            });
            break;
          } catch (_) {
            // fallback ke text biasa kalau parsing gagal
          }
        }
        contents.add({
          'role': 'model',
          'parts': [{'text': msg.content}],
        });
        break;
      case MessageRole.user:
        contents.add({
          'role': 'user',
          'parts': [{'text': msg.content}],
        });
        break;
    }
  }

  return {
    'contents': contents,
    if (systemPrompt != null && systemPrompt.isNotEmpty)
      'systemInstruction': {'parts': [{'text': systemPrompt}]},
    'generationConfig': {
      'temperature': temperature,
      'maxOutputTokens': maxTokens,
    },
  };
}
```
Catatan: kalau `functionResponse.name` butuh nama tool asli (bukan cuma
id), pertimbangkan tambah field `toolName` juga ke `ChatMessage` selain
`toolCallId` — cek dulu apa `toolCallJson` yang tersimpan cukup buat
nge-derive nama tool-nya, atau memang perlu disimpan eksplisit terpisah.

## 🟡 Keputusan UX — putuskan sebelum nulis `inference_provider.dart`

### 3. Perilaku saat fallback terjadi DI TENGAH streaming
Skenario: token sudah muncul sebagian dari cloud, lalu stall/429 di
tengah jalan. Putuskan salah satu (tulis keputusannya di komentar kode
`inference_provider.dart`, bukan diam-diam dipilih saat implementasi):
- (a) Lanjutkan sisa jawaban pakai model lokal, nyambung di bubble yang
  sama (device tampilan tunggal, transisi kualitas mungkin terasa)
- (b) Buang teks partial dari cloud, mulai ulang total pakai lokal
- (c) Tampilkan sebagai 2 bubble terpisah (bubble cloud partial ditandai
  gagal + bubble baru dari lokal)

### 4. Perilaku giliran chat berikutnya setelah sekali fallback
Setelah fallback ke lokal terjadi karena alasan transient (network blip,
rate limit sementara), apakah pesan berikutnya:
- (a) Otomatis coba cloud lagi (default, kecuali user manual pilih mode
  lokal di settings), atau
- (b) Tetap di lokal sampai user manual switch balik ke cloud

Rekomendasi: **(a)**, supaya user nggak "kejebak" di mode lokal tanpa
sadar kenapa — tapi tetap surface indikator di UI kalau percobaan cloud
gagal lagi, biar nggak berulang-ulang gagal secara diam-diam tiap pesan.

## Deliverable
Kirim balik:
1. Keputusan final untuk #1 (Opsi A/B) dan implementasinya di
   `evaluateLocalFallback()`
2. `ChatMessage` yang sudah ditambah field `toolCallId` (dan `toolName`
   kalau memang diperlukan untuk Gemini)
3. `convertAuraToOpenAIMessages` dan `convertAuraToGeminiPayload` versi
   revisi
4. Keputusan tertulis untuk #3 dan #4

Setelah ini disepakati, baru lanjut implementasi penuh
`router_client.dart` + `router_client_test.dart`.
