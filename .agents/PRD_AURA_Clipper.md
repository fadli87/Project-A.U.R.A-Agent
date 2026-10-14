# PRD: AURA Clipper — Modul AI Video Clipper untuk A.U.R.A Toolbox

## 1. Ringkasan

AURA Clipper adalah modul baru dalam ekosistem **A.U.R.A** (Flutter monorepo) yang berfungsi sebagai tool untuk *clippers* — mengubah video panjang (link YouTube/podcast) menjadi klip pendek vertikal yang berpotensi viral, menggunakan AI untuk mendeteksi momen menarik secara otomatis.

Modul ini akan hadir sebagai salah satu "tool" yang bisa diakses dari dashboard/launcher AURA, sejajar dengan modul AI Agent, Finance, dan DSA Tracker yang sudah ada.

## 2. Jawaban atas Pertanyaan Kunci: Apakah Bisa dengan Flutter?

**Ya, bisa — dan ini pilihan yang tepat**, dengan catatan pembagian tanggung jawab berikut:

| Bagian | Teknologi | Alasan |
|---|---|---|
| UI (timeline, preview, daftar klip, editor sederhana) | **Flutter Desktop** | Konsisten dengan stack AURA Desktop yang sudah ada, bisa share code lewat `aura_core` |
| Download video (yt-dlp), transcribe (Whisper), potong video (ffmpeg) | **Proses eksternal** (dipanggil via `Process.run` di Dart) | Flutter tidak punya library native untuk video processing berat — pola ini sama seperti proyek Flutter serupa (ClipForge dkk juga pakai pendekatan "orchestrator UI + heavy-lifting via external binary/process") |
| Deteksi momen viral (analisis transcript) | **Reuse `llm_router` yang sudah ada di `aura_core`** | Modul hybrid cloud LLM routing yang sudah kamu port dari 9router-go bisa langsung dipakai di sini — tidak perlu bikin ulang logic pemanggilan LLM |

Jadi Flutter berperan sebagai **orchestrator + UI**, sementara pekerjaan berat (download, transcribe, cut) didelegasikan ke binary eksternal yang dipanggil dari Dart. Ini pola yang sudah kamu pakai juga secara tidak langsung (mis. FFI ke Windows DPAPI di `DesktopSecureStorage`).

## 3. Integrasi ke Monorepo AURA

Mengikuti pola struktur yang sudah ada (`aura_core`, `aura_mobile`, `aura_desktop`, `aura_trading`):

```
aura_clipper/
  lib/src/
    ui/              # Timeline viewer, clip list, preview player
    pipeline/        # Orchestration: download -> transcribe -> analyze -> cut
    services/
      downloader_service.dart   # wrapper yt-dlp via Process
      transcriber_service.dart  # wrapper whisper.cpp / faster-whisper via Process
      moment_analyzer.dart      # pakai aura_core/llm_router untuk skoring viral
      clip_exporter.dart        # wrapper ffmpeg via Process
    storage/
      clip_database.dart        # pakai sqlite3 (konsisten dengan chat_database)
    models/
      video_job.dart
      clip_candidate.dart
```

- **Desktop-only di awal** — karena yt-dlp/whisper/ffmpeg sebagai binary eksternal jauh lebih mudah dijalankan di desktop daripada Android (butuh bundling binary per-platform, storage besar untuk model Whisper, dst). Versi mobile bisa jadi fase lanjutan (opsional, kemungkinan cloud-based).
- **Masuk ke dashboard AURA** sebagai entry baru di launcher/home screen, sejajar dengan modul lain.
- **Reuse `llm_router`** untuk tahap analisis viral moment — bisa pilih provider (lokal via Ollama, atau cloud) persis seperti agent utama AURA.
- **Data klip & histori job** disimpan lokal (SQLite), sinkron ke Supabase project yang sama (schema baru `clipper`) mengikuti keputusan multi-modul yang sudah kamu buat untuk Finance & DSA Tracker.

## 4. Pipeline Teknis

```
[Link YouTube/Podcast]
       │
       ▼
1. Download (yt-dlp)  ──> file video lokal (temp)
       │
       ▼
2. Transcribe (whisper.cpp / faster-whisper)  ──> transcript + timestamp
       │
       ▼
3. Analisis Viral Moment (aura_core/llm_router)
   → prompt: skor virality per segmen + alasan (hook, punchline, emotional peak)
   → output: list {start, end, score, reason}
       │
       ▼
4. Preview & Seleksi (UI)  ──> user pilih klip mana yang mau di-export
       │
       ▼
5. Export (ffmpeg)  ──> potong + (opsional) crop vertikal 9:16 + burn-in subtitle
       │
       ▼
[File klip siap post]
```

## 5. Prasyarat (Blocker Sebelum Fase 1)

> **Catatan penting**: `llm_router` (hasil port dari 9router-go) sudah selesai dan lolos review untuk sisi mobile, **tetapi belum ada wiring/integrasi ke `aura_desktop`**. Ini harus diselesaikan dulu sebelum AURA Clipper bisa reuse modul tersebut untuk deteksi momen viral.

**Fase 0 — Integrasi `llm_router` ke `aura_desktop`**
- Setup provider config di sisi desktop (API key storage pakai `DesktopSecureStorage` yang sudah ada)
- Wiring `llm_router` ke UI/state management desktop (Riverpod)
- Uji hybrid routing (lokal Ollama vs cloud) berjalan normal di environment desktop
- Setelah ini selesai, baru lanjut ke Fase 1 Clipper dan panggil `llm_router` langsung dari `moment_analyzer.dart`

## 6. Fitur (berdasarkan brief awal)

**Fase 1 — Core Pipeline (MVP)**
- Input link YouTube/podcast
- Download otomatis via yt-dlp
- Transkripsi otomatis (Whisper, jalan lokal)
- Deteksi momen viral via LLM (reuse `llm_router`)
- Preview daftar klip kandidat dengan skor & alasan
- Export klip terpilih ke file MP4

**Fase 2 — Polish**
- Auto-crop ke vertikal 9:16 dengan speaker tracking sederhana
- Auto burn-in subtitle dari transcript
- Riwayat job (video apa saja yang pernah diproses)

**Fase 3 — Integrasi Toolbox**
- Sinkron histori & preferensi ke Supabase (schema `clipper`)
- Muncul di dashboard AURA sebagai modul terpisah
- (Opsional) Auto-post terjadwal, kalau nanti mau dikembangkan ke arah publishing

## 7. Risiko & Catatan

- **Legalitas download**: yt-dlp menarik konten dari YouTube — pastikan hanya dipakai untuk video milik sendiri atau yang punya izin repurpose, sesuai ToS platform sumber.
- **Ukuran binary**: whisper model + ffmpeg + yt-dlp perlu dibundling atau di-download saat instalasi pertama — perlu strategi packaging untuk distribusi desktop app (installer size).
- **Biaya LLM**: kalau pakai `llm_router` dengan provider cloud, biaya jalan per video tergantung panjang transcript — opsi Ollama lokal (sudah didukung `llm_router`) jadi fallback gratis.
- **Skala kerja Antigravity**: mengikuti pola project lain, disarankan modul ini juga dapat file `.agents/rules/` & `.agents/workflows/` sendiri sebelum Antigravity mulai coding, supaya konsisten dengan cara kerja proyek AURA lainnya.

## 8. Keputusan Terbuka (perlu ditentukan sebelum mulai coding)

1. Whisper mode: lokal penuh (whisper.cpp, gratis tapi butuh resource) vs API (lebih cepat, berbayar)?
2. Apakah versi pertama fokus desktop saja, atau langsung dirancang agar `aura_core` pipeline-nya reusable ke mobile nanti?
3. Struktur nama package: `aura_clipper` atau nama lain yang lebih sesuai branding "tools" AURA?
