# Workflow: Fase 2 — Integrasi Streaming & Concurrency (REVISI: plugin sudah handle FFI+Foreground Service)

> **Update:** Karena `llama_flutter_android` sudah membungkus FFI bridge dan Foreground
> Service secara internal (lihat Fase 1 revisi), fase ini TIDAK LAGI tentang menulis
> `llama_bridge.cpp` atau isolate manual dari nol. Fokus fase ini bergeser ke: memverifikasi
> plugin sudah non-blocking terhadap UI thread, dan menyiapkan lapisan Riverpod di atasnya.

**Tujuan:** Pastikan komunikasi ke plugin non-blocking terhadap UI, dan siapkan
`StreamProvider` yang akan dipakai Fase 3.
**Deliverable akhir:** stream token dari `llama_flutter_android` sudah bisa dikonsumsi
lewat Riverpod tanpa freeze UI, proses tetap hidup saat app di-background.

## Langkah

1. Baca API streaming plugin ini (`generate()` dengan `StreamSubscription` — lihat contoh
   di README repo-nya) — pastikan API ini sudah berjalan di isolate/thread terpisah secara
   internal oleh plugin (cek `LlamaFlutterAndroidPlugin.kt`, bagian Kotlin coroutines).
2. JANGAN panggil `generate()` langsung dari widget tree tanpa provider — bungkus dalam
   satu service/notifier class agar gampang ditest dan diganti nanti.
3. Buat `StreamProvider<String>` (Riverpod) yang membungkus stream token dari plugin.
4. Uji: mulai generate dengan model tier ringan, minimize app — pastikan Foreground
   Service bawaan plugin tetap menjaga proses hidup (notification harus tetap muncul).
5. Uji beban UI: pastikan frame rate tidak drop saat token sedang di-generate (buka
   DevTools performance overlay Flutter untuk cek).
6. Kalau di langkah manapun ternyata plugin BLOCKING UI thread (tidak seperti yang
   diklaim), catat sebagai bug ke `.agents/rules/01-overview-stack.md` dan pertimbangkan
   fallback ke Opsi B (native custom) HANYA untuk bagian yang bermasalah — jangan langsung
   buang seluruh plugin.

## Definition of Done
- [ ] Stream token dari plugin berhasil dikonsumsi lewat `StreamProvider`
- [ ] UI tidak freeze/drop frame saat generate berlangsung
- [ ] Notification Foreground Service tetap muncul saat app di-background selama generate
- [ ] Tidak ada bug blocking yang ditemukan dari plugin (atau sudah didokumentasikan kalau ada)
