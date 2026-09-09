# Addendum 2 — Koreksi bug dari code review hasil generate

Ini hasil review langsung ke file `.dart` yang sudah Agy generate (bukan cuma
plan/laporan), dibandingkan baris demi baris ke source Go asli. Perbaiki
item-item berikut sebelum lanjut ke tahap integrasi.

## 🔴 Prioritas 1 — Tool-call index rusak untuk parallel tool calls

**File**: `models/llm_router_models.dart` + `format_translator.dart`

`OpenAIToolCall` (dan delta tool call di dalam `OpenAIDelta`) tidak punya
field `index`, padahal OpenAI mengirim field ini per tool-call delta untuk
menandai tool call yang mana yang sedang di-update (penting karena satu
turn bisa punya beberapa tool call paralel, masing-masing delta-nya datang
di chunk terpisah).

Saat ini di `translateOpenAIToClaudeStreamSession`:
```dart
for (var i = 0; i < delta!.toolCalls!.length; i++) {
  final tc = delta.toolCalls![i];
  final idx = i;   // SALAH — pakai posisi array lokal
```

**Fix:**
1. Tambah field `index` ke model tool call delta:
```dart
class OpenAIToolCall {
  final String id;
  final String type;
  final OpenAIFunctionCall function;
  final int? index;   // TAMBAHAN

  const OpenAIToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
    this.index,
  });

  factory OpenAIToolCall.fromJson(Map<String, dynamic> json) {
    return OpenAIToolCall(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'function',
      function: /* ... */,
      index: json['index'] as int?,   // TAMBAHAN
    );
  }
}
```
2. Di `translateOpenAIToClaudeStreamSession`, pakai `tc.index ?? 0`, BUKAN
   posisi loop:
```dart
for (final tc in delta!.toolCalls!) {
  final idx = tc.index ?? 0;   // BENAR — sesuai field index asli dari OpenAI
  ...
}
```
Tanpa ini, kalau model manggil 2+ tool sekaligus, argumen tool yang satu
bisa numpuk/nyasar ke buffer tool lain karena semuanya kebaca sebagai
index 0.

## 🟠 Prioritas 2 — Divergensi logic dari source Go

**File**: `format_translator.dart`

1. **`_billingHeaderRegex` — hapus `multiLine: true`**
   Source Go tidak punya flag `(?m)`, jadi `^` cuma match di awal string.
   Versi Dart saat ini pakai `multiLine: true` yang bikin regex mencocokkan
   awal SETIAP baris, berpotensi mencoret baris system prompt yang nggak
   seharusnya kena strip. Hapus parameter itu:
   ```dart
   final _billingHeaderRegex = RegExp(
     r'^x-anthropic-billing-header:[^\n]*(?:\r?\n)?',
     caseSensitive: false,
   );
   ```

2. **`convertClaudeMessage` — jangan hasilkan pesan kosong kalau blocks tidak
   menghasilkan apa pun**
   Di Go, kalau content blocks ada isinya tapi tidak satupun jadi
   text/tool_use/tool_result (misal cuma ada block "thinking"), fungsi
   return `nil` (tidak menghasilkan OpenAI message sama sekali untuk pesan
   itu). Versi Dart saat ini SELALU fallback ke
   `[OpenAIMessage(role: role, content: '')]` di akhir fungsi. Perbaiki jadi:
   ```dart
   if (textParts.isNotEmpty) {
     return [OpenAIMessage(role: role, content: collapseTextParts(textParts))];
   }
   if (blocks.isEmpty) {
     return [OpenAIMessage(role: role, content: '')];
   }
   return const [];   // blocks ada isinya tapi tidak menghasilkan apa-apa -> drop
   ```

3. **`translateOpenAIToClaude` (non-streaming) — tambahkan guard nama tool
   kosong**
   Sebelum menambahkan content block `tool_use`, skip kalau nama fungsi
   kosong (Go punya komentar eksplisit soal ini, referensi bug
   decolua/9router#2077/#3685 — "No such tool available: call_..."):
   ```dart
   if (msg.toolCalls != null) {
     for (final tc in msg.toolCalls!) {
       if (tc.function.name.isEmpty) continue;   // TAMBAHAN
       ...
     }
   }
   ```

4. **`translateOpenAIToClaude` (non-streaming) — panggil `sanitizeToolArgs`**
   Saat ini argumen tool cuma di-`jsonDecode` mentah. Samakan dengan jalur
   streaming yang sudah benar:
   ```dart
   final sanitizedArgs = sanitizeToolArgs(tc.function.name, tc.function.arguments);
   dynamic parsedInput;
   try {
     parsedInput = jsonDecode(sanitizedArgs);
   } catch (_) {
     parsedInput = sanitizedArgs;
   }
   ```

5. **`translateOpenAIToClaude` (non-streaming) — default nama model**
   Tambahkan fallback yang sama seperti di fungsi streaming:
   ```dart
   var modelName = resp.model;
   if (modelName.isEmpty) modelName = 'claude-3-5-sonnet';
   // pakai modelName, bukan resp.model langsung, di field 'model' hasil akhir
   ```

## 🟡 Prioritas 3 — Perbaikan minor, boleh sekaligus dirapikan

**File**: `format_translator.dart`

6. **`cleanGeminiSchema` — enum non-string jangan asal strip semua quote**
   ```dart
   // SALAH — strip semua karakter " di manapun posisinya
   return jsonEncode(item).replaceAll('"', '');

   // BENAR — cuma unwrap kalau hasil encode-nya string murni (diapit quote)
   final encoded = jsonEncode(item);
   if (encoded.length >= 2 && encoded.startsWith('"') && encoded.endsWith('"')) {
     return encoded.substring(1, encoded.length - 1);
   }
   return encoded;
   ```

7. **Stop-reason inference — hapus kondisi tambahan `|| toolCalls.isNotEmpty`**
   Baik di `translateOpenAIToClaude` maupun
   `translateOpenAIToClaudeStreamSession`, samakan persis ke Go: mapping
   `tool_use` HANYA kalau `finishReason == 'tool_calls'`, tanpa kondisi OR
   tambahan. Kalau ternyata kondisi tambahan itu memang sengaja buat
   menangani provider non-standar yang lupa kirim `finish_reason` yang
   benar, catat itu sebagai keputusan sadar di `PORT_REPORT.md`
   (bukan silent deviation).

**File**: `model_resolver.dart`

8. **Fallback provider list — eksplisitkan, jangan campur sepihak**
   Saat ini: `['openai', 'anthropic', 'deepseek', 'gemini']` (Go cuma 3,
   Dart nambah gemini sendiri). Putuskan salah satu secara sadar:
   - (a) ikut persis Go: `['openai', 'anthropic', 'deepseek']`, atau
   - (b) pakai semua 8 provider yang sudah dikurasi di `providerAliasMap`
     (openai, anthropic, claude, gemini, groq, deepseek, openrouter,
     mistral)
   Opsi (b) lebih masuk akal untuk A.U.R.A karena konsisten sama alias yang
   sudah di-trim, tapi harus ditulis sebagai keputusan eksplisit di
   `PORT_REPORT.md`, bukan nyelip diam-diam.

9. **`translateOpenAIToClaude` — urutan cek `msgId` untuk edge case
   `"chatcmpl-chat"`**
   Samakan urutan ke Go: strip prefix `chatcmpl-` DULU, baru cek apakah
   hasilnya kosong ATAU `"chat"` untuk generate ulang:
   ```dart
   var msgId = resp.id;
   if (msgId.isEmpty) {
     msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
   } else {
     msgId = msgId.replaceFirst('chatcmpl-', '');
     if (msgId.isEmpty || msgId == 'chat') {
       msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
     }
   }
   ```

## Setelah diperbaiki
Update unit test yang relevan (khususnya tambahkan test case untuk parallel
tool calls di `format_translator_test.dart` — ini yang paling penting karena
bug #1 nggak akan ketahuan tanpa test yang eksplisit mensimulasikan 2+ tool
call paralel dalam satu stream). Update juga `PORT_REPORT.md` untuk mencatat
keputusan sadar di item #7 dan #8 di atas.

Kirim lagi hasil revisinya (file kode, bukan cuma laporan) untuk saya review
ulang sebelum masuk tahap integrasi ke `main.dart`/provider Riverpod.
