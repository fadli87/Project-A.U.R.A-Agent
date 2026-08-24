# Rule: Project Acuan/Referensi

Tidak ada satu project open-source yang mencakup seluruh visi project ini sekaligus.
Kalau stuck di suatu bagian, cek dulu apakah sudah ada pola yang bisa dicontek dari
daftar berikut, sebelum reinvent dari nol.

| Layer / Fase | Project acuan | Kenapa relevan |
|---|---|---|
| Fase 1-2: FFI bridge + Foreground Service | [Llama-Flutter](https://github.com/dragneel2074/Llama-Flutter) | Arsitektur (Dart → Kotlin coroutines → Foreground Service → JNI → llama.cpp) hampir identik dengan rencana project ini; sudah ada deteksi GPU/RAM otomatis |
| Fase 1-2: alternatif plugin FFI | [fllama](https://github.com/Telosnex/fllama), [llama_cpp_dart](https://github.com/netdur/llama_cpp_dart) | Plugin llama.cpp-Flutter yang matang, banyak dipakai sebagai fondasi |
| Fase 1-2: tool-calling siap pakai | [llamafu](https://www.cognisoc.com/blog/llms-on-flutter-dart/) | Plugin Flutter FFI yang sudah mendukung streaming, embeddings, vision, DAN tool calling langsung |
| Fase 3: Chat UI & Model Manager | [Maid](https://github.com/danemadsen/maid) | Full app Flutter open-source: chat UI, model manager, download GGUF dari Hugging Face di app |
| Fase 4: Semantic memory / vector store | [ObjectBox](https://objectbox.io/on-device-vector-database-for-dart-flutter/) | Vector database Dart-native dengan HNSW search — pilihan resmi project ini |
| Fase 4: contoh pipeline RAG | [On-Device AI RAG (ObjectBox + LangChain)](https://github.com/muhammadadilnaeem/on-device-ai-rag-using-objectbox-vector-database-and-langchain), [llmedge_gguf](https://github.com/farmaker47/llmedge_gguf) | Alur ingest → embed → retrieve → generate; llmedge_gguf juga contoh model embedding ringan (all-MiniLM-L6-v2 ONNX) |
| Fase 5: arsitektur tool-calling | [Tool-Neuron](https://github.com/Siddhesh2377/llama.cpp-android) | `ToolManager` model-agnostic (JSON+XML+function-call) — acuan desain skema tool |
| Fase 5: model kecil untuk function-calling | [Octopus V2](https://huggingface.co/NexaAI/Octopus-v2-gguf-awq/blob/main/README.md) | Model 2B khusus function-calling on-device |
| Fase 5: pola permission-gate | [GGUF Loader — Agentic Mode](https://github.com/GGUFloader/gguf-loader) | Contoh matang agent multi-step dengan tool tersandbox + approval card Allow/Deny |
| Fase 7: pola persona & skills asli | [Hermes Agent — SOUL.md docs](https://hermes-agent.nousresearch.com/docs/guides/use-soul-with-hermes), [Hermes Agent — Prompt Assembly docs](https://hermes-agent.nousresearch.com/docs/developer-guide/prompt-assembly) | Sumber langsung pola SOUL.md (persona) dan skills index progresif yang diadaptasi di `.agents/rules/05-persona-skills.md` |

Strategi: mulai dari Llama-Flutter atau fllama sebagai fondasi Fase 1-2, lalu bangun
sendiri layer agentic (Fase 5) dengan referensi pola dari Tool-Neuron dan GGUF Loader.
