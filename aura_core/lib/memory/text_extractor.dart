import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class TextExtractor {
  /// Extracts text from .txt, .md, or .pdf files.
  static Future<String> extractText(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Berkas tidak ditemukan', filePath);
    }

    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.txt') || lowerPath.endsWith('.md')) {
      return file.readAsString();
    } else if (lowerPath.endsWith('.pdf')) {
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      try {
        final text = PdfTextExtractor(document).extractText();
        return text;
      } finally {
        document.dispose();
      }
    } else {
      throw UnsupportedError('Format berkas tidak didukung: hanya .txt, .md, dan .pdf');
    }
  }
}

class TextChunker {
  /// Splits text into word-based chunks of [chunkSize] words, with [overlap] words.
  static List<String> chunkText(String text, {int chunkSize = 300, int overlap = 50}) {
    if (text.trim().isEmpty) return [];
    
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= chunkSize) {
      return [words.join(' ')];
    }

    final chunks = <String>[];
    int start = 0;
    while (start < words.length) {
      int end = start + chunkSize;
      if (end > words.length) end = words.length;
      final chunkWords = words.sublist(start, end);
      chunks.add(chunkWords.join(' '));
      
      start += (chunkSize - overlap);
      if (chunkSize <= overlap) {
        // Fallback safety to avoid infinite loops
        start += chunkSize;
      }
    }
    return chunks;
  }
}
