# PORT REPORT: Porting 9router-go Logic ke Dart (aura_core)

Laporan komprehensif implementasi porting logika murni routing multi-provider LLM dari repositori Go [`luqman-v1/9router-go`](https://github.com/luqman-v1/9router-go) ke package Dart [`aura_core`](file:///l:/dev_app/aura_monorepo/Project-A.U.R.A-Agent/aura_core/).

Semua file dibuat sebagai **Pure Dart** (`dart:convert`, `dart:async`) tanpa dependensi HTTP/DB eksternal langsung di modul logika.

---

## 1. Daftar File & Modul yang Di-porting

Target lokasi: `aura_core/lib/src/llm_router/`

### A. Data Models (`models/llm_router_models.dart`)
* **OpenAI Models**: `OpenAIImageUrl`, `OpenAIContentBlock`, `OpenAIFunctionCall`, `OpenAIToolCall`, `OpenAIMessage`, `OpenAIFunction`, `OpenAITool`, `OpenAIRequest`, `OpenAIUsage`, `OpenAIDelta`, `OpenAIChoice`, `OpenAIResponse`.
* **Claude Models**: `ClaudeSystemBlock`, `ClaudeSource`, `ClaudeContentBlock`, `ClaudeMessage`, `ClaudeThinkingConfig`, `ClaudeOutputConfig`, `ClaudeToolChoice`, `ClaudeTool`, `ClaudeRequest`.
* **Routing & Fusion Models**: `ModelInfo`, `FusionAnswer`, `FusionResult`, `FusionTuning`.
* *Catatan Visibility*: `FusionAnswer` dan `FusionResult` di Go berhuruf kecil (`fusionAnswer`, `fusionResult`), namun dijadikan class publik di Dart agar dapat dipakai secara aman lintas modul.

### B. Format Translator (`format_translator.dart`)
Port dari `internal/translator/request.go`, `response.go`, `schema.go`, `sanitize.go`, `tool_schema.go`:
* `requiresMaxCompletionTokens(String model)`: Mendeteksi `gpt-5` dan seri `o1-`, `o3-`, `o4-` (port PR #3657).
* `stripAnthropicBillingHeader(String text)`: Menghapus header billing internal Anthropic dari string prompt.
* `parseSystemPrompt(dynamic systemRaw)`: Mendukung prompt teks tunggal maupun array of blocks.
* `systemReminderText(String content)` & `collapseTextParts`: Pembungkus `<instructions>` dan penggabung bagian teks.
* `convertClaudeMessage(ClaudeMessage msg)`: Mengonversi pesan Claude (termasuk tool_use, tool_result, thinking/reasoning, dan base64 image) menjadi format OpenAI.
* `fixMissingToolResponsesOpenAI(List<OpenAIMessage> messages)`: Menyisipkan placeholder `[No response received]` untuk tool-call yang tidak memiliki respon balik agar tidak ditolak oleh OpenAI.
* `convertToolChoice(dynamic choiceRaw)`: Mengonversi pilihan tool `auto`, `any` (`required`), atau spesifik tool.
* `translateClaudeToOpenAI(Map<String, dynamic> claudeBody)`: Mengonversi seluruh request body Claude ke format OpenAI.
* **Claude Compatibility (Addendum Section 2)**:
  - `sanitizeClaudePassthrough(Map<String, dynamic> body)`: Menghapus `server_tool_use` foreign dengan id yang tidak cocok dengan `^srvtoolu_`, `tool_result` yatim yang merujuk padanya, text block kosong, dan pesan kosong.
  - `defaultClaudeToolType(Map<String, dynamic> body)`: Memberikan nilai default `"type": "custom"` untuk tool yang tidak memiliki field `type`.
  - `lastCacheableToolIndex(List<dynamic>? tools)`: Menemukan indeks tool terakhir yang tidak memiliki `defer_loading: true`.
  - `anchorClaudeCache(Map<String, dynamic> body)`: Memasang prompt-caching breakpoint `cache_control: {type: ephemeral, ttl: 1h}` pada tool terakhir non-deferred.
  - `applyClaudeCompatPipeline(Map<String, dynamic> body)`: Menjalankan pipeline 3-langkah terurut: `sanitizeClaudePassthrough` → `defaultClaudeToolType` → `anchorClaudeCache`.
* **Response Translation & Usage**:
  - `parseClaudeUsage(Map<String, dynamic> body)` & `parseResponseUsage(Map<String, dynamic> body)`: Mengekstrak token prompt, completion, dan cache input/creation.
  - `translateOpenAIToClaude(Map<String, dynamic> openaiResp)`: Mengonversi response OpenAI menjadi format message Claude non-streaming.
  - `translateOpenAIToClaudeStreamSession(String sessionKey, String openaiChunkRaw)`: Mengonversi chunk SSE streaming OpenAI menjadi Claude SSE event blocks (`message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`) yang terisolasi per session, mendukung auto-rejoin fragment JSON terpotong.
  - `translateOpenAIToClaudeStream(String openaiChunkRaw)`: Versi praktis single chunk SSE stream.
  - `ensureStreamClosed(String sessionKey)`: Memastikan stream ditutup secara rapi (`end_turn`, `message_stop`) jika upstream terputus sebelum mengirimkan `finish_reason`.
  - `clearStreamState(String sessionKey)` & `getStreamUsage(String sessionKey)`: Pembersihan lifecycle session dan ekstraksi akumulasi usage token.
  - `seedStreamState(String sessionKey, String model)`: Pre-seeding model name pada session agar `message_start` meng-echo nama model permintaan klien.
* **Schema & Argument Sanitization**:
  - `cleanGeminiSchema(Map<dynamic, dynamic> schema)` & `cleanParametersSchema(dynamic raw)`: Membersihkan kata kunci JSON schema yang ditolak parser protobuf Gemini (e.g. `minLength`, `format`, `prefixItems`, dll.) dan menambahkan reason placeholder untuk object kosong.
  - `sanitizeOpenAITools(Map<String, dynamic> body)`: Menjalankan sanitasi skema pada seluruh tool di body request OpenAI.
  - `normalizeToolSchemasForProvider(String provider, List<dynamic> tools)`: Menghapus regex pattern yang tidak valid khusus untuk provider `openrouter`.
  - `sanitizeToolArgs(String toolName, String argsJson)` beserta `sanitizeSearchArgs`, `sanitizeReadArgs`, `sanitizeFetchArgs`: Normalisasi argumen pemanggilan tool pencarian web, pembacaan file, dan pengambilan URL.

### C. Model Resolver (`model_resolver.dart`)
Port dari `internal/handlers/chat/resolution.go` & `internal/providers/aliases.go`:
* `stripModelContextMarker(String modelStr)`: Menghapus trailing marker `[1m]` yang disematkan klien Claude Code untuk 1M context beta.
* `resolveProviderAlias(String alias)`: Memetakan short alias provider menjadi ID canonical provider.
* `flattenComboModels(List<String> models)`: Rekursif mengekspansi model combo bertingkat menjadi leaf konkret `provider/model`, men-deduplikasi entri berurutan yang identik, dan mendeteksi siklus.
* `resolveModelEntry(String entry)` & `resolveModel(String modelStr)`: Me-resolve string model melalui hierarki alias, combo, dan format standar `provider/model`.

### D. Model Fusion (`fusion.dart`)
Port dari `internal/handlers/chat/combo_fusion.go`:
* `flattenToolHistory(List<dynamic> msgs)`: Mengonversi riwayat tool turn menjadi teks naratif agar model panel memahami konteks tanpa terpicu meng-emit tool_calls baru.
* `buildJudgePrompt(List<FusionAnswer> answers)`: Menyusun prompt sistem anonymized untuk model Judge (`[Source 1]`, `[Source 2]`, dst.).
* `extractPanelText(Map<String, dynamic> body)`: Ekstraksi teks jawaban dari response JSON OpenAI.
* `appendUserTurn(Map<String, dynamic> body, String content)`: Menambahkan turn user baru ke request payload.
* `collectPanel(List<Future<FusionResult> Function()> calls, {FusionTuning tuning})`: Mengumpulkan respon dari multiple model secara konkuren dengan mekanisme Quorum ([FusionTuning.minPanel]) dan grace timer.

### E. Stall Detection (`stall_detection.dart`)
Port dari `internal/proxy/stall.go`:
* `StallTimeoutException`: Exception saat stream SSE idle melebihi batas waktu.
* `StallDetectionTransformer<T>` & `StallDetectionExtension`: Stream transformer yang me-reset idle timer setiap kali data chunk masuk, dan menutup stream dengan error jika idle melebihi batas (default 6 menit).

### F. Retry & Backoff (`retry_backoff.dart`)
Port dari `internal/handlers/chat/fallback.go` & `internal/providers/errorclassify.go`:
* `extractErrorText(dynamic body)`: Ekstraksi pesan error dari respons JSON.
* `extractRetryAfter(dynamic body)`: Parsing timestamp/delay dari `retryAfter`, `retry_after`, `resetsAt`, dsb.
* `formatRetryAfter(String isoTimestamp)`: Format countdown `"reset after Xm Ys"`.
* `getQuotaCooldown(int backoffLevel)`: Menghitung exponential backoff: level 0/1 -> 2s, level 2 -> 4s, level 3 -> 8s, dst. (cap 5 menit).
* `classifyError(int statusCode, String errorText, int currentBackoffLevel)`: Klasifikasi error berdasarkan aturan teks dan status code HTTP.

---

## 2. Rincian Penyesuaian Sesuai Addendum

### A. Provider Alias Map Di-trim (Bukan Full-Copy)
Pada source Go asli (`internal/providers/aliases.go`), terdapat lebih dari 70 alias. Sebagian besar merujuk pada provider niche, IDE resmi, atau service yang diexclude.

**Alias yang Dipertahankan untuk A.U.R.A**:
```dart
const providerAliasMap = <String, String>{
  'oa': 'openai',
  'ant': 'anthropic',
  'cc': 'claude',
  'gc': 'gemini',
  'gq': 'groq',
  'ds': 'deepseek',
  'or': 'openrouter',
  'mm': 'mistral',
};
```

**Daftar Alias yang Dibuang (~60 entri)**:
* **IDE / Niche Provider Excluded**: `tr` (trae), `ws` (windsurf), `qd` (qoder), `kr` (kiro), `cd` (codebuddy-cn), `cbai` (codebuddy-intl), `cl` (cline), `cp` (clinepass), `cu` (cursor), `cx` (codex), `dv` (devin-cli), `oc` (opencode), `ocg` (opencode-go), `kc` (kilocode), `zd` (zed).
* **Stealth / Decoy Tools**: `ag` (antigravity).
* **China / Niche Specific**: `ali` (alicode), `alii` (alicode-intl), `alitp` (alitp-intl), `ali-tp` (alitp-intl), `ark` (volcengine-ark), `vali` (volcengine-ark), `bpm` (byteplus), `glmcn` (glm-cn), `hunyuan` (tencent), `if` (iflow), `km` (kimi), `mimo` (xiaomi-mimo), `mmf` (mimo-free), `xmtp` (xiaomi-tokenplan), `qianfan` (baidu), `bzl` (bazaarlink), `bm` (bluesminds), `xq` (xquik).
* **Audio / Specialized Media**: `aai` (assemblyai), `dg` (deepgram), `el` (elevenlabs), `fish` (fish-audio), `polly` (aws-polly), `fal` (fal-ai), `bfl` (black-forest-labs), `runway` (runwayml), `stability` (stability-ai).
* **Other Platforms**: `az` (azure), `bb` (blackbox), `brave` (brave-search), `cb` (cerebras), `cf` (cloudflare-ai), `ch` (chutes), `cmc` (commandcode), `fl` (featherless), `fw` (fireworks), `gb` / `gcli` / `gw` (grok-cli/web), `gh` (github), `gl` (gitlab), `gpse` (google-pse), `hf` (huggingface), `hyp` (hyperbolic), `jina` (jina-ai), `nb` (nanobanana), `ne` (nebius), `nv` (nvidia), `pa` / `pplx` / `pw` (perplexity), `tg` (together), `vercel` (vercel-ai-gateway), `vn` (venice), `af` (api-airforce), `kgw` (kilo-gateway), `samba` (sambanova).

### B. Konfirmasi 3 Fungsi Claude-Compatibility & Pipeline 3 Langkah
Ketiga fungsi Claude-compatibility telah diimplementasikan dan diuji:
1. `sanitizeClaudePassthrough`
2. `defaultClaudeToolType`
3. `anchorClaudeCache` (dengan helper `lastCacheableToolIndex`)
Pipeline dieksekusi secara terurut melalui fungsi praktis `applyClaudeCompatPipeline`:
$$\text{sanitizeClaudePassthrough} \longrightarrow \text{defaultClaudeToolType} \longrightarrow \text{anchorClaudeCache}$$

### C. Konstanta Numerik Eksak Sesuai Source Go
* `FusionTuning`: `minPanel = 2`, `stragglerGraceMs = 8000`, `panelHardTimeoutMs = 90000`.
* `defaultStallTimeout`: `Duration(minutes: 6)`.
* `backoffBaseMs`: `2000` (2 detik).
* `backoffMaxMs`: `300000` (5 menit).
* `backoffMaxLevel`: `15`.
* `transientCooldownMs`: `30000` (30 detik).
* `cooldownLong`: `120000` (2 menit).
* `cooldownShort`: `5000` (5 detik).

### D. Rincian Penyesuaian & Keputusan Sadar (Addendum 2)
1. **Parallel Tool Calls (`OpenAIToolCall.index`)**: Menambahkan field `index` ke `OpenAIToolCall`. Pada streaming translation `translateOpenAIToClaudeStreamSession`, routing delta tool menggunakan `tc.index ?? 0`, bukan indeks perulangan lokal `i`, sehingga argumen tool call paralel tidak tertukar.
2. **`_billingHeaderRegex`**: Menghapus `multiLine: true` agar pencocokan `^` hanya berlaku di awal string prompt penuh (sesuai Go), mencegah terhapusnya baris di tengah system prompt.
3. **`convertClaudeMessage`**: Mengembalikan `const []` (drop message) jika content blocks hanya berisi block non-producing (seperti `thinking`) tanpa teks atau tool hasil, persis seperti Go.
4. **Guard Nama Tool Kosong & Sanitasi Argumen**: Menambahkan pengecekan `tc.function.name.isEmpty` pada `translateOpenAIToClaude` non-streaming dan memanggil `sanitizeToolArgs`, mencegah error *"No such tool available: call_..."*.
5. **Model Fallback**: Jika `resp.model` kosong, non-streaming translation otomatis fallback ke `'claude-3-5-sonnet'`.
6. **Enum Sanitasi Gemini**: Unwrap quote hanya jika hasil JSON encoding diawali dan diakhiri dengan double quote, sehingga double quote internal string tetap aman.
7. **Stop-Reason Tool-Use (Keputusan Sadar)**: Menghapus kondisi inferensi tambahan `|| toolCalls.isNotEmpty`. Stop reason `tool_use` dipetakan secara eksak hanya bila `finishReason == 'tool_calls'` (sesuai Go).
8. **Provider Fallback List (Keputusan Sadar)**: Pada `resolveModel`, fallback list diselaraskan secara konsisten menggunakan 8 provider yang telah dikurasi pada `providerAliasMap` (`openai`, `anthropic`, `claude`, `gemini`, `groq`, `deepseek`, `openrouter`, `mistral`).
9. **`msgId` Normalization Order**: Strip prefix `chatcmpl-` terlebih dahulu sebelum memeriksa apakah ID kosong atau bernilai `"chat"`.

---

## 3. Komponen yang Sengaja Dikecualikan (Exclusion List)

Sesuai aturan ketat pada `AGY_TASK_9router_to_dart.md`:
1. **`internal/translator/antigravity.go`**: Dikecualikan sepenuhnya karena berisi logika penyemaran IDE, decoy tools, `_ide` suffix, manipulasi fingerprint, dan competitive prompt stripping.
2. **`internal/handlers/chat/antigravity_quota.go` & `antigravity_project.go`**: Dikecualikan karena terkait mekanisme penyemaran yang sama.
3. **`internal/mitm/`**: Dikecualikan karena berkaitan dengan intercept network proxy tingkat server, bukan logika klien A.U.R.A.
4. **`internal/updater/`, `internal/shutdown/`, `internal/tracing/`, `internal/headroom/`**: Dikecualikan karena merupakan infrastruktur daemon Go server / Next.js proxy dashboard.
5. **Endpoint Media (`/v1/images/*`, `/v1/videos/*`, `/v1/audio/*`)**: Dikecualikan dari scope router LLM teks/multimodal chat saat ini.

---

## 4. Hasil Verifikasi & Unit Tests

Semua pengujian dijalankan dengan Flutter & Dart SDK pada paket `aura_core`:
* **Unit Tests**:
  - `test/llm_router/format_translator_test.dart` (25 test passed)
  - `test/llm_router/model_resolver_test.dart` (5 test passed)
  - `test/llm_router/fusion_test.dart` (6 test passed)
  - `test/llm_router/stall_detection_test.dart` (2 test passed)
  - `test/llm_router/retry_backoff_test.dart` (10 test passed)
  - **Total: 48 tests passed (0 failures).**
* **Static Analysis**:
  - `flutter analyze lib/src/llm_router/ test/llm_router/`
  - **Hasil: 0 issues found (clean).**
