import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../models/clip_candidate.dart';
import '../models/video_job.dart';
import '../storage/clip_database.dart';
import '../storage/clipper_settings.dart';
import '../desktop/tool_check.dart';
import '../desktop/yt_dlp_downloader.dart';
import '../desktop/whisper_cpp_transcriber.dart';
import '../desktop/ffmpeg_exporter.dart';
import '../analysis/moment_analyzer.dart';
import '../pipeline/interfaces.dart';
import '../pipeline/clipper_pipeline.dart';
import 'package:aura_core/aura_core.dart';
import 'clipper_host_config.dart';

/// State lengkap UI AURA Clipper.
class ClipperState {
  final ClipperHostConfig config;
  final ClipperSettings settings;
  final bool isInitialized;
  final String url;
  final int? fromSec;
  final int? toSec;
  final String? focus;
  final int maxClips;
  final bool forceWhisper;

  // Pipeline runtime state
  final bool isRunning;
  final VideoJobStatus? activeStage;
  final double progressFraction;
  final String progressMessage;
  final VideoJob? currentJob;
  final List<ClipCandidate> candidates;
  final ClipCandidate? selectedCandidate;
  final Set<String> checkedCandidateTitles;
  final List<VideoJob> historyJobs;
  final String? errorMessage;
  final String? rawLogPath;

  // Export runtime state
  final bool isExporting;
  final double exportProgress;
  final String? exportMessage;
  final List<String> exportedPaths;
  final String? lastExportFolder;

  // Tool check state
  final Map<String, ToolCheckResult>? toolCheckResults;
  final bool isCheckingTools;

  const ClipperState({
    required this.config,
    this.settings = const ClipperSettings(),
    this.isInitialized = false,
    this.url = '',
    this.fromSec,
    this.toSec,
    this.focus,
    this.maxClips = 5,
    this.forceWhisper = false,
    this.isRunning = false,
    this.activeStage,
    this.progressFraction = 0.0,
    this.progressMessage = 'Siap memproses video.',
    this.currentJob,
    this.candidates = const [],
    this.selectedCandidate,
    this.checkedCandidateTitles = const {},
    this.historyJobs = const [],
    this.errorMessage,
    this.rawLogPath,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.exportMessage,
    this.exportedPaths = const [],
    this.lastExportFolder,
    this.toolCheckResults,
    this.isCheckingTools = false,
  });

  ClipperState copyWith({
    ClipperHostConfig? config,
    ClipperSettings? settings,
    bool? isInitialized,
    String? url,
    int? fromSec,
    int? toSec,
    String? focus,
    int? maxClips,
    bool? forceWhisper,
    bool? isRunning,
    VideoJobStatus? activeStage,
    double? progressFraction,
    String? progressMessage,
    VideoJob? currentJob,
    List<ClipCandidate>? candidates,
    ClipCandidate? selectedCandidate,
    Set<String>? checkedCandidateTitles,
    List<VideoJob>? historyJobs,
    String? errorMessage,
    String? rawLogPath,
    bool? isExporting,
    double? exportProgress,
    String? exportMessage,
    List<String>? exportedPaths,
    String? lastExportFolder,
    Map<String, ToolCheckResult>? toolCheckResults,
    bool? isCheckingTools,
    bool clearError = false,
    bool clearSelectedCandidate = false,
  }) {
    return ClipperState(
      config: config ?? this.config,
      settings: settings ?? this.settings,
      isInitialized: isInitialized ?? this.isInitialized,
      url: url ?? this.url,
      fromSec: fromSec ?? this.fromSec,
      toSec: toSec ?? this.toSec,
      focus: focus ?? this.focus,
      maxClips: maxClips ?? this.maxClips,
      forceWhisper: forceWhisper ?? this.forceWhisper,
      isRunning: isRunning ?? this.isRunning,
      activeStage: activeStage ?? this.activeStage,
      progressFraction: progressFraction ?? this.progressFraction,
      progressMessage: progressMessage ?? this.progressMessage,
      currentJob: currentJob ?? this.currentJob,
      candidates: candidates ?? this.candidates,
      selectedCandidate: clearSelectedCandidate ? null : (selectedCandidate ?? this.selectedCandidate),
      checkedCandidateTitles: checkedCandidateTitles ?? this.checkedCandidateTitles,
      historyJobs: historyJobs ?? this.historyJobs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      rawLogPath: rawLogPath ?? this.rawLogPath,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      exportMessage: exportMessage ?? this.exportMessage,
      exportedPaths: exportedPaths ?? this.exportedPaths,
      lastExportFolder: lastExportFolder ?? this.lastExportFolder,
      toolCheckResults: toolCheckResults ?? this.toolCheckResults,
      isCheckingTools: isCheckingTools ?? this.isCheckingTools,
    );
  }
}

/// Riverpod StateNotifier untuk `ClipperState`.
class ClipperNotifier extends StateNotifier<ClipperState> {
  final ClipperHostConfig hostConfig;
  ClipDatabase? _database;
  ClipperSettingsStore? _settingsStore;
  CancelToken? _currentCancelToken;

  ClipperNotifier(this.hostConfig) : super(ClipperState(config: hostConfig)) {
    init();
  }

  /// Inisialisasi basis data, pengaturan lokal, riwayat, dan tool check.
  Future<void> init() async {
    try {
      final workDir = hostConfig.workDir;
      if (!workDir.existsSync()) {
        workDir.createSync(recursive: true);
      }

      _settingsStore = ClipperSettingsStore.fromDirectory(workDir);
      final loadedSettings = await _settingsStore!.load();

      _database = await ClipDatabase.init(workDir.path);
      final recent = _database!.getJobs();

      state = state.copyWith(
        settings: loadedSettings,
        historyJobs: recent,
        isInitialized: true,
      );

      // Cek tool di latar belakang
      unawaited(runToolCheck());
    } catch (e) {
      state = state.copyWith(
        isInitialized: true,
        errorMessage: 'Gagal menginisialisasi penyimpanan Clipper: $e',
      );
    }
  }

  void setUrl(String url) {
    state = state.copyWith(url: url, clearError: true);
  }

  void setRange({int? fromSec, int? toSec}) {
    state = state.copyWith(fromSec: fromSec, toSec: toSec);
  }

  void setFocus(String? focus) {
    state = state.copyWith(focus: focus);
  }

  void setMaxClips(int maxClips) {
    state = state.copyWith(maxClips: maxClips);
  }

  void setForceWhisper(bool force) {
    state = state.copyWith(forceWhisper: force);
  }

  void selectCandidate(ClipCandidate candidate) {
    state = state.copyWith(selectedCandidate: candidate);
  }

  void toggleCandidateChecked(ClipCandidate candidate) {
    final next = Set<String>.from(state.checkedCandidateTitles);
    if (next.contains(candidate.title)) {
      next.remove(candidate.title);
    } else {
      next.add(candidate.title);
    }
    state = state.copyWith(checkedCandidateTitles: next);
  }

  void toggleAllCandidates(bool selectAll) {
    if (selectAll) {
      state = state.copyWith(
        checkedCandidateTitles: state.candidates.map((c) => c.title).toSet(),
      );
    } else {
      state = state.copyWith(checkedCandidateTitles: const {});
    }
  }

  /// Menjalankan pipeline video nyata dari tautan YouTube sampai kandidat klip.
  Future<void> startPipeline({ClipperPipeline? customPipeline}) async {
    final trimmedUrl = state.url.trim();
    if (trimmedUrl.isEmpty) {
      state = state.copyWith(errorMessage: 'Silakan masukkan tautan video YouTube.');
      return;
    }

    if (!state.config.hasAnyApiKey) {
      state = state.copyWith(
        errorMessage:
            'Tidak ada API key LLM yang terkonfigurasi. Silakan buka Pengaturan Desktop untuk menambahkan API key Gemini, OpenAI, Claude, atau Groq.',
      );
      return;
    }

    if (!YtDlpDownloader.isValidUrl(trimmedUrl, state.settings.allowedHosts)) {
      state = state.copyWith(
        errorMessage: 'Tautan video tidak didukung. Pastikan berasal dari domain YouTube yang diizinkan.',
      );
      return;
    }

    // Persiapan direktori job baru
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final jobDir = Directory(p.join(hostConfig.workDir.path, 'jobs', jobId));
    if (!jobDir.existsSync()) {
      jobDir.createSync(recursive: true);
    }

    final job = VideoJob(
      id: jobId,
      url: trimmedUrl,
      createdAt: DateTime.now(),
    );

    _currentCancelToken = CancelToken();

    state = state.copyWith(
      isRunning: true,
      currentJob: job,
      activeStage: VideoJobStatus.downloading,
      progressFraction: 0.0,
      progressMessage: 'Memulai pengunduhan video...',
      candidates: const [],
      checkedCandidateTitles: const {},
      clearError: true,
      clearSelectedCandidate: true,
    );

    try {
      final pipeline = customPipeline ?? _buildPipeline();

      final options = AnalysisOptions(
        tokenBudget: state.settings.tokenBudget,
        maxClips: state.maxClips,
        forceWhisper: state.forceWhisper,
        focus: state.focus?.trim().isNotEmpty == true ? state.focus!.trim() : null,
        from: state.fromSec != null ? Duration(seconds: state.fromSec!) : null,
        to: state.toSec != null ? Duration(seconds: state.toSec!) : null,
      );

      await for (final progress in pipeline.run(
        job,
        jobDir: jobDir,
        options: options,
        cancel: _currentCancelToken,
      )) {
        state = state.copyWith(
          activeStage: progress.stage,
          progressFraction: progress.fraction,
          progressMessage: progress.message,
        );
      }

      final candidates = pipeline.candidates;
      final history = _database?.getJobs() ?? state.historyJobs;

      state = state.copyWith(
        isRunning: false,
        activeStage: VideoJobStatus.done,
        progressFraction: 1.0,
        progressMessage: 'Analisis selesai. Ditemukan ${candidates.length} kandidat klip.',
        candidates: candidates,
        selectedCandidate: candidates.isNotEmpty ? candidates.first : null,
        checkedCandidateTitles: candidates.map((c) => c.title).toSet(),
        historyJobs: history,
      );
    } catch (e) {
      if (_currentCancelToken?.isCancelled == true) {
        state = state.copyWith(
          isRunning: false,
          activeStage: VideoJobStatus.cancelled,
          progressFraction: 0.0,
          progressMessage: 'Proses dibatalkan oleh pengguna.',
        );
      } else {
        String errText = e.toString();
        String? rawLog;
        if (jobDir.existsSync()) {
          final logFile = File(p.join(jobDir.path, 'analysis_raw.log'));
          if (logFile.existsSync()) {
            rawLog = logFile.path;
          }
        }

        if (e is LlmAnalysisException) {
          errText = 'Analisis AI Gagal: ${e.message}';
        } else if (e is ProcessException) {
          errText = 'Tool gagal dijalankan: ${e.message} (executable: ${e.executable}). Cek Pengaturan Tool.';
        }

        state = state.copyWith(
          isRunning: false,
          activeStage: VideoJobStatus.error,
          errorMessage: errText,
          rawLogPath: rawLog,
          progressMessage: 'Terjadi kesalahan saat memproses video.',
        );
      }
    } finally {
      _currentCancelToken = null;
    }
  }

  /// Membatalkan proses aktif seketika.
  void cancelPipeline() {
    if (_currentCancelToken != null && !_currentCancelToken!.isCancelled) {
      _currentCancelToken!.cancel();
      state = state.copyWith(
        progressMessage: 'Membatalkan proses...',
      );
    }
  }

  /// Memuat riwayat job yang telah selesai sebelumnya dari database.
  Future<void> loadJob(VideoJob job) async {
    if (_database == null) return;
    final candidates = _database!.getCandidates(job.id);
    state = state.copyWith(
      currentJob: job,
      activeStage: job.status,
      candidates: candidates,
      selectedCandidate: candidates.isNotEmpty ? candidates.first : null,
      checkedCandidateTitles: candidates.map((c) => c.title).toSet(),
      progressMessage: 'Memuat data job #${job.id}',
    );
  }

  /// Mengekspor klip terpilih ke format MP4 menggunakan FFmpeg.
  Future<void> exportSelected({String? targetFolder}) async {
    final selectedTitles = state.checkedCandidateTitles;
    if (selectedTitles.isEmpty) {
      state = state.copyWith(errorMessage: 'Pilih minimal satu klip untuk diekspor.');
      return;
    }

    final toExport = state.candidates.where((c) => selectedTitles.contains(c.title)).toList();
    if (toExport.isEmpty) return;

    final currentJob = state.currentJob;
    final videoPath = currentJob?.localVideoPath;
    if (currentJob == null || videoPath == null || !File(videoPath).existsSync()) {
      state = state.copyWith(
        errorMessage: 'File video sumber tidak ditemukan. Tidak dapat mengekspor klip.',
      );
      return;
    }

    String? outPath = targetFolder ?? state.settings.outputDir;
    if (outPath == null || outPath.trim().isEmpty) {
      if (hostConfig.onPickOutputFolder != null) {
        outPath = await hostConfig.onPickOutputFolder!();
      }
    }

    if (outPath == null || outPath.trim().isEmpty) {
      outPath = p.join(hostConfig.workDir.path, 'exports');
    }

    final outDir = Directory(outPath);
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    state = state.copyWith(
      isExporting: true,
      exportProgress: 0.0,
      exportMessage: 'Memulai ekspor ${toExport.length} klip...',
      lastExportFolder: outDir.path,
      clearError: true,
    );

    final exporter = FfmpegExporter(ffmpegPath: state.settings.ffmpegPath);
    final results = <String>[];

    try {
      for (var i = 0; i < toExport.length; i++) {
        final clip = toExport[i];
        state = state.copyWith(
          exportProgress: i / toExport.length,
          exportMessage: 'Mengekspor [${i + 1}/${toExport.length}]: "${clip.title}"...',
        );

        final exported = await exporter.export(
          videoPath,
          clip,
          outDir: outDir,
        );
        results.add(exported);
      }

      state = state.copyWith(
        isExporting: false,
        exportProgress: 1.0,
        exportedPaths: results,
        exportMessage: 'Selesai! ${results.length} klip berhasil diekspor ke folder.',
      );
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Gagal mengekspor klip: $e',
        exportMessage: 'Ekspor terhenti karena kesalahan.',
      );
    }
  }

  /// Memperbarui pengaturan Clipper dan menyimpannya ke `clipper_settings.json`.
  Future<void> updateSettings(ClipperSettings newSettings) async {
    if (_settingsStore != null) {
      await _settingsStore!.save(newSettings);
    }
    state = state.copyWith(settings: newSettings);
    await runToolCheck();
  }

  /// Menjalankan verifikasi kesiapan tool eksternal (yt-dlp, ffmpeg, whisper).
  Future<void> runToolCheck() async {
    state = state.copyWith(isCheckingTools: true);
    try {
      final checker = ToolCheck();
      final list = await checker.checkAll(
        ytDlpPath: state.settings.ytDlpPath,
        ffmpegPath: state.settings.ffmpegPath,
        whisperPath: state.settings.whisperPath,
      );
      final map = {for (final r in list) r.name: r};
      state = state.copyWith(
        toolCheckResults: map,
        isCheckingTools: false,
      );
    } catch (_) {
      state = state.copyWith(isCheckingTools: false);
    }
  }

  ClipperPipeline _buildPipeline() {
    final settings = state.settings;
    final downloader = YtDlpDownloader(ytDlpPath: settings.ytDlpPath);
    final transcriber = WhisperCppTranscriber(
      whisperPath: settings.whisperPath,
      ffmpegPath: settings.ffmpegPath,
      whisperModelName: settings.whisperModelName,
      whisperModelsDir: settings.whisperModelsDir,
    );
    final router = LlmRouterClient();
    final analyzer = MomentAnalyzer(
      routerClient: router,
      modelOrCombo: hostConfig.modelOrCombo,
      apiKeys: hostConfig.apiKeys,
    );
    final exporter = FfmpegExporter(ffmpegPath: settings.ffmpegPath);

    return ClipperPipeline(
      downloader: downloader,
      transcriber: transcriber,
      analyzer: analyzer,
      exporter: exporter,
      database: _database,
    );
  }
}

/// Provider Riverpod untuk `ClipperNotifier` berbasis `ClipperHostConfig`.
final clipperControllerProvider =
    StateNotifierProvider.autoDispose.family<ClipperNotifier, ClipperState, ClipperHostConfig>(
  (ref, config) => ClipperNotifier(config),
);
