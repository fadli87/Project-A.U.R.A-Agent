import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_lib;

import 'memory_entry.dart';
import '../../../objectbox.g.dart';

/// Singleton that opens and holds the ObjectBox [Store].
/// Call [ObjectBoxStore.open()] once at app startup in main.dart.
class ObjectBoxStore {
  ObjectBoxStore._({required this.store});

  static ObjectBoxStore? _instance;
  final Store store;

  static ObjectBoxStore get instance {
    assert(_instance != null, 'Call ObjectBoxStore.open() before accessing instance');
    return _instance!;
  }

  static bool get isOpen => _instance != null;

  /// Opens the ObjectBox store. Call this once from main().
  static Future<ObjectBoxStore> open() async {
    if (_instance != null) return _instance!;

    final docsDir = await getApplicationDocumentsDirectory();
    final dbDir = path_lib.join(docsDir.path, 'objectbox');

    final store = await openStore(directory: dbDir);
    _instance = ObjectBoxStore._(store: store);
    return _instance!;
  }

  Box<MemoryEntry> get memoryBox => store.box<MemoryEntry>();

  /// Clean up resources
  void close() {
    store.close();
    _instance = null;
  }
}
