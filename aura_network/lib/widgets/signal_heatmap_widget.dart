import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drive_test_log.dart';
import '../models/cell_signal_info.dart';
import '../providers/drive_test_provider.dart';

/// Signal heatmap widget — peta dengan titik drive test diwarnai berdasarkan kualitas sinyal.
/// Ported dari G-Net Track clone (flutter_map + OpenStreetMap).
class SignalHeatmapWidget extends ConsumerWidget {
  final List<LogPoint> points;
  final bool followDevice;

  const SignalHeatmapWidget({
    super.key,
    required this.points,
    this.followDevice = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveState = ref.watch(driveTestNotifierProvider);
    final lastPoint = driveState.lastPoint;

    final center = _computeCenter(lastPoint, points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            // OSM tile layer (gratis, tidak perlu API key)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aura.network',
            ),

            // Signal markers
            CircleLayer(
              circles: points.map((p) => CircleMarker(
                point: LatLng(p.latitude, p.longitude),
                radius: 7,
                color: _signalColor(p.rsrpDbm).withOpacity(0.75),
                borderStrokeWidth: 1.5,
                borderColor: _signalColor(p.rsrpDbm),
                useRadiusInMeter: false,
              )).toList(),
            ),

            // Current position marker
            if (lastPoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lastPoint.latitude, lastPoint.longitude),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF4FC3F7), width: 3),
                        boxShadow: [BoxShadow(color: const Color(0xFF4FC3F7).withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  LatLng _computeCenter(LogPoint? last, List<LogPoint> pts) {
    if (last != null) return LatLng(last.latitude, last.longitude);
    if (pts.isNotEmpty) return LatLng(pts.last.latitude, pts.last.longitude);
    return const LatLng(-6.2088, 106.8456); // Default: Jakarta
  }

  Color _signalColor(int? rsrp) {
    if (rsrp == null) return Colors.grey;
    if (rsrp >= -85) return const Color(0xFF4CAF50);  // excellent: green
    if (rsrp >= -98) return const Color(0xFF8BC34A);  // good: light green
    if (rsrp >= -110) return const Color(0xFFFF9800); // fair: orange
    return const Color(0xFFF44336);                    // poor: red
  }
}
