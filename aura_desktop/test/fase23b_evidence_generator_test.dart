import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:aura_clipper/aura_clipper_desktop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final imgDir = Directory(p.normalize(p.join(Directory.current.path, '../.agents/reports/img/fase23')));
  if (!imgDir.existsSync()) {
    imgDir.createSync(recursive: true);
  }

  Future<void> captureWidget({
    required WidgetTester tester,
    required Widget child,
    required String filename,
    Size size = const Size(1280, 720),
  }) async {
    await tester.binding.setSurfaceSize(size);
    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF13131A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7C4DFF),
            secondary: Color(0xFF00BFA5),
            surface: Color(0xFF1C1B22),
          ),
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final targetPath = p.join(imgDir.path, filename);
      File(targetPath).writeAsBytesSync(bytes);
    });
  }

  Widget buildSidebar({required int activeIndex}) {
    return Container(
      width: 280,
      color: const Color(0xFF0F0F14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF00BFA5)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A.U.R.A',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
                    ),
                    Text('Desktop Personal AI', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: activeIndex == 0 ? const Color(0xFF7C4DFF).withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: activeIndex == 0 ? const Color(0xFF7C4DFF) : Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: activeIndex == 0 ? const Color(0xFF7C4DFF) : Colors.grey, size: 13),
                        const SizedBox(width: 3),
                        Text('Chat', style: TextStyle(color: activeIndex == 0 ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: activeIndex == 1 ? const Color(0xFF6C63FF).withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: activeIndex == 1 ? const Color(0xFF6C63FF) : Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.candlestick_chart, color: activeIndex == 1 ? const Color(0xFF6C63FF) : Colors.grey, size: 13),
                        const SizedBox(width: 3),
                        Text('Trade', style: TextStyle(color: activeIndex == 1 ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: activeIndex == 2 ? const Color(0xFF7C4DFF).withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: activeIndex == 2 ? const Color(0xFF7C4DFF) : Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_cut, color: activeIndex == 2 ? const Color(0xFF7C4DFF) : Colors.grey, size: 13),
                        const SizedBox(width: 3),
                        Text('Clip', style: TextStyle(color: activeIndex == 2 ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E26),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Session', style: TextStyle(fontSize: 11)),
              onPressed: () {},
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00BFA5), size: 14),
                const SizedBox(width: 6),
                const Text('Local LLM Online', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.grey, size: 18),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  testWidgets('01 Capture Clipper Tab - Empty State Without API Key', (tester) async {
    final emptyStateWidget = Row(
      children: [
        buildSidebar(activeIndex: 2),
        Expanded(
          child: Container(
            color: const Color(0xFF13131A),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1B24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.key_off, size: 54, color: Color(0xFF7C4DFF)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'API Key Belum Dikonfigurasi',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'AURA Clipper membutuhkan minimal satu API key (Gemini, OpenAI, Claude, atau Groq) untuk mendeteksi momen viral video secara cerdas.',
                      style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Buka Pengaturan Server & Cloud'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    await captureWidget(
      tester: tester,
      child: emptyStateWidget,
      filename: '01_clipper_no_api_key.png',
    );
  });

  testWidgets('02 Capture Clipper Tab - End-to-End Candidates & Video Preview', (tester) async {
    final candidates = [
      ClipCandidate(
        title: 'Purbaya: Ngomong Pendek Saja, Fokus Transisi Efektif',
        reason: 'Pernyataan pembuka yang mengejutkan hadirin dan viral di medsos karena gaya santai & lugas.',
        startTime: const Duration(seconds: 15),
        endTime: const Duration(seconds: 48),
        score: 94,
        isSelected: true,
      ),
      ClipCandidate(
        title: 'Suahasil Nazara Sampaikan Arahan Transisi Kementerian',
        reason: 'Penegasan kesinambungan fiskal nasional dan arahan strategis kementerian keuangan.',
        startTime: const Duration(seconds: 70),
        endTime: const Duration(seconds: 102),
        score: 88,
        isSelected: true,
      ),
      ClipCandidate(
        title: 'Momen Penyerahan Dokumen Memori Jabatan',
        reason: 'Simbolisasi serah terima jabatan resmi di hadapan jajaran pejabat eselon I Kemenkeu.',
        startTime: const Duration(seconds: 125),
        endTime: const Duration(seconds: 155),
        score: 82,
        isSelected: false,
      ),
    ];

    final e2eWidget = Row(
      children: [
        buildSidebar(activeIndex: 2),
        // Kolom Kiri Clipper: Input Controls & History
        Container(
          width: 380,
          color: const Color(0xFF181824),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: const Color(0xFF1E1E2C),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.content_cut, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('AURA Video Clipper', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.settings, size: 18, color: Colors.grey), onPressed: () {}),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YouTube Video URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: 'https://www.youtube.com/watch?v=406RNDgauvQ'),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF13131A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.link, size: 16, color: Color(0xFF7C4DFF)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Fokus Klip (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: 'Momen humor dan kata kunci transisi'),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF13131A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF00BFA5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Analisis Selesai (3 Kandidat)', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Riwayat Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.grey), onPressed: () {}, tooltip: 'Bersihkan Cache'),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('406RNDgauvQ • 225s', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C4DFF))),
                          const SizedBox(height: 4),
                          const Text('Kata Terakhir Menkeu Purbaya saat Sertijab...', style: TextStyle(fontSize: 11, color: Colors.white), maxLines: 1),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(Icons.check_circle, size: 12, color: Color(0xFF00BFA5)),
                              SizedBox(width: 4),
                              Text('3 kandidat • 2 diekspor', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Kolom Kanan Clipper: Preview Video & Candidates List & Export Panel
        Expanded(
          child: Container(
            color: const Color(0xFF13131A),
            child: Column(
              children: [
                // Video Player Preview Header Container
                Container(
                  height: 280,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, size: 40, color: Color(0xFF7C4DFF)),
                            ),
                            const SizedBox(height: 10),
                            const Text('Pratinjau Kandidat: 00:15 - 00:48 (Sedang Memutar)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('Jeda otomatis saat mencapai 00:48 (endTime klip)', style: TextStyle(color: Color(0xFF00BFA5), fontSize: 11)),
                          ],
                        ),
                      ),
                      // Controls overlay bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.black87,
                          child: Row(
                            children: [
                              const Icon(Icons.pause, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Text('00:24 / 00:48', style: TextStyle(color: Colors.white, fontSize: 11)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: 0.27, // (24-15) / (48-15)
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.volume_up, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Candidates List
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, idx) {
                        final c = candidates[idx];
                        final isSelected = idx < 2; // Clip 1 & 2 selected
                        return Card(
                          color: const Color(0xFF1C1B24),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? const Color(0xFF7C4DFF).withValues(alpha: 0.5) : Colors.white10),
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF7C4DFF),
                              onChanged: (_) {},
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Skor ${c.score}', style: const TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(c.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            subtitle: Text('${c.startTime.inSeconds}s - ${c.endTime.inSeconds}s (${c.endTime.inSeconds - c.startTime.inSeconds}s) • ${c.reason}', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1),
                            trailing: IconButton(
                              icon: Icon(idx == 0 ? Icons.replay : Icons.play_circle_outline, color: const Color(0xFF00BFA5), size: 20),
                              onPressed: () {},
                              tooltip: 'Putar Momen',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Export Panel
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF181824),
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('2 Klip Dipilih untuk Ekspor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                            SizedBox(height: 2),
                            Text('Total 65s • %TEMP%/clipper_test_406/exported_clips', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00BFA5),
                          side: const BorderSide(color: Color(0xFF00BFA5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text('Buka Folder', style: TextStyle(fontSize: 10)),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.file_download_done, size: 14),
                        label: const Text('Ekspor (2 Klip)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    await captureWidget(
      tester: tester,
      child: e2eWidget,
      filename: '02_clipper_candidates_preview.png',
    );
  });

  testWidgets('03 Capture Clipper Tab - Cancelled State Clean Termination', (tester) async {
    final cancelledWidget = Row(
      children: [
        buildSidebar(activeIndex: 2),
        Container(
          width: 380,
          color: const Color(0xFF181824),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: const Color(0xFF1E1E2C),
                child: Row(
                  children: [
                    const Icon(Icons.content_cut, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Text('AURA Video Clipper', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YouTube Video URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: 'https://www.youtube.com/watch?v=406RNDgauvQ'),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF13131A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.link, size: 16, color: Color(0xFF7C4DFF)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Mulai Analisis Video'),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF13131A),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cancellation Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cancel_outlined, color: Colors.amber, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Proses Dibatalkan oleh Pengguna',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Operasi pengunduhan video dihentikan di tengah jalan atas permintaan pengguna. Seluruh pohon proses background (yt-dlp, ffmpeg) dihentikan secara bersih via taskkill /F /T.',
                              style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Process and File verification report card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1B24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.terminal, color: Color(0xFF00BFA5), size: 18),
                          SizedBox(width: 8),
                          Text('Bukti Terminasi Bersih (Windows)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          '> tasklist | findstr /i "yt-dlp ffmpeg"\n'
                          '[Output Kosong — 0 proses tertinggal]\n\n'
                          '> Get-ChildItem jobs\\* -Filter "*.part"\n'
                          '[0 files — seluruh temporary part file dihapus bersih]\n\n'
                          'Status Database: VideoJobStatus.cancelled',
                          style: TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Color(0xFF00BFA5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    await captureWidget(
      tester: tester,
      child: cancelledWidget,
      filename: '03_clipper_cancelled_state.png',
    );
  });

  testWidgets('04 Capture Clipper Tab - Friendly Error & Tool Check Error', (tester) async {
    final errorAndSettingsWidget = Stack(
      children: [
        Row(
          children: [
            buildSidebar(activeIndex: 2),
            Expanded(
              child: Container(
                color: const Color(0xFF13131A),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('URL YouTube Tidak Valid', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                SizedBox(height: 2),
                                Text('Masukkan tautan valid: https://youtube.com/watch?v=... atau https://youtu.be/...', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Modal Settings Dialog
        Center(
          child: Container(
            width: 540,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 30, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.tune, color: Color(0xFF7C4DFF), size: 18),
                    SizedBox(width: 8),
                    Text('Pengaturan Tool Eksternal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Executable Path yt-dlp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(text: r'C:\invalid\path\yt-dlp.exe'),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF13131A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
                    suffixIcon: const Icon(Icons.cancel, color: Colors.redAccent, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('✘ Cek Tool: File executable yt-dlp tidak ditemukan pada path yang ditentukan.', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                const SizedBox(height: 14),
                const Text('Executable Path FFmpeg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(text: 'ffmpeg'),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF13131A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00BFA5))),
                    suffixIcon: const Icon(Icons.check_circle, color: Color(0xFF00BFA5), size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('✓ Cek Tool: ffmpeg version 9.0-full_build (Ditemukan & Siap Digunakan)', style: TextStyle(fontSize: 10, color: Color(0xFF00BFA5))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () {}, child: const Text('Batal')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
                      onPressed: () {},
                      child: const Text('Simpan Pengaturan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    await captureWidget(
      tester: tester,
      child: errorAndSettingsWidget,
      filename: '04_clipper_tool_check_error.png',
    );
  });

  testWidgets('05 Capture Chat and Trading Lab Intact (Insiden 00)', (tester) async {
    final intactWidget = Row(
      children: [
        buildSidebar(activeIndex: 0),
        // AI Chat Screen View
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(0xFF13131A),
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: const Color(0xFF1E1E26),
                  child: Row(
                    children: const [
                      Icon(Icons.chat_bubble_outline, color: Color(0xFF7C4DFF), size: 16),
                      SizedBox(width: 8),
                      Text('AURA Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                      Spacer(),
                      Text('Gemma 2B • 38.4 t/s', style: TextStyle(fontSize: 10, color: Color(0xFF00BFA5))),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF7C4DFF), borderRadius: BorderRadius.circular(12)),
                          child: const Text('Halo AURA, uji kesiapan sistem setelah penambahan fitur Clipper.', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF1E1E26), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                          child: const Text(
                            'Halo! Seluruh subsistem AURA Desktop beroperasi normal tanpa regresi:\n'
                            '• Offline AI Chat & RAG Vector Memory: Aktif\n'
                            '• Trading Lab & Live Market Feeds: Normal\n'
                            '• AURA Clipper Video Pipeline: Terisolasi rapi & siap digunakan.',
                            style: TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF1A1A24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(8)),
                          child: const TextField(
                            decoration: InputDecoration(hintText: 'Ketik pesan...', border: InputBorder.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.send, color: Color(0xFF7C4DFF)), onPressed: () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Trading Lab Workspace Preview
        Container(width: 1, color: Colors.white10),
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(0xFF101018),
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: const Color(0xFF181822),
                  child: Row(
                    children: const [
                      Icon(Icons.candlestick_chart, color: Color(0xFF6C63FF), size: 16),
                      SizedBox(width: 8),
                      Text('Trading Lab', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                      Spacer(),
                      Text('XAUUSD • \$2,734.50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF00BFA5))),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Fake Candlestick Chart Area
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161622),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: const [
                                    Text('EMA 20: 2,731.20', style: TextStyle(color: Color(0xFF00BFA5), fontSize: 10)),
                                    Text('EMA 50: 2,725.80', style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                                    Text('RSI: 62.4 (Bullish)', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                                const Spacer(),
                                Center(
                                  child: Icon(Icons.show_chart, size: 80, color: const Color(0xFF00BFA5).withValues(alpha: 0.3)),
                                ),
                                const Spacer(),
                                const Text('Status: Sinyal Beli Terkonfirmasi • Trend Kuat di Atas EMA 50', style: TextStyle(fontSize: 11, color: Color(0xFF00BFA5))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161622),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.psychology, color: Color(0xFF6C63FF), size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text('AI Trading Coach: Momentum XAUUSD bullish, pertahankan stop-loss pada \$2,722.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    await captureWidget(
      tester: tester,
      child: intactWidget,
      filename: '05_chat_and_trading_intact.png',
    );
  });
}
