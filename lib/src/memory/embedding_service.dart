import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;

/// On-device embedding service using all-MiniLM-L6-v2 (INT8 quantized, ~22 MB).
/// Produces 384-dimensional vectors for semantic similarity search via ObjectBox HNSW.
///
/// Usage:
///   final svc = EmbeddingService.instance;
///   await svc.init();
///   final vec = await svc.embed('Hello world');  // List<double> of length 384
class EmbeddingService {
  EmbeddingService._();
  static final EmbeddingService instance = EmbeddingService._();

  Interpreter? _interpreter;
  Map<String, int>? _vocab;

  bool get isReady => _interpreter != null && _vocab != null;

  static const _modelAsset = 'assets/models/minilm_l6_v2.tflite';
  static const _tokenizerAsset = 'assets/models/minilm_tokenizer.json';

  // MiniLM-L6 expects max 128 tokens
  static const _maxSeqLen = 128;

  /// Initialize interpreter and tokenizer. Safe to call multiple times.
  Future<void> init() async {
    if (isReady) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);

      final tokenizerJson = await rootBundle.loadString(_tokenizerAsset);
      final tokenizerData = jsonDecode(tokenizerJson) as Map<String, dynamic>;
      final modelData = tokenizerData['model'] as Map<String, dynamic>?;
      if (modelData != null && modelData['vocab'] != null) {
        final rawVocab = modelData['vocab'] as Map<String, dynamic>;
        _vocab = rawVocab.map((k, v) => MapEntry(k, v as int));
      }
    } catch (_) {
      _interpreter = null;
      _vocab = null;
    }
  }

  /// Compute a 384-dimensional embedding for [text].
  /// Returns a zero vector on failure (graceful degradation).
  Future<List<double>> embed(String text) async {
    if (!isReady) await init();
    if (_interpreter == null) return List.filled(384, 0.0);

    try {
      final tokens = _tokenize(text);
      final inputIds = _padOrTruncate(tokens, _maxSeqLen);
      final attentionMask = inputIds.map((t) => t != 0 ? 1 : 0).toList();
      final tokenTypeIds = List<int>.filled(_maxSeqLen, 0);

      // Input tensors shape: [1, maxSeqLen]
      final inputIdsTensor = [inputIds];
      final attentionMaskTensor = [attentionMask];
      final tokenTypeIdsTensor = [tokenTypeIds];

      // Output shape: [1, maxSeqLen, 384]
      final output = List.generate(
        1,
        (_) => List.generate(_maxSeqLen, (_) => List.filled(384, 0.0)),
      );

      _interpreter!.runForMultipleInputs(
        [inputIdsTensor, attentionMaskTensor, tokenTypeIdsTensor],
        {0: output},
      );

      // Mean pooling over non-padding tokens, then L2 normalize
      final embedding = _meanPool(output[0], attentionMask);
      return _l2Normalize(embedding);
    } catch (_) {
      return List.filled(384, 0.0);
    }
  }

  // ─── Tokenizer helpers ──────────────────────────────────────────────────────

  List<int> _tokenize(String text) {
    final tokens = <int>[101]; // [CLS]
    final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
    final words = cleaned.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.isEmpty) continue;
      if (_vocab != null && _vocab!.containsKey(word)) {
        tokens.add(_vocab![word]!);
      } else {
        // WordPiece fallback: try subwords
        bool found = false;
        for (int i = 0; i < word.length; i++) {
          final sub = i == 0 ? word.substring(i) : '##${word.substring(i)}';
          if (_vocab != null && _vocab!.containsKey(sub)) {
            tokens.add(_vocab![sub]!);
            found = true;
            break;
          }
        }
        if (!found) tokens.add(100); // [UNK]
      }
      if (tokens.length >= _maxSeqLen - 1) break;
    }
    tokens.add(102); // [SEP]
    return tokens;
  }

  List<int> _padOrTruncate(List<int> tokens, int maxLen) {
    if (tokens.length >= maxLen) return tokens.sublist(0, maxLen);
    return [...tokens, ...List.filled(maxLen - tokens.length, 0)];
  }

  List<double> _meanPool(List<List<double>> hiddenStates, List<int> mask) {
    final dim = hiddenStates[0].length;
    final result = List.filled(dim, 0.0);
    int count = 0;
    for (int i = 0; i < hiddenStates.length; i++) {
      if (mask[i] == 0) continue;
      count++;
      for (int j = 0; j < dim; j++) {
        result[j] += hiddenStates[i][j];
      }
    }
    if (count > 0) {
      for (int j = 0; j < dim; j++) {
        result[j] /= count;
      }
    }
    return result;
  }

  List<double> _l2Normalize(List<double> vec) {
    double norm = 0.0;
    for (final v in vec) norm += v * v;
    norm = math.sqrt(norm);
    if (norm < 1e-10) return vec;
    return vec.map((v) => v / norm).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _vocab = null;
  }
}
