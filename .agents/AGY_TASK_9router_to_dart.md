# Task untuk Agy (Antigravity): Port logic 9router-go ke Dart (aura_core)

## Konteks
Kita mau ambil **logic murni** (bukan seluruh server) dari repo Go
`9router-go` (https://github.com/luqman-v1/9router-go) dan port ke Dart,
supaya `aura_core` (A.U.R.A) bisa punya kemampuan hybrid routing ke
multi-provider cloud LLM (OpenAI/Claude/Gemini/Groq) selain inference lokal
via llama.cpp yang sudah ada.

Referensi gaya kode: file `combo_strategy.dart` yang sudah dibuat duluan
(lampirkan file ini ke context Agy) — ikuti pola yang sama:
- Pure Dart, tanpa dependency HTTP/DB di dalam file logic-nya sendiri
- Kapabilitas/checker eksternal di-inject via `typedef` callback, jangan
  hardcode
- Komentar dart-doc (`///`) di tiap public class/method, sebutkan port dari
  fungsi Go yang mana

## ATURAN PALING PENTING — JANGAN DILANGGAR
**JANGAN port, JANGAN referensikan, dan JANGAN ambil ide dari bagian-bagian
berikut di repo Go sumber:**
- `internal/translator/antigravity.go` — SELURUH file ini (tool cloaking,
  decoy tools, `_ide` suffix, `StripCompetitivePrompts`,
  `competitivePromptBlacklist`). Ini fitur untuk menyamar sebagai client IDE
  resmi dan menghindari deteksi anti-abuse provider lain — tidak boleh masuk
  ke A.U.R.A dalam bentuk apa pun.
- `internal/handlers/chat/antigravity_quota.go`,
  `internal/handlers/chat/antigravity_project.go` — terkait mekanisme yang
  sama.
- Semua executor provider yang sangat spesifik & tidak relevan buat A.U.R.A:
  Qoder, CodeBuddy, Trae, Windsurf, Kimchi, Kiro, Codex-CLI-khusus,
  Opencode-desktop-fingerprint, Mimo/Mimofree, iFlow, Azure-khusus,
  no-auth/free-tier proxy pool routing.
- Kalau ragu apakah sebuah fungsi termasuk kategori ini: **skip dan tanyakan
  ke saya dulu**, jangan diputuskan sendiri.

Kalau nemu fungsi yang jelas cuma berguna untuk hal di atas, cukup catat di
laporan akhir "diabaikan karena X", tidak perlu di-port.

## Scope yang HARUS di-port

Target struktur di `aura_core/lib/src/llm_router/` (buat folder baru ini):

### 1. `format_translator.dart`
Port dari `internal/translator/request.go` + `response.go` + `schema.go` +
`sanitize.go` + `tool_schema.go` — **hanya bagian generik OpenAI ↔ Claude
↔ Gemini**, skip apa pun yang jelas Gemini-eksotis (thoughtSignature
backfill khusus Gemini 3.8, dll) kecuali saya bilang sebaliknya nanti.

Fungsi prioritas untuk di-port (nama Dart boleh disesuaikan idiom Dart):
- `parseSystemPrompt`, `convertClaudeMessage`,
  `fixMissingToolResponsesOpenAI`, `convertToolChoice`,
  `TranslateClaudeToOpenAI` — transformasi request Claude→OpenAI format
- `ParseClaudeUsage`, `ParseResponseUsage`, `TranslateOpenAIToClaude`,
  `TranslateOpenAIToClaudeStream(Session)` — transformasi response +
  streaming OpenAI→Claude format
- `cleanGeminiSchema`, `CleanParametersSchema`, `SanitizeOpenAITools`,
  `NormalizeToolSchemasForProvider` — bersihin JSON schema tool supaya
  kompatibel antar-provider
- `sanitizeToolArgs` dan turunannya (`sanitizeFetchArgs`,
  `sanitizeSearchArgs`, `sanitizeBashArgs`, `sanitizeReadArgs`) — HANYA kalau
  A.U.R.A memang punya tool-calling jenis itu (fetch/search/bash/read file);
  kalau tidak relevan, skip dan catat di laporan.

### 2. `model_resolver.dart`
Port dari `internal/handlers/chat/resolution.go`:
- `resolveModel`, `resolveProviderAlias`, `flattenComboModels`,
  `stripModelContextMarker`, `resolvePrefixProvider`
- Tujuan: parsing string model format `"provider/model"`, alias resolution,
  dan flatten kalau satu entry combo ternyata referensi ke combo lain.

### 3. `fusion.dart`
Port dari `internal/handlers/chat/combo_fusion.go`:
- `flattenToolHistory`, `buildJudgePrompt`, `extractPanelText`,
  `appendUserTurn`
- `collectPanel` → di Dart pakai `Future.wait` + per-`Future` timeout
  (jangan literal port goroutine/channel Go, sesuaikan idiom
  `async`/`Future`/`Stream`)
- Fitur ini opsional dipakai belakangan (multi-model panel + judge), tapi
  tetap port sekarang biar lengkap.

### 4. `stall_detection.dart`
Port konsep dari `internal/proxy/stall.go` (`StallReader`,
`NewStallReaderWithContext`):
- Implementasikan sebagai `StreamTransformer` atau wrapper `Stream<List<int>>`
  yang reset `Timer` tiap kali ada chunk masuk, dan otomatis close/error kalau
  tidak ada data selama N menit (default 6 menit, buat jadi parameter).

### 5. `retry_backoff.dart`
Port dari `internal/handlers/chat/fallback.go` (bagian yang generik saja,
BUKAN `tryForwardWithConnection` yang penuh detail HTTP Go):
- `extractErrorText`, `extractRetryAfter`, `formatRetryAfter`
- Plus error classification table dari README (`"rate limit"` →
  exponential backoff, 429 → exponential backoff, dst) — buat sebagai
  konstanta/enum yang gampang di-lookup, bukan hardcoded di banyak tempat.

## Yang TIDAK perlu di-port (biar Agy tidak buang waktu)
- Semua yang di dalam `internal/mitm/` — ini terkait intercept traffic,
  bukan buat A.U.R.A
- `internal/updater/`, `internal/shutdown/`, `internal/tracing/` — infra
  server Go, tidak relevan untuk app Flutter
- Endpoint media generation (`/v1/images/*`, `/v1/videos/*`,
  `/v1/audio/*`) kecuali saya minta lain waktu
- `internal/headroom/` (proxy token compression khusus dashboard Next.js)

## Konvensi kode
- Ikuti struktur folder & state-management yang sudah ada di `aura_core`
  (cek `lib/src/agent/`, `lib/src/memory/` sebagai referensi pola yang sudah
  dipakai)
- Kalau butuh model data (mis. `OpenAIMessage`, `ClaudeMessage`), buat
  sebagai class immutable dengan `fromJson`/`toJson`, taruh di
  `llm_router/models/`
- Tulis unit test minimal untuk tiap fungsi transformasi (input JSON contoh
  → output JSON yang diharapkan) di `test/llm_router/`
- JANGAN tambahkan dependency pubspec baru tanpa nanya dulu — usahakan pure
  Dart (`dart:convert`, `dart:async`) semaksimal mungkin

## Deliverable
1. Kelima file di atas + folder `models/` pendukung
2. Unit test untuk masing-masing
3. Laporan singkat (`PORT_REPORT.md`) berisi: fungsi Go apa saja yang
   di-skip dan alasannya, terutama kalau ada yang di luar exclusion list di
   atas tapi Agy putuskan untuk skip sendiri

## Setelah selesai
Jangan langsung integrasikan ke `main.dart`/provider Riverpod dulu — stop di
level file-file di atas + test. Saya (lewat chat ini) yang akan review hasil
generate-nya dulu sebelum lanjut ke tahap integrasi ke UI/agent loop.
