import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aura_core/aura_core.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../theme/app_theme.dart';

class TrustedFoldersScreen extends StatefulWidget {
  const TrustedFoldersScreen({super.key});

  @override
  State<TrustedFoldersScreen> createState() => _TrustedFoldersScreenState();
}

class _TrustedFoldersScreenState extends State<TrustedFoldersScreen> {
  List<Map<String, dynamic>> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    try {
      final list = await ChatDatabase.instance.getAllTrustedFolders();
      setState(() {
        _folders = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndAddFolder() async {
    try {
      final path = await FilePickerPlatform.instance.getDirectoryPath();
      if (path == null || path.isEmpty) return;

      await ChatDatabase.instance.insertTrustedFolder(path);
      _loadFolders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder terpercaya berhasil ditambahkan.'),
            backgroundColor: AppTheme.statusReady,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan folder: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteFolder(int id, String name) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Folder Terpercaya?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$name" dari daftar folder terpercaya? AURA tidak akan bisa lagi membaca berkas dari folder ini.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Hapus', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(context);
              await ChatDatabase.instance.deleteTrustedFolder(id);
              _loadFolders();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Folder Terpercaya (Read-Only)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header deskripsi
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Daftarkan folder di PC/HP Anda agar asisten AURA dapat membaca berkas di dalamnya saat Anda memintanya secara langsung (mis. "tolong baca file catatan.txt"). AURA tidak dapat menulis atau menghapus file apa pun.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _folders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _folders.length,
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          return _buildFolderCard(folder);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _pickAndAddFolder,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Folder',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_shared_outlined,
            size: 64,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada folder terpercaya',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Akses baca dibatasi secara keras hanya untuk folder yang Anda whitelist secara aktif demi menjaga privasi data Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              foregroundColor: AppTheme.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _pickAndAddFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Pilih Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    final id = folder['id'] as int;
    final path = folder['path'] as String? ?? '';
    final addedAtMs = folder['added_at'] as int? ?? 0;
    final folderName = p.basename(path).isEmpty ? path : p.basename(path);
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(addedAtMs),
    );

    return Card(
      color: AppTheme.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.folder,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ditambahkan $formattedDate',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: () => _deleteFolder(id, folderName),
            ),
          ],
        ),
      ),
    );
  }
}
