/// Stall detection logic — port dari `internal/proxy/stall.go` (9router-go).
///
/// Mengawasi stream SSE / byte response agar tidak macet di tengah jalan tanpa data.
/// Setiap ada data chunk yang masuk, timer di-reset. Jika tidak ada chunk data selama
/// batas timeout (default 6 menit), stream akan diputus dengan [StallTimeoutException].
library stall_detection;

import 'dart:async';

/// Batas timeout idle default untuk streaming SSE (6 menit).
/// Sesuai Addendum Section 3 & `DefaultStallTimeout` di Go (`internal/proxy/stall.go`).
const defaultStallTimeout = Duration(minutes: 6);

/// Exception yang dilempar saat stream mengalami stall (macet / tidak ada data).
class StallTimeoutException implements Exception {
  final Duration timeout;
  final String label;

  const StallTimeoutException({
    required this.timeout,
    this.label = 'stream',
  });

  @override
  String toString() => 'StallTimeoutException: No data received for ${timeout.inSeconds}s (label: "$label")';
}

/// StreamTransformer yang memantau keaktifan aliran data dan memicu error timeout
/// jika aliran stream berhenti mengirim data lebih lama dari batas waktu yang ditentukan.
class StallDetectionTransformer<T> extends StreamTransformerBase<T, T> {
  final Duration timeout;
  final String label;

  const StallDetectionTransformer({
    this.timeout = defaultStallTimeout,
    this.label = 'stream',
  });

  @override
  Stream<T> bind(Stream<T> stream) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? timer;

    void resetTimer() {
      timer?.cancel();
      timer = Timer(timeout, () {
        controller.addError(StallTimeoutException(timeout: timeout, label: label));
        subscription?.cancel();
        controller.close();
      });
    }

    controller = StreamController<T>(
      onListen: () {
        resetTimer();
        subscription = stream.listen(
          (data) {
            resetTimer();
            controller.add(data);
          },
          onError: (Object error, StackTrace stackTrace) {
            timer?.cancel();
            controller.addError(error, stackTrace);
          },
          onDone: () {
            timer?.cancel();
            controller.close();
          },
          cancelOnError: false,
        );
      },
      onPause: () {
        timer?.cancel();
        subscription?.pause();
      },
      onResume: () {
        resetTimer();
        subscription?.resume();
      },
      onCancel: () {
        timer?.cancel();
        return subscription?.cancel();
      },
    );

    return controller.stream;
  }
}

/// Ekstensi praktis untuk menambahkan deteksi stall pada [Stream].
extension StallDetectionExtension<T> on Stream<T> {
  /// Membungkus stream saat ini dengan [StallDetectionTransformer].
  Stream<T> withStallDetection({
    Duration timeout = defaultStallTimeout,
    String label = 'stream',
  }) {
    return transform(StallDetectionTransformer<T>(timeout: timeout, label: label));
  }
}
