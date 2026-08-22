# Workflow: Fase 6 — Testing, Optimasi Performa & Thermal

**Tujuan:** Validasi performa nyata di device fisik dan tuning supaya app tetap terpakai
dalam waktu lama (baterai, suhu).
**Deliverable akhir:** benchmark terdokumentasi per tier model, tidak ada crash OOM di
tier terendah yang didukung.

## Langkah

1. Uji di device fisik nyata untuk SETIAP tier (Ringan/Standar/Lanjut) — emulator tidak
   akurat untuk performa, jangan andalkan hasil dari emulator.
2. Ukur dan catat: tokens/detik, suhu device (sebelum/selama/sesudah sesi panjang),
   drainase baterai per menit penggunaan — untuk masing-masing tier model.
3. Deteksi thermal throttling: jalankan sesi generate panjang (>5 menit kontinu), catat
   penurunan tokens/detik dari waktu ke waktu.
4. Tuning jumlah thread CPU yang dipakai llama.cpp — cari titik seimbang antara kecepatan
   dan panas berlebih, bukan selalu maksimalkan thread count.
5. Tuning context window default — lebih kecil dari maksimum model kalau itu terbukti
   mengurangi throttling tanpa banyak mengorbankan kualitas jawaban.
6. Tuning strategi eviction memori ObjectBox/SQLite kalau ukuran database mulai
   berpengaruh ke waktu retrieval.
7. Validasi kriteria sukses akhir project (lihat PRD §9): recall memori lama berfungsi,
   minimal 2 tool end-to-end, kecepatan tier Standar layak untuk percakapan real-time,
   tidak ada crash OOM di tier terendah.

## Definition of Done
- [ ] Benchmark tokens/detik, suhu, dan baterai terdokumentasi per tier model
- [ ] Tidak ada crash OOM pada device tier terendah yang didukung
- [ ] Thread count dan context window default sudah di-tuning berdasarkan data, bukan tebakan
- [ ] Semua kriteria sukses di PRD §9 terpenuhi
