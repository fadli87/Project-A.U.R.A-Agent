import 'package:flutter_riverpod/legacy.dart';
import 'package:aura_core/aura_core.dart';

class TrustedFoldersState {
  final List<Map<String, dynamic>> folders;
  final bool isLoading;

  const TrustedFoldersState({
    this.folders = const [],
    this.isLoading = false,
  });

  TrustedFoldersState copyWith({
    List<Map<String, dynamic>>? folders,
    bool? isLoading,
  }) {
    return TrustedFoldersState(
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DesktopTrustedFoldersNotifier extends StateNotifier<TrustedFoldersState> {
  DesktopTrustedFoldersNotifier() : super(const TrustedFoldersState()) {
    loadFolders();
  }

  Future<void> loadFolders() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await ChatDatabase.instance.getAllTrustedFolders();
      state = state.copyWith(folders: list, isLoading: false);
    } catch (_) {
      state = state.copyWith(folders: [], isLoading: false);
    }
  }

  Future<void> addFolder(String path) async {
    await ChatDatabase.instance.insertTrustedFolder(path);
    await loadFolders();
  }

  Future<void> removeFolder(int id) async {
    await ChatDatabase.instance.deleteTrustedFolder(id);
    await loadFolders();
  }
}

final desktopTrustedFoldersProvider = StateNotifierProvider<DesktopTrustedFoldersNotifier, TrustedFoldersState>((ref) {
  return DesktopTrustedFoldersNotifier();
});
