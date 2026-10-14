/// Model resolver & alias mapping logic — port dari
/// `internal/handlers/chat/resolution.go` dan `internal/providers/aliases.go` (9router-go).
///
/// Digunakan untuk parsing string model format "provider/model", resolusi alias,
/// pembersihan context marker [1m], dan flattening combo hierarkis.
library model_resolver;

import 'models/llm_router_models.dart';

/// Daftar alias canonical provider yang dikurasi khusus untuk A.U.R.A.
/// Sesuai Addendum Section 1, seluruh alias provider yang di-exclude/tidak relevan dibuang.
const providerAliasMap = <String, String>{
  'oa': 'openai',
  'ant': 'anthropic',
  'cc': 'claude', // kalau dipakai terpisah dari 'anthropic'
  'gc': 'gemini', // mapping A.U.R.A: 'gc' -> 'gemini'
  'gq': 'groq',
  'ds': 'deepseek',
  'or': 'openrouter',
  'mm': 'mistral',
};

/// Provider default yang diakui secara bawaan.
const defaultKnownProviders = <String>{
  'openai',
  'anthropic',
  'claude',
  'gemini',
  'groq',
  'deepseek',
  'openrouter',
  'mistral',
};

/// Callback untuk mencari definisi combo models berdasarkan nama combo.
typedef ComboLookup = List<String>? Function(String comboName);

/// Callback untuk mencari model alias (mis. "gpt-4o" -> "openai/gpt-4o").
typedef AliasLookup = String? Function(String alias);

/// Callback untuk mengecek apakah suatu provider aktif / memiliki koneksi valid.
typedef ActiveProviderChecker = bool Function(String provider);

/// ModelResolver mengelola resolusi string model ke [ModelInfo] konkret.
class ModelResolver {
  final Map<String, String> aliasMap;
  final Set<String> knownProviders;
  final ComboLookup? comboLookup;
  final AliasLookup? aliasLookup;
  final ActiveProviderChecker? isProviderActive;

  const ModelResolver({
    this.aliasMap = providerAliasMap,
    this.knownProviders = defaultKnownProviders,
    this.comboLookup,
    this.aliasLookup,
    this.isProviderActive,
  });

  /// Menghapus trailing marker `[1m]` yang disematkan klien Claude Code untuk 1M context beta.
  /// Port dari `stripModelContextMarker` di `resolution.go`.
  static String stripModelContextMarker(String modelStr) {
    final trimmed = modelStr.trim();
    if (trimmed.length < 4) return modelStr;

    final suffix = trimmed.substring(trimmed.length - 4);
    if (suffix.toLowerCase() == '[1m]') {
      return trimmed.substring(0, trimmed.length - 4).trim();
    }
    return modelStr;
  }

  /// Mengonversi short alias provider menjadi ID canonical provider.
  /// Port dari `resolveProviderAlias` di `resolution.go` & `aliases.go`.
  String resolveProviderAlias(String alias) {
    return aliasMap[alias.toLowerCase()] ?? alias;
  }

  /// Mengekspansi model-model combo hierarkis menjadi leaf konkret "provider/model",
  /// menjaga urutan, men-deduplikasi entri berurutan yang identik, dan mencegah loop siklis.
  /// Port dari `flattenComboModels` di `resolution.go`.
  List<String> flattenComboModels(List<String> models) {
    final out = <String>[];
    final seen = <String>{};

    void walk(List<String> ms) {
      for (var m in ms) {
        if (!m.contains('/')) {
          if (seen.contains(m)) {
            // Deteksi siklus combo, lewati entri ini
            continue;
          }

          if (comboLookup != null) {
            final sub = comboLookup!(m);
            if (sub != null && sub.isNotEmpty) {
              seen.add(m);
              walk(sub);
              seen.remove(m);
              continue;
            }
          }

          if (aliasLookup != null) {
            final target = aliasLookup!(m);
            if (target != null && target.contains('/')) {
              m = target;
            }
          }
        }

        if (m.contains('/')) {
          final parts = m.split('/');
          final provider = resolveProviderAlias(parts[0]);
          m = '$provider/${parts.sublist(1).join('/')}';
        }

        // Simpan hanya jika berbeda dari entri terakhir (deduping berurutan)
        if (out.isEmpty || out.last != m) {
          out.add(m);
        }
      }
    }

    walk(models);

    if (out.isEmpty) {
      throw const FormatException('Combo has no valid leaf models');
    }

    return out;
  }

  /// Mem-parse dan me-resolve string model format "provider/model" tanpa combo lookup.
  /// Port dari `resolveModelEntry` di `resolution.go`.
  ModelInfo? resolveModelEntry(String entry) {
    if (!entry.contains('/')) {
      if (comboLookup != null) {
        final sub = comboLookup!(entry);
        if (sub != null && sub.isNotEmpty) {
          final first = resolveModelEntry(sub[0]);
          if (first != null) {
            return ModelInfo(
              provider: first.provider,
              model: first.model,
              comboModels: sub,
            );
          }
        }
      }
      final lower = entry.toLowerCase();
      if (lower.startsWith('gemini')) {
        return ModelInfo(provider: 'gemini', model: entry);
      }
      if (lower.startsWith('gpt') || lower.startsWith('o1') || lower.startsWith('o3')) {
        return ModelInfo(provider: 'openai', model: entry);
      }
      if (lower.startsWith('claude')) {
        return ModelInfo(provider: 'anthropic', model: entry);
      }
      if (lower.startsWith('deepseek')) {
        return ModelInfo(provider: 'deepseek', model: entry);
      }
      return null;
    }

    final parts = entry.split('/');
    final providerPart = parts[0];
    final modelPart = parts.sublist(1).join('/');

    final provider = resolveProviderAlias(providerPart);
    return ModelInfo(provider: provider, model: modelPart);
  }

  /// Me-resolve string model secara lengkap melalui alias, combo, dan format provider/model.
  /// Port dari `resolveModel` di `resolution.go`.
  ModelInfo resolveModel(String modelStr) {
    var str = modelStr.trim();
    if (str.isEmpty) {
      throw ArgumentError('Missing model identifier');
    }

    // 1. Strip [1m] marker
    str = stripModelContextMarker(str);

    // 2. Cek apakah ini nama combo atau comma-separated models
    if (comboLookup != null) {
      final sub = comboLookup!(str);
      if (sub != null && sub.isNotEmpty) {
        final flattened = flattenComboModels(sub);
        if (flattened.isNotEmpty) {
          final first = resolveModelEntry(flattened[0]);
          if (first != null) {
            return ModelInfo(
              provider: first.provider,
              model: first.model,
              comboModels: flattened,
            );
          }
        }
      }
    }

    // 3. Format standar: "provider/model"
    if (str.contains('/')) {
      final parts = str.split('/');
      final provider = resolveProviderAlias(parts[0]);
      final model = parts.sublist(1).join('/');
      return ModelInfo(provider: provider, model: model);
    }

    // 4. Cek apakah ini model alias (misal: "gpt-4o" -> "openai/gpt-4o")
    if (aliasLookup != null) {
      final target = aliasLookup!(str);
      if (target != null && target.contains('/')) {
        final parts = target.split('/');
        final provider = resolveProviderAlias(parts[0]);
        final model = parts.sublist(1).join('/');
        return ModelInfo(provider: provider, model: model);
      }
    }

    // 5. Cek bare provider alias (misal: "oa" -> provider "openai" dengan model "")
    final canonical = resolveProviderAlias(str);
    if (knownProviders.contains(canonical)) {
      if (isProviderActive == null || isProviderActive!(canonical)) {
        return ModelInfo(provider: canonical, model: '');
      }
    }

    // 5.1 Infer provider from common model name prefix if not specified
    final lower = str.toLowerCase();
    if (lower.startsWith('gemini')) {
      return ModelInfo(provider: 'gemini', model: str);
    }
    if (lower.startsWith('gpt') || lower.startsWith('o1') || lower.startsWith('o3')) {
      return ModelInfo(provider: 'openai', model: str);
    }
    if (lower.startsWith('claude')) {
      return ModelInfo(provider: 'anthropic', model: str);
    }
    if (lower.startsWith('deepseek')) {
      return ModelInfo(provider: 'deepseek', model: str);
    }

    // 6. Fallback ke provider aktif dari daftar 8 provider terkurasi A.U.R.A
    for (final p in const [
      'openai',
      'anthropic',
      'claude',
      'gemini',
      'groq',
      'deepseek',
      'openrouter',
      'mistral',
    ]) {
      if (isProviderActive != null && isProviderActive!(p)) {
        return ModelInfo(provider: p, model: str);
      }
    }

    throw FormatException('Could not resolve model: $modelStr');
  }
}
