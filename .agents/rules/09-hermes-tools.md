# Rule: Tools Tambahan (diadaptasi dari Hermes Agent)

Baca ini sebelum mengerjakan Fase 10. Empat tool baru, diadaptasi dari katalog ~86 tools
Hermes Agent, disaring khusus untuk yang masuk akal di model 1-3B on-device. Fase ini
MELENGKAPI Fase 5 (Tool-Calling) dan Fase 7 (Persona & Skills), bukan menggantikan.

## Tool 1: `clarify(question: String, options: List<String>?)`
Kategori: **AMAN** (tidak mengubah/mengakses data apapun, cuma menampilkan pertanyaan).

Dipakai saat model mendeteksi prompt user ambigu — DAN LEBIH BAIK bertanya balik daripada
menebak. Ini penting khusus untuk model 1-3B yang jauh lebih rentan salah tafsir dibanding
model besar yang biasa dipakai Hermes asli.
- System prompt tool-calling (`.agents/rules/03-tool-calling.md`) HARUS diupdate: beri
  instruksi eksplisit "kalau permintaan user ambigu, panggil clarify daripada menebak dan
  menjalankan tool lain yang berisiko salah sasaran."
- UI: tampilkan sebagai pertanyaan dengan tombol pilihan cepat (kalau `options` diisi) atau
  kotak jawaban bebas (kalau `options` null) — bukan modal blocking yang mengganggu.
- Setelah user jawab, jawaban itu masuk lagi ke context sebagai observasi, agent lanjut
  reasoning dari situ (sama pola dengan tool lain di Fase 5).

## Tool 2: `todo_create/todo_update/todo_list`
Kategori: **AMAN** (data lokal milik user sendiri, low-risk).

Beda dari tool "buat catatan/reminder" di Fase 5 (single note/reminder bertanggal) — ini
checklist terstruktur dengan multiple item dan status selesai/belum.
- Tabel baru: `TodoItems (id, list_id, content, is_done, created_at)` dan
  `TodoLists (id, name, created_at)`.
- Tiga tool terpisah (bukan satu tool serbaguna) supaya skema parameter tiap tool tetap
  simpel — konsisten dengan prinsip validasi skema ketat di Fase 5.

## Tool 3: `skill_manage` — agent bisa usulkan skill baru sendiri
Kategori: **SENSITIF** (mengubah state permanen — WAJIB permission gate, tidak pernah
auto-execute, sesuai aturan di `.agents/rules/03-tool-calling.md`).

Diadaptasi dari kemampuan self-improving Hermes: setelah agent menyelesaikan sesuatu yang
kompleks (mis. rangkaian tool-call yang berhasil untuk task tertentu), agent BOLEH
mengusulkan menyimpan itu sebagai skill baru untuk dipakai lagi nanti.
- Alur: agent panggil `skill_manage(action: "propose", name, description, body)` →
  tampilkan dialog konfirmasi ke user berisi draft skill lengkap → user Approve/Reject →
  kalau Approve, baru benar-benar masuk tabel `Skills` (skema Fase 7) dengan `enabled=1`.
- JANGAN pernah skip dialog konfirmasi ini, walau untuk skill yang "kelihatan aman" — ini
  mengubah perilaku agent jangka panjang, beda dari tool sensitif lain yang efeknya
  langsung terlihat saat itu juga.
- Skill hasil `skill_manage` ditandai `is_agent_created=1` di tabel Skills (butuh tambah
  kolom ini) — supaya user bisa bedakan skill buatan sendiri vs buatan agent saat browse
  di Skill Manager UI.

## Tool 4: `session_search(query: String)` — expose semantic recall sebagai tool
Kategori: **AMAN**.

Infrastruktur sudah ada dari Fase 4 (ObjectBox semantic search) — fase ini cuma
meng-expose-nya sebagai tool yang bisa dipanggil AGENT sendiri (bukan cuma dipakai otomatis
untuk recall pasif di background seperti sekarang).
- Berguna saat user bertanya sesuatu yang eksplisit merujuk masa lalu (mis. "inget nggak
  waktu itu aku cerita soal..."), model bisa aktif memanggil pencarian daripada berharap
  recall otomatis Fase 4 sudah menangkapnya.
- Implementasi: wrapper tipis di atas fungsi retrieval ObjectBox yang sudah ada di
  `embedding_service.dart` — jangan bikin logic pencarian baru dari nol.

## Yang SENGAJA TIDAK diadopsi dari Hermes (dan kenapa)
- Browser automation, `computer_use`, image/video generation, TTS, integrasi platform
  (Spotify/Discord/Feishu) — di luar scope agent personal offline di HP.
- `execute_code` (Programmatic Tool Calling) — butuh model jauh lebih kuat dari 1-3B untuk
  reliable, terlalu berisiko untuk hardware target kita.
- Vision/multimodal — sudah Non-Goal eksplisit di `.agents/rules/01-overview-stack.md`.
