# Rule: Network Monitor & WiFi/LAN Analyzer (integrasi dari G-Net Track clone)

Baca ini sebelum mengerjakan Fase 18. Ini MENGINTEGRASIKAN kemampuan dari project terpisah
"G-Net Track clone" (drive test, log sinyal, heatmap) ke dalam AURA sebagai satu set tool
baru — bukan project terpisah lagi.

## Sumber kode
Reuse kode dari project G-Net Track clone yang sudah ada dan sudah ditest di dua device
(Xiaomi Mi A1 PixelExperience 12, Infinix Hot 12i stock ROM). JANGAN tulis ulang dari nol
logic pembacaan sinyal seluler/cell tower — port/adaptasi kode yang sudah terbukti jalan
itu ke dalam `aura_core` atau package baru `aura_network` (lihat keputusan struktur di
bawah).

## Struktur package
Buat package baru `aura_network` (pola sama dengan `aura_trading`) — shared antara
`aura_mobile` dan `aura_desktop`, BUKAN ditaruh langsung di `aura_core` supaya
`aura_core` tetap ramping (prinsip modular yang sudah dipakai untuk trading).
- Fitur seluler (cell tower, drive test, RSRP/RSRQ) → **Mobile-only**, Android API level
  rendah untuk info radio seluler tidak tersedia di Desktop.
- Fitur WiFi/LAN Analyzer → berlaku KEDUANYA (Mobile dan Desktop), API-nya beda per
  platform tapi konsepnya sama.

## Kategori tool & sensitivitas
| Tool | Kategori | Alasan |
|---|---|---|
| `ping_host`, `dns_lookup`, `traceroute` | Aman | Tidak butuh izin khusus, low-risk |
| `get_wifi_info` (SSID, RSSI, channel, band) | **Sensitif** | Android mewajibkan izin lokasi untuk baca info WiFi sejak Android 8+ — akses lokasi selalu masuk kategori sensitif di project ini |
| `get_cellular_signal_info` (RSRP/RSRQ, cell ID, LAC) | **Sensitif** | Butuh izin lokasi (Android 10+) DAN `READ_PHONE_STATE` — dua izin sensitif sekaligus |
| `speed_test` | **Sensitif** | Mengirim/menerima data ke server test pihak ketiga — pengecualian privasi baru, harus disclose seperti Fase 9 |
| `scan_lan_devices` (LAN Analyzer — daftar device di jaringan lokal) | **Sensitif** | Ini bentuk network scanning; batasi HANYA ke subnet lokal milik device sendiri, JANGAN scan ke luar jaringan lokal |
| `drive_test_log_start/stop` (rekam log sinyal ke CSV/KML) | Aman (setelah user mulai) tapi START-nya perlu konfirmasi karena berjalan background terus-menerus | Konsisten baterai — beri batas waktu maksimal sesi (mis. auto-stop 4 jam) |

## Batasan keras untuk `scan_lan_devices`
- HANYA scan subnet lokal device sendiri (deteksi otomatis dari IP+netmask WiFi aktif) —
  JANGAN izinkan input IP range manual sembarangan, itu bisa disalahgunakan untuk scan
  jaringan orang lain (berpotensi ilegal tergantung yurisdiksi, dan di luar scope tool ini).
- Batasi ke discovery pasif/ringan (ARP table, mDNS/Bonjour discovery) — JANGAN port-scan
  agresif ke tiap device yang ditemukan, itu bisa terdeteksi sebagai aktivitas mencurigakan
  oleh device lain di jaringan (mis. firewall router kantor).

## Speed Test — disclosure seperti fitur online lain
Sama pola dengan Fase 9 (search) dan Fase 14 (cloud fallback): kalau `speed_test`
dijalankan, tampilkan indikator jelas "📡 Menjalankan speed test ke server eksternal" —
transparan bahwa ini mengirim data test ke luar device, bukan murni offline.

## Integrasi dengan AI Coach (diferensiasi dari G-Net Track biasa)
Nilai tambah utama menggabungkan ini ke AURA (bukan sekadar tool mentah menampilkan angka):
AI bisa menjelaskan hasil diagnostic dalam bahasa natural — user tanya "kenapa internet
lambat?", AI panggil kombinasi tool (`get_wifi_info` + `speed_test` + `ping_host`), lalu
jelaskan hasilnya dan beri saran. Sama prinsip grounding dengan Trading Coach
(`.agents/rules/14-trading-assistant.md` Prinsip 2) — AI HANYA boleh menjelaskan dari hasil
tool-call nyata, JANGAN menebak kondisi jaringan dari asumsi umum.

## Drive Test & Ekspor Log
- Format ekspor: CSV (data tabular) dan KML (untuk dibuka di Google Earth/Maps) — sesuai
  spesifikasi asli G-Net Track clone.
- Simpan log ke app-specific storage dulu (bukan langsung ke public storage) — ingat
  Insiden 3 (reinstall menghapus app-specific storage), jadi WAJIB masuk cakupan Backup
  (Fase 8/Prinsip 6 di `.agents/rules/14-trading-assistant.md`) juga — data drive test log
  tidak boleh hilang begitu saja kalau ada reinstall.
