# Addendum — Koreksi untuk plan port 9router-go → Dart

Ini lanjutan dari `AGY_TASK_9router_to_dart.md`. Plan yang sudah Agy susun
sudah bagus dan patuh exclusion list, tapi ada 3 koreksi/tambahan sebelum
mulai generate kode betulan.

## 1. Provider alias map — TRIM, jangan full-copy

Source asli (`internal/providers/aliases.go`) punya `ProviderAliasMap`
berisi ~70 entry, termasuk alias untuk provider yang SUDAH kita exclude
(`tr -> trae`, `ws -> windsurf`, `qd -> qoder`, `kr -> kiro`,
`cd -> codebuddy-cn`, `mimo -> xiaomi-mimo`, `if -> iflow`, `cx -> codex`,
`cu -> cursor`, `cl -> cline`, `gh -> github`, `hf -> huggingface`, dll —
sebagian besar tidak relevan untuk A.U.R.A).

**Jangan copy-paste seluruh map ini.** Buat `providerAliasMap` versi Dart
yang HANYA berisi provider yang benar-benar akan dipakai A.U.R.A:

```dart
const providerAliasMap = <String, String>{
  'oa': 'openai',
  'ant': 'anthropic',
  'cc': 'claude',       // kalau dipakai terpisah dari 'anthropic'
  'gc': 'gemini',       // CATATAN: di source asli 'gc' -> 'gemini-cli',
                         // bukan 'gemini' polos — untuk A.U.R.A pakai
                         // mapping yang masuk akal sendiri, jangan asal
                         // contek dari source Go
  'gq': 'groq',
  'ds': 'deepseek',
  'or': 'openrouter',
  'mm': 'mistral',       // sesuaikan lagi kalau salah cocokin
};
```

Kalau nanti mau nambah provider baru, tambah manual satu-satu — jangan
sinkron otomatis dari source Go.

## 2. Tambahkan 3 fungsi Claude-compat yang kelewat di plan

Ini fungsi generik (bukan provider-niche), dari `request.go`, port juga ke
`format_translator.dart`:

- **`sanitizeClaudePassthrough`** — port dari `SanitizeClaudePassthrough`.
  Membersihkan: (a) `server_tool_use` block dengan id yang tidak valid +
  `tool_result` yatim yang mereferensikannya, (b) text block kosong
  (Anthropic API menolak dengan 400 kalau ada), (c) message dengan content
  yang jadi kosong setelah dibersihkan.
- **`defaultClaudeToolType`** — port dari `DefaultClaudeToolType`. Kasih
  default `"type": "custom"` ke tool yang tidak punya field `type` (beberapa
  gateway Anthropic-compatible strict soal ini).
- **`anchorClaudeCache`** + **`lastCacheableToolIndex`** — port dari
  `AnchorClaudeCache` / `LastCacheableToolIndex`. Menaruh breakpoint
  prompt-caching (`cache_control: {type: ephemeral, ttl: 1h}`) di tool
  terakhir yang TIDAK punya `defer_loading: true`, karena Anthropic API
  menolak kombinasi `defer_loading: true` + `cache_control` di tool yang
  sama. Berguna untuk hemat token kalau A.U.R.A pakai tools sama Claude.

Panggil urutannya: sanitize dulu → baru anchor cache (sama seperti alur di
`TranslateClaudeToOpenAI` versi Go).

## 3. Eksplisitkan angka default sebagai konstanta

Jangan biarkan Agy menebak sendiri angka-angka ini — pakai persis nilai dari
source Go supaya perilaku tetap konsisten:

```dart
// fusion.dart
class FusionTuning {
  final int minPanel;
  final int stragglerGraceMs;
  final int panelHardTimeoutMs;

  const FusionTuning({
    this.minPanel = 2,
    this.stragglerGraceMs = 8000,
    this.panelHardTimeoutMs = 90000,
  });
}

// stall_detection.dart
const defaultStallTimeout = Duration(minutes: 6);

// retry_backoff.dart
const backoffBaseMs = 2000;      // 2 detik
const backoffMaxMs = 5 * 60000;  // 5 menit cap
const backoffMaxLevel = 15;
const transientCooldownMs = 30000; // 30 detik, untuk error yang tidak match rule manapun
```

## Setelah addendum ini diterapkan
Update `PORT_REPORT.md` supaya juga mencatat:
- Alasan alias map di-trim (bukan full-copy) + daftar alias mana saja yang
  sengaja dibuang
- Konfirmasi 3 fungsi Claude-compat di atas sudah termasuk, bukan
  ke-skip

Baru setelah itu boleh lanjut generate kode.
