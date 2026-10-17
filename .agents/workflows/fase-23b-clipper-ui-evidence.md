# Workflow: Fase 23b — AURA Clipper: Bukti UI Nyata & Pembersihan (sebelum dianggap selesai)

Baca `rules/19-aura-clipper.md` dan `fase-23-clipper-ui-desktop.md` (bagian C) dulu.

**Konteks:** Review `45feba4`. Bagian 0 (LLM nyata, heatmap nyata, caption tumpang tindih,
sanitasi nama) diterima. Struktur UI dan glue host rapi, `main.dart` minimal. Tetapi laporan
Fase 23 mencentang "Alur penuh dari UI", "Batal", dan "Chat & Trading Lab normal" **tanpa
satu pun bukti yang dijalankan**: tidak ada tangkapan layar, tidak ada `flutter run`/`build
windows`, dan checklist Insiden 00 dibuktikan dengan alasan ("tidak tersentuh"), bukan
dengan menjalankannya. Widget test hanya 3 (render, `ClipListView`, `ExportPanel`); tidak ada
test untuk `ClipperNotifier` maupun status/error `ClipperScreen` dengan pipeline palsu,
padahal diminta di Fase 23 bagian C.1.

## 1. Uji manual di Windows (wajib, dengan bukti)
`cd aura_desktop && flutter clean && flutter pub get && flutter run -d windows`
(Insiden 7: plugin native baru `fvp`). Lampirkan **tangkapan layar** (simpan di
`.agents/reports/img/fase23/`, tanpa data pribadi/API key) untuk:
1. Tab Clipper terbuka; keadaan tanpa API key (pesan ramah).
2. Video `406RNDgauvQ`: progres tiap stage → daftar kandidat → pratinjau **benar-benar
   memutar** dan jeda otomatis di `endTime` → ekspor 2 klip → "Buka folder" → file ada.
3. **Batal** di tengah unduhan lewat tombol UI: tempel `tasklist | findstr /i "yt-dlp ffmpeg"`
   sesudahnya (kosong) dan tidak ada `.part` di folder job.
4. Error ramah: URL tidak valid; path yt-dlp salah (via dialog Pengaturan → Cek Tool ✘).
5. Chat: kirim satu pesan; Trading Lab: buka layar. Keduanya normal (checklist 00 dijalankan).
Jika pratinjau tidak memutar (mis. fvp gagal mendaftar), perbaiki dan catat penyebabnya.

## 2. Test yang kurang
- `ClipperNotifier` dengan pipeline palsu: sukses (status → kandidat), error (pesan ramah),
  dibatalkan (`cancelled`, bukan `error`), ekspor banyak klip.
- Widget test `ClipperScreen`: tampil progres, tampil kandidat, tampil banner error.

## 3. Pembersihan kecil
- `video_player` dan `fvp` hanya dipakai di `aura_clipper`; **hapus dari `aura_desktop/pubspec.yaml`**
  jika build tetap berjalan (dependency transitif cukup; Insiden 2). Catat hasilnya.
- `ClipperNotifier` memakai `StateNotifier` dari `flutter_riverpod/legacy.dart`, sedangkan
  Fase 23 meminta `Notifier`/`AsyncNotifier` Riverpod 3. Tidak perlu dimigrasi sekarang,
  tapi **tulis sebagai penyimpangan** di laporan (alasan + rencana migrasi), jangan
  menyebutnya "sesuai".
- Pastikan folder `jobs/<id>` tidak menumpuk: tetapkan perilaku (hapus video sumber setelah
  ekspor, atau tombol "Bersihkan") dan catat.

## Definition of Done
- [ ] Semua tangkapan layar butir 1.1–1.5 terlampir; pratinjau memutar; ekspor menghasilkan file
- [ ] Bukti batal via UI (daftar proses kosong, 0 `.part`)
- [ ] Chat dan Trading Lab dijalankan nyata, bukan hanya dinyatakan
- [ ] Test notifier + widget status/error hijau
- [ ] Dependency duplikat dihapus atau alasan dicatat; penyimpangan StateNotifier ditulis
- [ ] `flutter analyze` = 0, `flutter test` hijau, push; laporan `CLIPPER_FASE_23B.md` jujur
