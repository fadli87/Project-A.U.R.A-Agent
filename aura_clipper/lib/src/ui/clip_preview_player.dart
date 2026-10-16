import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;

/// Widget pemutar video pratinjau klip dengan dukungan Direct3D 11 via `fvp`.
/// Berjalan dari `startTime`, otomatis jeda tepat di `endTime`, dan mendukung mode loop.
class ClipPreviewPlayer extends StatefulWidget {
  final String videoPath;
  final Duration startTime;
  final Duration endTime;
  final bool autoPlay;

  const ClipPreviewPlayer({
    super.key,
    required this.videoPath,
    required this.startTime,
    required this.endTime,
    this.autoPlay = false,
  });

  @override
  State<ClipPreviewPlayer> createState() => _ClipPreviewPlayerState();
}

class _ClipPreviewPlayerState extends State<ClipPreviewPlayer> {
  static bool _fvpRegistered = false;

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLooping = true;
  String? _errorMessage;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initFvpAndPlayer();
  }

  @override
  void didUpdateWidget(ClipPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initFvpAndPlayer();
    } else if (oldWidget.startTime != widget.startTime || oldWidget.endTime != widget.endTime) {
      _seekToStart();
    }
  }

  Future<void> _initFvpAndPlayer() async {
    // Registrasi fvp backend Direct3D 11 untuk desktop Windows satu kali
    if (!_fvpRegistered) {
      try {
        fvp.registerWith();
        _fvpRegistered = true;
      } catch (_) {}
    }

    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final file = File(widget.videoPath);
    if (!file.existsSync()) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Berkas video tidak ditemukan di: ${file.path}';
          _isInitialized = false;
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      controller.addListener(_videoPlayerListener);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _errorMessage = null;
        });

        await controller.seekTo(widget.startTime);
        if (widget.autoPlay) {
          await controller.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat pemutar video: $e';
          _isInitialized = false;
        });
      }
    }
  }

  void _videoPlayerListener() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final pos = controller.value.position;
    final isPlaying = controller.value.isPlaying;

    if (_isPlaying != isPlaying || (_currentPosition - pos).inMilliseconds.abs() > 200) {
      setState(() {
        _isPlaying = isPlaying;
        _currentPosition = pos;
      });
    }

    // Penegakan auto-pause / loop tepat di batas endTime
    if (pos >= widget.endTime) {
      if (_isLooping) {
        controller.seekTo(widget.startTime);
        controller.play();
      } else {
        controller.pause();
        controller.seekTo(widget.endTime);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      // Jika saat ini di luar rentang, lompat ke startTime terlebih dahulu
      final pos = controller.value.position;
      if (pos < widget.startTime || pos >= widget.endTime) {
        await controller.seekTo(widget.startTime);
      }
      await controller.play();
    }
  }

  Future<void> _seekToStart() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(widget.startTime);
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoPlayerListener);
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.redAccent, size: 40),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (!_isInitialized || controller == null) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final clipDuration = widget.endTime - widget.startTime;
    final rawElapsed = _currentPosition - widget.startTime;
    final elapsedInClip = rawElapsed < Duration.zero
        ? Duration.zero
        : (rawElapsed > clipDuration ? clipDuration : rawElapsed);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video viewport
          AspectRatio(
            aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                // Play overlay on click
                GestureDetector(
                  onTap: _togglePlayPause,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _isPlaying ? 0.0 : 0.85,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, size: 44, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                // Timestamp badge in top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_formatDuration(widget.startTime)} - ${_formatDuration(widget.endTime)} (${clipDuration.inSeconds}s)',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom timeline & controls bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF1E1E28),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 20),
                  onPressed: _togglePlayPause,
                  tooltip: _isPlaying ? 'Jeda' : 'Putar',
                  color: Colors.white,
                ),
                IconButton(
                  icon: const Icon(Icons.replay, size: 18),
                  onPressed: _seekToStart,
                  tooltip: 'Mulai Ulang dari Awal Klip',
                  color: Colors.white70,
                ),
                IconButton(
                  icon: Icon(
                    Icons.repeat,
                    size: 18,
                    color: _isLooping ? const Color(0xFF7C4DFF) : Colors.white38,
                  ),
                  onPressed: () => setState(() => _isLooping = !_isLooping),
                  tooltip: _isLooping ? 'Loop: Aktif' : 'Loop: Non-aktif',
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(elapsedInClip),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: clipDuration.inMilliseconds > 0
                          ? (elapsedInClip.inMilliseconds / clipDuration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(clipDuration),
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
