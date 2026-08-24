# Rule: Backup/Restore & Agentic Loop Safety Cap

Baca ini sebelum mengerjakan Fase 8. Ini merespons langsung insiden nyata: model GGUF
(dan berpotensi seluruh database app — chat, persona, skills, memory) hilang saat reinstall
APK di masa development. Lihat catatan "reinstall APK menghapus model GGUF" di
`.agents/rules/01-overview-stack.md` untuk konteks kenapa ini prioritas tinggi.

## Bagian A: Backup & Restore

### Apa yang di-backup
SATU file backup (format ZIP atau JSON gabungan) berisi:
- Seluruh isi tabel SQLite: `Sessions`, `Messages`, `Persona`, `Skills`, `MemorySnapshot`,
  `UserProfile` (skema dari `.agents/rules/05-persona-skills.md`)
- TIDAK termasuk file model GGUF itu sendiri (terlalu besar, dan sudah bisa didownload
  ulang dari sumber di `.agents/rules/02-architecture.md`) — backup hanya untuk data yang
  TIDAK BISA didownload ulang: riwayat percakapan, persona custom, skill custom.

### Format & lokasi
- Export ke file `.aurabackup` (ZIP berisi JSON per tabel) — beri ekstensi custom supaya
  gampang dikenali, tapi isinya cukup JSON/SQLite dump biasa, tidak perlu enkripsi khusus
  di v1 (data tetap di device user sendiri).
- User pilih lokasi simpan lewat Storage Access Framework (`file_picker`, sudah dipakai di
  Fase 3) — bisa ke folder Download, atau langsung ke Google Drive kalau user pilih app itu
  di picker.
- JANGAN auto-upload ke cloud manapun tanpa aksi eksplisit user — tetap pegang prinsip
  privacy-first di `.agents/rules/01-overview-stack.md`.

### Kapan backup terjadi
- **Manual:** tombol "Export Backup" di Settings — kapan saja user mau.
- **Reminder pasif (bukan otomatis):** kalau sudah >7 hari sejak backup terakhir DAN ada
  data baru sejak itu, tampilkan banner halus di Settings (bukan popup mengganggu)
  mengingatkan untuk backup. JANGAN auto-backup di background — itu tidak dibutuhkan untuk
  app single-device seperti ini, cukup reminder pasif.

### Restore
- Tombol "Restore dari Backup" di Settings (atau di first-run screen kalau app terdeteksi
  kosong tapi user punya file `.aurabackup` lama).
- Validasi isi file sebelum restore (skema version check) — kalau ternyata dari versi app
  yang lebih lama dengan skema tabel berbeda, tampilkan pesan jelas, jangan crash diam-diam.
- Restore MENGGANTIKAN data yang ada, bukan merge — beri konfirmasi eksplisit ke user
  sebelum menimpa data saat ini ("Ini akan mengganti seluruh data saat ini dengan isi
  backup. Lanjutkan?").

## Bagian B: Batas Iterasi Agentic Loop (Safety Cap)

### Kenapa ini penting
Setiap iterasi tool-call = satu kali inferensi penuh model di CPU HP. Berbeda dari Hermes
Agent asli (model kuat via API cloud, default cap 500 iterasi) — di A.U.R.A dengan model
1-3B on-device, loop yang tidak terkendali bisa menguras baterai signifikan dalam hitungan
menit dan memicu thermal throttling (lihat risiko di `.agents/rules/02-architecture.md`).

### Aturan
- Default `MAX_AGENT_ITERATIONS = 8` per giliran percakapan (satu prompt user →
  serangkaian tool-call → jawaban final). Nilai ini dikonfigurasi, bisa diubah lewat
  Settings (advanced), tapi default harus konservatif.
- Setiap kali Agent Orchestration Layer (`.agents/rules/03-tool-calling.md`) melakukan
  satu putaran reasoning→tool-call→observasi, increment counter.
- Kalau counter mencapai `MAX_AGENT_ITERATIONS` TANPA jawaban final tercapai: hentikan
  loop paksa, tampilkan ke user apa yang sudah didapat sejauh ini (bukan error kosong),
  dengan pesan jelas mis. "Saya belum bisa menyelesaikan ini dalam batas langkah yang
  wajar — ini yang sudah saya temukan sejauh ini: ...".
- JANGAN diam-diam mengulang loop lagi otomatis setelah cap tercapai — itu balik lagi ke
  masalah boros baterai. Kalau user mau lanjut, mereka yang harus prompt ulang secara
  eksplisit.
- Tampilkan indikator progres kasar ke user selama loop berjalan (mis. "Langkah 3 dari
  maks 8") supaya user tahu app sedang bekerja, bukan macet.
