import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aura_core/aura_core.dart';
import 'package:intl/intl.dart';

import '../../providers/knowledge_provider.dart';
import '../theme/app_theme.dart';

class KnowledgeSourcesScreen extends ConsumerWidget {
  const KnowledgeSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(knowledgeProvider);
    final notifier = ref.read(knowledgeProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Sumber Pengetahuan (RAG)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deskripsi Singkat
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'Latih asisten AURA dengan mengunggah dokumen pribadi Anda (.txt, .md, .pdf). Konten dokumen akan diindeks secara lokal ke dalam memori vektor ObjectBox Anda.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),

              if (state.isImporting && state.importingProgressText != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.importingProgressText!,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: state.sources.isEmpty
                    ? _buildEmptyState(context, notifier)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.sources.length,
                        itemBuilder: (context, index) {
                          final doc = state.sources[index];
                          return _buildDocCard(context, doc, notifier);
                        },
                      ),
              ),
            ],
          ),
          
          if (state.isImporting)
            const ModalBarrier(
              dismissible: false,
              color: Colors.transparent,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: state.isImporting ? null : () => _pickAndImportFile(context, notifier),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Dokumen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, KnowledgeNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada dokumen',
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
              'Unggah dokumen untuk melatih asisten AURA menjawab pertanyaan spesifik dari dokumen tersebut.',
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
            onPressed: () => _pickAndImportFile(context, notifier),
            icon: const Icon(Icons.upload_file),
            label: const Text('Pilih Berkas'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(BuildContext context, DocumentSource doc, KnowledgeNotifier notifier) {
    final isPdf = doc.name.toLowerCase().endsWith('.pdf');
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(doc.importedAt);

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
                color: isPdf 
                    ? Colors.red.withValues(alpha: 0.1) 
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf : Icons.description,
                color: isPdf ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
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
                    '${doc.chunkCount} potongan (chunks) • Di-import $formattedDate',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doc.path,
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
              onPressed: () => _confirmDelete(context, doc, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImportFile(BuildContext context, KnowledgeNotifier notifier) async {
    final pickedFiles = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'pdf'],
    );

    if (pickedFiles.isEmpty) return;
    final path = pickedFiles.first.path;
    if (path == null || path.isEmpty) return;

    await notifier.importDocument(path);
  }

  void _confirmDelete(BuildContext context, DocumentSource doc, KnowledgeNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Dokumen?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${doc.name}"? Menghapus dokumen juga akan menghapus seluruh data indeks/embedding vektor terkait dari memori asisten.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Hapus', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              notifier.deleteDocument(doc.id);
            },
          ),
        ],
      ),
    );
  }
}
