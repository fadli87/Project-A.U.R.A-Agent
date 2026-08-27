# Rule: Cloud Provider Fallback (Gemini/OpenAI) — Manual Per-Pesan

Baca ini sebelum mengerjakan Fase 14. Ini pengecualian privasi paling besar sejauh ini di
project ini — lebih besar dari Fase 9 (search online, hanya kirim query) karena di sini
**seluruh isi giliran chat** (persona, tool schema, riwayat relevan) bisa terkirim ke
provider pihak ketiga. Baca `.agents/rules/01-overview-stack.md` bagian Visi untuk konteks
prinsip privasi inti yang tetap harus dijaga di luar fitur opt-in ini.

## Cakupan platform
Berlaku untuk `aura_mobile` DAN `aura_desktop` — logic provider client di `aura_core`
(shared), UI Settings untuk API key dibangun terpisah per platform (secure storage API
beda antara Android Keystore dan Windows Credential Manager).

## KEPUTUSAN FINAL: manual per-pesan, BUKAN otomatis
User sudah eksplisit memilih: **tidak ada auto-fallback berdasarkan deteksi device
lambat.** Alasan: menghindari kejutan biaya (API cloud berbayar per-token) dan menjaga
user selalu sadar kapan data mereka keluar device. JANGAN implementasikan auto-switch
tanpa diskusi ulang eksplisit dengan user.

## Penyimpanan API Key — WAJIB secure storage, TIDAK BOLEH plain text
1. Gunakan `flutter_secure_storage` — Android Keystore di Mobile, Windows Credential
   Manager/DPAPI di Desktop.
2. JANGAN simpan API key di SQLite, ObjectBox, SharedPreferences, atau file konfigurasi
   plain text apapun — ini kredensial sensitif yang bisa berdampak biaya nyata kalau bocor.
3. UI Settings: input field API key dengan mode "password" (disembunyikan), tombol
   show/hide, dan opsi hapus key kapan saja.
4. Validasi key sebelum disimpan: lakukan satu panggilan API ringan/murah (mis. list
   models) untuk konfirmasi key valid sebelum menyimpannya sebagai "aktif" — supaya user
   tidak baru tahu key salah pas sedang butuh cepat.

## Provider yang didukung
- **Google Gemini** (via Gemini API — model disarankan: `gemini-flash-latest` untuk
  keseimbangan kecepatan/biaya, konsisten dengan yang sudah dipakai user di setup Hermes
  Agent ThinkPad-nya).
- **OpenAI** (via Chat Completions API — model dipilih user dari daftar, jangan hardcode
  satu model saja karena OpenAI sering update lineup).
- Desain provider client sebagai interface/abstraction (`CloudInferenceEngine`) yang
  gampang ditambah provider lain nanti — jangan hardcode logic Gemini/OpenAI campur di satu
  fungsi besar.

## UI: toggle per-pesan
1. Di chat screen, tambahkan tombol/switch kecil dekat input field: "☁️ Kirim ke Cloud"
   (default OFF/mati tiap buka app — TIDAK persisten sebagai default nyala, supaya user
   selalu sadar aktif tidaknya tiap sesi baru).
2. Kalau user aktifkan untuk satu pesan, tampilkan indikator jelas di bubble chat itu (mis.
   badge "☁️ via Gemini" atau "☁️ via OpenAI") — sama pola dengan indikator lokal vs Desktop
   di Fase 12.
3. Kalau belum ada API key tersimpan sama sekali dan user coba aktifkan toggle, arahkan
   langsung ke Settings untuk isi key dulu — jangan biarkan toggle aktif tanpa key valid.

## Data yang dikirim vs yang TIDAK dikirim
- **Dikirim (saat toggle aktif):** persona aktif, skills index relevan, riwayat pesan
  dalam context window giliran itu, prompt user saat itu.
- **TIDAK PERNAH dikirim:** seluruh database riwayat chat/memori/dokumen RAG secara utuh
  — hanya konteks yang memang relevan untuk giliran itu (sama disiplin budget context
  yang sudah dipakai untuk model lokal), BUKAN dump semua data pribadi ke provider.
- Riwayat percakapan TETAP disimpan lokal seperti biasa (Fase 4) — cloud provider cuma
  dipakai untuk satu putaran inferensi, tidak untuk penyimpanan.

## Error handling
- Kalau API call gagal (key invalid, rate limit, network), tampilkan error jelas ke user
  DAN tawarkan opsi jatuh kembali ke model lokal untuk pesan itu — jangan otomatis retry
  berkali-kali ke cloud (biaya) atau diam-diam gagal tanpa penjelasan.

## Yang TIDAK termasuk di v1
- Auto-fallback berbasis deteksi device lambat (lihat "Keputusan Final" di atas).
- Estimasi/tracking biaya penggunaan API — dicatat sebagai potensi Fase lanjutan kalau
  penggunaan cloud jadi cukup sering untuk perlu dipantau.
- Streaming response dari cloud provider bisa berbeda formatnya dari local — pastikan
  UI streaming yang sudah ada (Fase 2/3) cukup generic untuk menangani kedua sumber.
