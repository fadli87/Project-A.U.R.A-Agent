# Addendum — Koreksi Kode `router_client.dart`

Hasil review kode aktual (bukan lagi dokumen desain). Ada 2 item blocking
dan 1 item tinggi yang harus diperbaiki sebelum lanjut, plus 2 item minor.

## 🔴 BLOCKING #1 — Parsing combo rusak kalau ada `/` di dalam string combo

**Bukti konkret:** `resolveModel('gemini-2.5-flash,openai/gpt-4o-mini')` —
persis string combo yang dipakai di test
`skips provider in cooldown and uses next healthy provider in combo`.

`ModelResolver.resolveModel()` mengecek `str.contains('/')` LEBIH DULU
sebelum mengecek combo:
```dart
if (str.contains('/')) {
  final parts = str.split('/');
  final provider = resolveProviderAlias(parts[0]);
  final model = parts.sublist(1).join('/');
  return ModelInfo(provider: provider, model: model);
}
```
String combo `'gemini-2.5-flash,openai/gpt-4o-mini'` MENGANDUNG `/` (di
bagian `openai/gpt-4o-mini`), jadi nyangkut di cabang ini duluan —
`comboLookup` callback nggak pernah ke-reach. Hasilnya:
`parts[0] = "gemini-2.5-flash,openai"` (bukan provider valid), dan
`candidateModels` cuma jadi 1 entry garbage, bukan 2 model seperti yang
dimaksud.

**Jalankan test yang ada sekarang dan cek — kemungkinan besar test
`skips provider in cooldown...` gagal (throw `LocalFallbackException`
auth failure di percobaan pertama, `callCount` nggak akan mencapai 2/3
seperti yang diharapkan). Konfirmasikan hasil run test ini sebagai bagian
dari balasan.**

**Fix:** Jangan andalkan `comboLookup` callback untuk kasus ini sama
sekali. Split string combo dengan koma **DI DALAM `streamGenerate()`**,
SEBELUM memanggil `resolver.resolveModel()` — resolve tiap elemen combo
satu-satu:

```dart
// Di streamGenerate(), ganti langkah "1. Resolve model & flatten combo":
List<String> candidateModels;
if (modelOrCombo.contains(',')) {
  candidateModels = modelOrCombo.split(',').map((s) => s.trim()).toList();
} else {
  candidateModels = [modelOrCombo];
}
```
Hapus penggunaan `comboLookup` yang mencoba mendeteksi combo dari
`resolver.resolveModel(modelOrCombo)` secara langsung — itu didesain untuk
combo YANG SUDAH TERSIMPAN sebagai nama (mis. `"main_combo"` yang di-lookup
ke DB), bukan untuk string koma-separated mentah yang dipassing langsung
sebagai `modelOrCombo`. Dua kasus ini beda dan jangan dicampur di satu
resolusi yang sama. Setelah dapat `candidateModels` dari split koma di
atas, baru lanjut ke langkah "2. Rotasi urutan kandidat" dan seterusnya
seperti semula — tiap elemen combo (mis. `"openai/gpt-4o-mini"`) baru
di-`resolver.resolveModel()` satu-satu di dalam loop `for` yang sudah ada.

## 🔴 BLOCKING #2 — Tool-calling hilang total di jalur streaming cloud

`_streamGemini` dan `_streamOpenAICompatible` menulis parser SSE sendiri
dari nol yang HANYA mengekstrak teks (`delta['content']` /
`parts[0]['text']`). Tidak ada satupun pengecekan `delta['tool_calls']`
(OpenAI-compatible) atau `parts[...]['functionCall']` (Gemini). Padahal
kita sudah investasi 3 putaran review penuh di
`translateOpenAIToClaudeStreamSession` (termasuk fix index parallel
tool-calls) yang justru dirancang untuk menangani persis kasus ini —
tapi fungsi itu SAMA SEKALI TIDAK DIPANGGIL di sini.

Akibatnya: begitu model manggil tool lewat cloud (fitur inti agentic
A.U.R.A), tool call itu hilang — user cuma lihat respon kosong/diam.
`sessionKey`/`ensureStreamClosed`/`clearStreamState` yang dipanggil di
`streamGenerate()` juga jadi no-op karena `_streamStates` (di
`format_translator.dart`) nggak pernah diisi (tidak ada yang memanggil
`translateOpenAIToClaudeStreamSession`/`seedStreamState`).

**Fix — ubah tipe return, dari `Stream<String>` (token teks polos) jadi
representasi yang bisa membawa tool call.** Definisikan tipe event baru:

```dart
/// Event yang di-yield dari streamGenerate — bisa berupa teks token,
/// tool call yang perlu dieksekusi, atau sinyal selesai.
sealed class RouterStreamEvent {
  const RouterStreamEvent();
}

class RouterTextDelta extends RouterStreamEvent {
  final String text;
  const RouterTextDelta(this.text);
}

class RouterToolCall extends RouterStreamEvent {
  final String id;
  final String name;
  final String argumentsJson;
  const RouterToolCall({required this.id, required this.name, required this.argumentsJson});
}

class RouterStreamDone extends RouterStreamEvent {
  final String? finishReason;
  const RouterStreamDone({this.finishReason});
}
```

Lalu `streamGenerate()` dan `_dispatchProviderStream()`/
`_streamGemini`/`_streamOpenAICompatible` semuanya jadi
`Stream<RouterStreamEvent>` (bukan `Stream<String>` lagi):

- Di `_streamOpenAICompatible`, gunakan
  `translateOpenAIToClaudeStreamSession(sessionKey, line)` untuk parsing
  tiap baris SSE mentah (bukan `jsonDecode(dataStr)` manual seperti
  sekarang) — hasilnya berupa string SSE Claude-format, lalu di-parse lagi
  untuk diterjemahkan ke `RouterTextDelta`/`RouterToolCall` di atas. INI
  yang memastikan investasi review 3 putaran kita di
  `format_translator.dart` benar-benar terpakai, termasuk fix index
  parallel tool-call.
- Di `_streamGemini`, tambahkan pengecekan eksplisit untuk
  `parts[...]['functionCall']` selain `parts[...]['text']`, emit
  `RouterToolCall` saat ketemu.
- `inference_provider.dart` (nanti, di luar scope task ini) yang akan
  membedakan menangani `RouterTextDelta` (tampilkan token) vs
  `RouterToolCall` (jalankan tool, feed hasilnya balik sebagai
  `ChatMessage` role tool untuk turn berikutnya).

Test `streams Gemini SSE response successfully` dan
`streams OpenAI-compatible response successfully` yang sudah ada perlu
disesuaikan untuk collect `RouterTextDelta` dan gabungkan `.text`-nya,
bukan collect `String` langsung. Tambahkan juga test baru khusus yang
mensimulasikan SSE dengan `tool_calls`/`functionCall` di dalamnya,
verifikasi `RouterToolCall` ter-emit dengan `name`/`argumentsJson` yang
benar.

## 🟠 TINGGI #3 — Provider Anthropic/Claude salah rute

`getProviderEndpoint()` sudah menyiapkan URL untuk `anthropic`/`claude`,
tapi `_dispatchProviderStream()` cuma cek:
```dart
if (provider == 'gemini') { ... } else { _streamOpenAICompatible(...) }
```
Semua provider selain gemini — termasuk anthropic — masuk
`_streamOpenAICompatible`, yang kirim header `Authorization: Bearer` dan
payload format OpenAI. Claude Messages API butuh header `x-api-key` +
`anthropic-version: 2023-06-01`, dan format request beda (system
terpisah, dst — lihat `translateClaudeToOpenAI`/format Claude asli yang
sudah ada).

**Fix:** tambah cabang eksplisit:
```dart
if (provider == 'gemini') {
  yield* _streamGemini(...);
} else if (provider == 'anthropic' || provider == 'claude') {
  yield* _streamAnthropic(...);   // fungsi baru, header x-api-key + anthropic-version
} else {
  yield* _streamOpenAICompatible(...);
}
```
Kalau saat ini A.U.R.A belum benar-benar butuh Claude sebagai provider
cloud (cek lagi apakah ini prioritas), alternatif sementara: HAPUS dulu
Claude dari `getProviderEndpoint()`/daftar provider aktif sampai
`_streamAnthropic` benar-benar diimplementasikan — supaya nggak ada
provider yang "kelihatan didukung" padahal diam-diam salah kirim format.
Jangan biarkan endpoint terdaftar tapi routingnya salah tanpa keterangan.

## 🟡 Minor — sekalian dirapikan

**4. Field `modelResolver` yang di-inject tidak dipakai di `streamGenerate()`**
Constructor `LlmRouterClient` menerima `ModelResolver? modelResolver`, tapi
`streamGenerate()` malah bikin instance `ModelResolver` baru secara lokal
(`final resolver = ModelResolver(...)`). Field yang di-inject cuma dipakai
di `validateKey()`. Pilih salah satu: pakai `this.modelResolver` yang
sudah ada (perlu constructor `ModelResolver` mendukung reconfigure
`isProviderActive`/`comboLookup` per-call), atau kalau memang butuh
instance baru tiap panggilan karena callback beda-beda per request,
hapus saja parameter `modelResolver` dari constructor dan dokumentasikan
kenapa `validateKey()` pakai default plain instance.

**5. Test `tracks cooldown per-provider correctly` tidak menguji apa-apa**
```dart
test('tracks cooldown per-provider correctly', () {
  final client = LlmRouterClient();
  expect(client.isProviderInCooldown('gemini'), isFalse);
  client.validateKey('gemini', 'test_key').ignore();
  expect(client.getCooldownExpiry('gemini'), isNull);
});
```
`validateKey()` tidak ada hubungannya dengan cooldown recording, dan
assert kedua trivially true (memang dari awal null). Ganti dengan test
yang benar-benar memicu cooldown lewat jalur nyata, misal: inject
`MockClient` yang balikin 429, panggil `streamGenerate()` sampai
lempar `LocalFallbackException`, baru assert
`isProviderInCooldown(provider)` jadi `true` dan `getCooldownExpiry`
mengembalikan waktu yang masuk akal (`isAfter(DateTime.now())`).
(Test serupa sebenarnya sudah ada di
`falls back to local when 429 quota is reached on single model` — cukup
pastikan test khusus ini dihapus atau digabung supaya nggak
menyesatkan/redundan.)

## Deliverable
Kirim balik `router_client.dart` + `router_client_test.dart` yang sudah
direvisi untuk 3 item pertama (blocking #1, #2, tinggi #3), dengan test
yang benar-benar memverifikasi:
- Combo dengan format `"provider1/model1,provider2/model2"` ter-parse
  jadi 2+ kandidat yang benar (bukan garbage 1 entry)
- Tool call (baik format OpenAI `tool_calls` maupun Gemini
  `functionCall`) ter-emit sebagai `RouterToolCall`, bukan hilang
- Anthropic/Claude (kalau tetap didukung) memakai header & format yang
  benar, bukan numpang ke jalur OpenAI-compatible

Setelah ini beres, baru saya review ulang sebelum lanjut wiring ke
`inference_provider.dart`.
