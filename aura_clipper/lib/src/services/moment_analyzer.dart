import 'dart:convert';
import 'dart:io';
import 'package:aura_core/aura_core.dart';
import '../models/clip_candidate.dart';

class MomentAnalyzer {
  final LlmRouterClient routerClient;
  final String modelOrCombo;
  final Map<String, String> apiKeys;

  MomentAnalyzer({
    required this.routerClient,
    required this.modelOrCombo,
    required this.apiKeys,
  });

  /// Menganalisis file transkripsi [transcriptPath] dan mengembalikan daftar [ClipCandidate].
  Future<List<ClipCandidate>> analyzeTranscript(String transcriptPath) async {
    final transcriptFile = File(transcriptPath);
    if (!await transcriptFile.exists()) {
      throw Exception('File transkrip tidak ditemukan: $transcriptPath');
    }

    final transcriptText = await transcriptFile.readAsString();
    
    // Parse JSON dari whisper.cpp
    // Tergantung versi whisper.cpp, formatnya biasanya memiliki array "transcription" berisi "timestamps" dan "text"
    // Untuk menyederhanakan prompt, kita gabungkan menjadi teks dengan format [MM:SS] Teks
    final parsed = jsonDecode(transcriptText);
    final buffer = StringBuffer();
    
    if (parsed is Map && parsed.containsKey('transcription')) {
      final segments = parsed['transcription'] as List;
      for (final segment in segments) {
        if (segment is Map) {
          final startMs = (segment['offsets']?['from'] ?? 0) as int;
          // final endMs = (segment['offsets']?['to'] ?? 0) as int;
          final text = segment['text'] ?? '';
          
          final startSec = startMs ~/ 1000;
          final m = startSec ~/ 60;
          final s = startSec % 60;
          
          buffer.writeln('[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}] $text');
        }
      }
    } else {
      // Fallback: kirim raw text
      buffer.write(transcriptText);
    }

    final prompt = '''
Anda adalah AI Video Editor yang ahli dalam menemukan momen "viral" dari sebuah transkrip video.
Tugas Anda adalah membaca transkrip berikut (dengan timestamp) dan memilih 3-5 klip terbaik berdurasi 30-60 detik.

Transkrip:
$buffer

Berikan output murni dalam format JSON array yang berisi objek dengan properti:
- "title": Judul menarik (hook)
- "start_seconds": Waktu mulai dalam integer detik
- "end_seconds": Waktu selesai dalam integer detik
- "score": Nilai viralitas 1-100
- "reason": Alasan singkat kenapa klip ini bagus
''';

    final messages = [
      ChatMessage(
        id: 0,
        sessionId: 0,
        role: MessageRole.user,
        content: prompt,
        timestamp: DateTime.now(),
      )
    ];

    final stream = routerClient.streamGenerate(
      messages: messages,
      modelOrCombo: modelOrCombo,
      apiKeys: apiKeys,
    );

    final responseBuffer = StringBuffer();
    await for (final event in stream) {
      if (event is RouterTextDelta) {
        responseBuffer.write(event.text);
      }
    }

    final responseText = responseBuffer.toString().trim();
    
    // Ekstrak JSON dari response (kadang dibungkus ```json ... ```)
    String jsonString = responseText;
    final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(responseText);
    if (jsonMatch != null) {
      jsonString = jsonMatch.group(1)!;
    }

    try {
      final decoded = jsonDecode(jsonString) as List;
      final candidates = <ClipCandidate>[];
      
      for (final item in decoded) {
        if (item is Map) {
          candidates.add(ClipCandidate(
            title: item['title']?.toString() ?? 'Untitled Clip',
            startTime: Duration(seconds: (item['start_seconds'] as num?)?.toInt() ?? 0),
            endTime: Duration(seconds: (item['end_seconds'] as num?)?.toInt() ?? 0),
            score: (item['score'] as num?)?.toInt() ?? 0,
            reason: item['reason']?.toString() ?? '',
          ));
        }
      }
      return candidates;
    } catch (e) {
      throw Exception('Gagal parse JSON dari LLM: $e\nResponse text: $responseText');
    }
  }
}
