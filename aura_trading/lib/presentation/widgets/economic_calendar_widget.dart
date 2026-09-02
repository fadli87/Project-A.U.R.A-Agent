import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/market_data_provider.dart';
import '../../data/models/economic_event.dart';

class EconomicCalendarWidget extends ConsumerStatefulWidget {
  const EconomicCalendarWidget({super.key});

  @override
  ConsumerState<EconomicCalendarWidget> createState() =>
      _EconomicCalendarWidgetState();
}

class _EconomicCalendarWidgetState extends ConsumerState<EconomicCalendarWidget> {
  List<String> _selectedCurrencies = ['USD', 'EUR', 'GBP', 'JPY', 'IDR', 'AUD'];
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(economicCalendarProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header & Currency Filter ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF6C63FF), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kalender Ekonomi',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                    // Date picker chip
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Colors.white54, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          ref.invalidate(economicCalendarProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CurrencyFilterChips(
                  selected: _selectedCurrencies,
                  onChanged: (val) => setState(() => _selectedCurrencies = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // ── Events List ───────────────────────────────────────────
          calendarAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF6C63FF)),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF5252), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gagal memuat kalender: $err',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            data: (allEvents) {
              final filtered = allEvents
                  .where((e) => _selectedCurrencies.contains(e.currency))
                  .toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Tidak ada event untuk filter ini',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Colors.white10, indent: 12, endIndent: 12),
                itemBuilder: (context, i) => _EventTile(event: filtered[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            surface: Color(0xFF1E1E2C),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }
}

class _CurrencyFilterChips extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _CurrencyFilterChips({required this.selected, required this.onChanged});

  static const _allCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'IDR',
    'AUD',
    'NZD',
    'CHF',
    'CAD',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: _allCurrencies.map((c) {
        final isSel = selected.contains(c);
        return FilterChip(
          label: Text(
            c,
            style: TextStyle(
              color: isSel ? Colors.black : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          selected: isSel,
          onSelected: (v) {
            final newList = List<String>.from(selected);
            v ? newList.add(c) : newList.remove(c);
            onChanged(newList);
          },
          selectedColor: c == 'USD'
              ? const Color(0xFF00E676)
              : (c == 'IDR' ? const Color(0xFFFFB74D) : const Color(0xFF6C63FF)),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        );
      }).toList(),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EconomicEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isPast = event.dateTime.isBefore(DateTime.now().toUtc());
    final hasActual = event.actual != null && event.actual!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time & Impact Dot
          Column(
            children: [
              Text(
                event.formattedTimeWIB,
                style: TextStyle(
                  color: isPast ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: event.impactColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Currency & Event Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.currency,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPast ? Colors.white54 : Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (event.forecast != null)
                      _DataBadge(
                          label: 'Fcst',
                          value: event.forecast!,
                          color: Colors.white38),
                    if (event.previous != null)
                      _DataBadge(
                          label: 'Prev',
                          value: event.previous!,
                          color: Colors.white38),
                    if (hasActual)
                      _DataBadge(
                          label: 'Act',
                          value: event.actual!,
                          color: event.impactColor),
                  ],
                ),
              ],
            ),
          ),

          // AI Explain Icon
          IconButton(
            icon: const Icon(Icons.psychology_outlined,
                color: Color(0xFF6C63FF), size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'AI Analysis',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🤖 AI Coach (${event.currency}): ${event.title} — Forecast: ${event.forecast ?? "N/A"}, Prev: ${event.previous ?? "N/A"}. High impact volatility expected.',
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF6C63FF),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DataBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DataBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
