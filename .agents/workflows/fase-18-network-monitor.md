# Workflow: Fase 18 — Network Monitor & WiFi/LAN Analyzer

Baca `.agents/rules/16-network-monitor.md` SEBELUM memulai.

**Tujuan:** Integrasikan kemampuan project G-Net Track clone (drive test, log sinyal,
heatmap) ke AURA sebagai tool agentic, plus tambahan WiFi/LAN Analyzer baru.
**Prasyarat:** Fase 5 (Tool-Calling) selesai. Akses ke source code project G-Net Track
clone yang sudah ada.

## Langkah

1. Buat package baru `aura_network` (struktur mirip `aura_trading`).
2. **Port kode seluler dari G-Net Track clone:** pindahkan logic pembacaan cell tower
   info (RSRP/RSRQ, LAC, Cell ID, band) ke `aura_network` — adaptasi API call kalau perlu,
   tapi jangan tulis ulang logic inti dari nol.
3. Implementasikan tool dasar (aman): `ping_host`, `dns_lookup`, `traceroute`.
4. Implementasikan `get_wifi_info` (SSID, RSSI, channel) — kategori sensitif, minta
   permission lokasi saat pertama dipakai dengan penjelasan jelas kenapa dibutuhkan.
5. Implementasikan `get_cellular_signal_info` — port dari kode G-Net Track clone, kategori
   sensitif (lokasi + READ_PHONE_STATE).
6. Implementasikan `speed_test` dengan indikator UI "📡 Menjalankan speed test..." saat
   dipanggil.
7. Implementasikan `scan_lan_devices` — HANYA subnet lokal, pakai ARP table/mDNS
   discovery pasif, JANGAN port-scan agresif. Kategori sensitif.
8. Implementasikan drive test: start/stop logging, ekspor ke CSV dan KML, auto-stop
   setelah durasi maksimal (default 4 jam) untuk cegah boros baterai kalau lupa dimatikan.
9. Bangun UI heatmap sinyal (reuse widget dari G-Net Track clone kalau ada) untuk
   visualisasi drive test log.
10. Update system prompt tool-calling: AI boleh kombinasikan beberapa tool network untuk
    menjelaskan masalah jaringan ke user, HANYA dari hasil tool-call nyata.
11. Perluas `backup_service.dart` untuk mencakup drive test log tersimpan — konsisten
    dengan prinsip yang sudah dibangun untuk data Trading (Fase 15).
12. Uji di kedua device yang sudah dipakai sebelumnya (Xiaomi Mi A1 PixelExperience 12,
    Infinix Hot 12i stock ROM) — custom ROM vs stock ROM kadang beda perilaku API radio.

## Definition of Done
- [ ] Tool dasar (ping/DNS/traceroute) berfungsi
- [ ] Info WiFi dan seluler terbaca benar di kedua device test
- [ ] `scan_lan_devices` terbatas ke subnet lokal saja, tidak port-scan agresif
- [ ] Drive test log berhasil diekspor ke CSV dan KML
- [ ] Drive test auto-stop setelah durasi maksimal
- [ ] AI Coach bisa menjelaskan masalah jaringan dari kombinasi tool-call, bukan asumsi
- [ ] Drive test log tercakup dalam backup/restore
