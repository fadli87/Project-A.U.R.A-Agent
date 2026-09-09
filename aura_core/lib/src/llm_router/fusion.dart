/// Model fusion logic — port dari `internal/handlers/chat/combo_fusion.go` (9router-go).
///
/// Digunakan untuk orkestrasi panel multi-model (menghimpun jawaban beberapa LLM
/// secara paralel lalu dinilai oleh model Judge secara anonymized).
library fusion;

import 'dart:async';
import 'models/llm_router_models.dart';

/// Mengonversi riwayat giliran tool-call menjadi teks naratif/prose agar model panel
/// memahami konteks tanpa terpicu meng-emit tool_calls baru.
/// Port dari `flattenToolHistory` di `combo_fusion.go`.
List<Map<String, dynamic>> flattenToolHistory(List<dynamic> msgs) {
  final out = <Map<String, dynamic>>[];

  for (final m in msgs) {
    if (m is! Map) {
      continue;
    }
    final msg = Map<String, dynamic>.from(m as Map<String, dynamic>);
    final role = msg['role'] as String? ?? '';
    final content = msg['content'] as String? ?? '';

    if (role == 'tool') {
      final text = '[Tool result]\n$content';
      out.add({'role': 'user', 'content': text});
      continue;
    }

    if (role == 'assistant') {
      final toolCalls = msg['tool_calls'];
      if (toolCalls is List && toolCalls.isNotEmpty) {
        final sb = StringBuffer();
        if (content.isNotEmpty) {
          sb.writeln(content);
        }
        for (final tc in toolCalls) {
          if (tc is Map) {
            final fn = tc['function'];
            if (fn is Map) {
              final name = fn['name'] ?? '';
              final args = fn['arguments'] ?? '';
              sb.write('[Call tool $name($args)]');
            }
          }
        }
        out.add({
          'role': 'assistant',
          'content': sb.toString().trim(),
        });
        continue;
      }
    }

    out.add(msg);
  }

  return out;
}

/// Membangun prompt sistem untuk model Judge yang mengevaluasi jawaban dari panel multi-model.
/// Setiap sumber di-anonimkan (Source 1, Source 2, dst.) agar Judge menilai substansi,
/// bukan reputasi nama model.
/// Port dari `buildJudgePrompt` di `combo_fusion.go`.
String buildJudgePrompt(List<FusionAnswer> answers) {
  final panel = StringBuffer();
  for (var i = 0; i < answers.length; i++) {
    panel.writeln('[Source ${i + 1}]\n${answers[i].text}\n');
  }

  return 'You are the JUDGE in a model-fusion panel. ${answers.length} expert models independently answered the user\'s most recent request. Their responses are below, anonymized by source.\n\n'
      'Do NOT mention that multiple models were used, and do NOT refer to the sources. Produce ONE authoritative final answer addressed directly to the user.\n\n'
      'First, internally analyze the panel along these dimensions: consensus (points most sources agree on — treat as higher-confidence), contradictions (where they disagree — resolve with your own judgment), partial coverage, unique insights only one source surfaced, and blind spots every source missed. Then write the best possible final answer grounded in that analysis — more complete and correct than any single response, with no filler.\n\n'
      '=== PANEL RESPONSES ===\n'
      '$panel'
      '=== END PANEL RESPONSES ===\n\n'
      'Now write the final answer to the user\'s original request.';
}

/// Mengekstrak konten teks dari format response chat completion OpenAI.
/// Port dari `extractPanelText` di `combo_fusion.go`.
String extractPanelText(Map<String, dynamic> body) {
  final choices = body['choices'];
  if (choices is List && choices.isNotEmpty) {
    final first = choices[0];
    if (first is Map && first['message'] is Map) {
      final msg = first['message'] as Map;
      final content = msg['content'];
      if (content is String) {
        return content;
      }
    }
  }
  return '';
}

/// Menambahkan giliran user baru ke payload messages/input.
/// Port dari `appendUserTurn` di `combo_fusion.go`.
Map<String, dynamic> appendUserTurn(Map<String, dynamic> body, String content) {
  final copy = Map<String, dynamic>.from(body);
  final userMsg = {'role': 'user', 'content': content};

  if (copy['messages'] is List) {
    final msgs = List<dynamic>.from(copy['messages'] as List)..add(userMsg);
    copy['messages'] = msgs;
  } else if (copy['input'] is List) {
    final input = List<dynamic>.from(copy['input'] as List)..add(userMsg);
    copy['input'] = input;
  } else {
    copy['messages'] = [userMsg];
  }

  return copy;
}

/// Menghimpun hasil panggilan model panel secara konkuren dengan mekanisme Quorum + Grace period.
/// Ketika jumlah respon sukses mencapai [FusionTuning.minPanel], timer grace akan menyala.
/// Pengumpulan akan berhenti jika semua selesai, grace timer habis, atau batas hard timeout tercapai.
/// Port dari `collectPanel` di `combo_fusion.go`.
Future<List<FusionResult?>> collectPanel(
  List<Future<FusionResult> Function()> calls, {
  FusionTuning tuning = const FusionTuning(),
}) async {
  final n = calls.length;
  if (n == 0) return const [];

  final results = List<FusionResult?>.filled(n, null);
  final completer = Completer<List<FusionResult?>>();

  var settled = 0;
  var okCount = 0;
  Timer? graceTimer;
  Timer? hardTimer;

  void finish() {
    if (!completer.isCompleted) {
      graceTimer?.cancel();
      hardTimer?.cancel();
      completer.complete(List<FusionResult?>.from(results));
    }
  }

  hardTimer = Timer(Duration(milliseconds: tuning.panelHardTimeoutMs), () {
    finish();
  });

  for (var i = 0; i < n; i++) {
    final idx = i;
    calls[idx]().then((res) {
      if (completer.isCompleted) return;

      results[idx] = res;
      settled++;

      if (res.ok) {
        okCount++;
        if (okCount >= tuning.minPanel && graceTimer == null) {
          graceTimer = Timer(Duration(milliseconds: tuning.stragglerGraceMs), () {
            finish();
          });
        }
      }

      if (settled >= n) {
        finish();
      }
    }).catchError((err) {
      if (completer.isCompleted) return;

      results[idx] = FusionResult(model: 'call_$idx', ok: false, error: err);
      settled++;

      if (settled >= n) {
        finish();
      }
    });
  }

  return completer.future;
}
