import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_network/aura_network.dart';

/// Layar utama Network Monitor AURA.
/// Tab: Signal | WiFi/LAN | Drive Test | Tools
class NetworkMonitorScreen extends ConsumerStatefulWidget {
  const NetworkMonitorScreen({super.key});

  @override
  ConsumerState<NetworkMonitorScreen> createState() => _NetworkMonitorScreenState();
}

class _NetworkMonitorScreenState extends ConsumerState<NetworkMonitorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Network Monitor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        'AURA Network Analyzer',
                        style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Inter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.5)),
                  ),
                  labelColor: const Color(0xFF4FC3F7),
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  unselectedLabelStyle: const TextStyle(fontSize: 11, fontFamily: 'Inter'),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.cell_tower, size: 16), text: 'Signal'),
                    Tab(icon: Icon(Icons.wifi, size: 16), text: 'WiFi/LAN'),
                    Tab(icon: Icon(Icons.directions_car, size: 16), text: 'Drive'),
                    Tab(icon: Icon(Icons.build_outlined, size: 16), text: 'Tools'),
                  ],
                ),
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Cellular Signal
                  _SignalTab(),

                  // Tab 2: WiFi + LAN
                  _WifiLanTab(),

                  // Tab 3: Drive Test
                  _DriveTestTab(),

                  // Tab 4: Network Tools
                  _ToolsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 1: Cellular Signal
// =============================================================================

class _SignalTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          SignalMonitorCard(),
          SizedBox(height: 16),
          SpeedTestWidget(),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 2: WiFi + LAN
// =============================================================================

class _WifiLanTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          WifiInfoCard(),
          SizedBox(height: 16),
          LanDevicesList(),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 3: Drive Test
// =============================================================================

class _DriveTestTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveState = ref.watch(driveTestNotifierProvider);
    final driveNotifier = ref.read(driveTestNotifierProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DriveTestControls(
            onExportCsv: driveState.sessionHistory.isNotEmpty
                ? () => driveNotifier.exportCsv(driveState.sessionHistory.first.id!)
                : null,
            onExportKml: driveState.sessionHistory.isNotEmpty
                ? () => driveNotifier.exportKml(driveState.sessionHistory.first.id!)
                : null,
          ),
          const SizedBox(height: 16),

          // Heatmap (hanya tampil jika ada session aktif atau history)
          if (driveState.isRunning || driveState.lastPoint != null) ...[
            SignalHeatmapWidget(
              points: const [], // Akan diisi dari DB query di masa depan
              followDevice: driveState.isRunning,
            ),
            const SizedBox(height: 16),
          ],

          // Export result snackbar
          if (driveState.exportedFilePath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Disimpan: ${driveState.exportedFilePath}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 4: Network Tools
// =============================================================================

class _ToolsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          NetworkToolsPanel(),
        ],
      ),
    );
  }
}
