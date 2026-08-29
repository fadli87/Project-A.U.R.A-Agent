import 'package:flutter/material.dart';

class SessionHeatmapWidget extends StatelessWidget {
  final bool isCompact;
  const SessionHeatmapWidget({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    final hourUtc = nowUtc.hour;

    // Tokyo: 00:00 - 09:00 UTC
    final isTokyoOpen = hourUtc >= 0 && hourUtc < 9;
    // London: 08:00 - 17:00 UTC
    final isLondonOpen = hourUtc >= 8 && hourUtc < 17;
    // New York: 13:00 - 22:00 UTC
    final isNewYorkOpen = hourUtc >= 13 && hourUtc < 22;

    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSessionBadge('Tokyo', '00-09', isTokyoOpen),
          const SizedBox(width: 4),
          _buildSessionBadge('London', '08-17', isLondonOpen),
          const SizedBox(width: 4),
          _buildSessionBadge('New York', '13-22', isNewYorkOpen),
        ],
      );
    }

    return Container(

      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, color: Color(0xFF29B6F6), size: 18),
              SizedBox(width: 8),
              Text(
                'Trading Sessions (UTC)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSessionBadge('Tokyo', '00-09 UTC', isTokyoOpen)),
              const SizedBox(width: 6),
              Expanded(child: _buildSessionBadge('London', '08-17 UTC', isLondonOpen)),
              const SizedBox(width: 6),
              Expanded(child: _buildSessionBadge('New York', '13-22 UTC', isNewYorkOpen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBadge(String name, String time, bool isOpen) {
    final activeColor = isOpen ? const Color(0xFF00E676) : Colors.white24;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFF00E676).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOpen ? const Color(0xFF00E676).withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                name,
                style: TextStyle(
                  color: isOpen ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isOpen ? 'ACTIVE' : time,
            style: TextStyle(
              color: isOpen ? const Color(0xFF00E676) : Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
