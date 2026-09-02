# 📅 IMPLEMENTATION GUIDE: Economic Calendar Widget (Forex Factory Style)

> **Target**: Antigravity (Agy)  
> **Prioritas**: 🟡 **Sedang** — Data & Provider sudah ada, butuh UI Widget  
> **File Terkait**: `aura_trading/lib/presentation/providers/market_data_provider.dart`, `aura_trading/lib/data/sources/news/forex_factory_calendar.dart`

---

## 🎯 Tujuan
Tampilkan **Kalender Ekonomi** real-time di UI (Mobile & Desktop) dengan:
- Warna impact: 🔴 High / 🟠 Medium / 🟡 Low
- Filter by currency (USD, EUR, GBP, JPY, IDR, AUD, NZD, CHF, CAD)
- AI Explain: Tap event → AI jelaskan dampak ke pair terkait
- Auto-refresh setiap 1 jam

---

## 📦 1. Data Model (Sudah Ada / Perlu Lengkapi)

`aura_trading/lib/data/models/economic_event.dart` — **Buat file baru**:

```dart
import 'package:intl/intl.dart';

enum EventImpact { high, medium, low, none }

class EconomicEvent {
  final String id;
  final DateTime dateTime; // UTC
  final String currency;
  final String title;
  final EventImpact impact;
  final String? forecast;
  final String? previous;
  final String? actual;
  final String? detailUrl; // Link ke ForexFactory/Investing detail

  const EconomicEvent({
    required this.id,
    required this.dateTime,
    required this.currency,
    required this.title,
    required this.impact,
    this.forecast,
    this.previous,
    this.actual,
    this.detailUrl,
  });

  factory EconomicEvent.fromJson(Map<String, dynamic> json) {
    return EconomicEvent(
      id: json['id'] ?? '',
      dateTime: DateTime.tryParse(json['date'] ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      currency: json['currency'] ?? '',
      title: json['title'] ?? json['event'] ?? '',
      impact: _parseImpact(json['impact']),
      forecast: json['forecast'],
      previous: json['previous'],
      actual: json['actual'],
      detailUrl: json['url'],
    );
  }

  static EventImpact _parseImpact(dynamic v) {
    final s = v?.toString().toLowerCase() ?? '';
    if (s.contains('high') || s == 'red') return EventImpact.high;
    if (s.contains('medium') || s == 'orange') return EventImpact.medium;
    if (s.contains('low') || s == 'yellow') return EventImpact.low;
    return EventImpact.none;
  }

  Color get impactColor {
    switch (impact) {
      case EventImpact.high: return const Color(0xFFFF5252);
      case EventImpact.medium: return const Color(0xFFFFB74D);
      case EventImpact.low: return const Color(0xFFFFEB3B);
      default: return Colors.white38;
    }
  }

  String get impactLabel {
    switch (impact) {
      case EventImpact.high: return 'TINGGI';
      case EventImpact.medium: return 'SEDANG';
      case EventImpact.low: return 'RENDAH';
      default: return '';
    }
  }

  String get formattedTimeWIB {
    // Forex Factory UTC → WIB (UTC+7)
    final wib = dateTime.add(const Duration(hours: 7));
    return DateFormat('HH:mm').format(wib);
  }

  String get formattedDateWIB {
    final wib = dateTime.add(const Duration(hours: 7));
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(wib);
  }
}
```

---

## 🔌 2. Provider Update (Market Data Provider)

Edit `aura_trading/lib/presentation/providers/market_data_provider.dart` — tambah provider kalender:

```dart
// Tambah import
import '../models/economic_event.dart';
import '../../data/sources/news/forex_factory_calendar.dart';

// Provider kalender ekonomi (auto-refresh 1 jam)
final economicCalendarProvider = FutureProvider.autoDispose<List<EconomicEvent>>((ref) async {
  final calendar = ForexFactoryCalendar();
  return await calendar.fetchCalendar();
});

// Provider filter by currency (watch dari user settings nanti)
final filteredCalendarProvider = Provider.autoDispose.family<List<EconomicEvent>, List<String>>((ref, currencies) {
  final allEvents = ref.watch(economicCalendarProvider);
  return allEvents.when(
    data: (events) => events.where((e) => currencies.contains(e.currency)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
```

---

## 🎨 3. Widget Utama: `EconomicCalendarWidget`

Buat file: `aura_trading/lib/presentation/widgets/economic_calendar_widget.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/market_data_provider.dart';
import '../../data/models/economic_event.dart';
import '../../ai/trading_tools.dart'; // untuk AI explain
import 'package:aura_core/aura_core.dart'; // InferenceProvider

class EconomicCalendarWidget extends ConsumerStatefulWidget {
  const EconomicCalendarWidget({super.key});

  @override
  ConsumerState<EconomicCalendarWidget> createState() => _EconomicCalendarWidgetState();
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
          // ── Header dengan Filter ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF6C63FF), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kalender Ekonomi',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    // Date picker
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ref.invalidate(economicCalendarProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Currency filter chips
                _CurrencyFilterChips(
                  selected: _selectedCurrencies,
                  onChanged: (val) => setState(() => _selectedCurrencies = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // ── Body ──────────────────────────────────────────────────
          calendarAsync.when(
            loading: () => const _CalendarLoading(),
            error: (err, _) => _CalendarError(message: 'Gagal memuat kalender: $err'),
            data: (allEvents) {
              // Filter by selected date & currencies
              final wibNow = DateTime.now().add(const Duration(hours: 7));
              final startOfDay = DateTime(wibNow.year, wibNow.month, wibNow.day).subtract(const Duration(hours: 7));
              final endOfDay = startOfDay.add(const Duration(days: 1));

              final filtered = allEvents.where((e) {
                final inDate = e.dateTime.isAfter(startOfDay) && e.dateTime.isBefore(endOfDay);
                final inCurrency = _selectedCurrencies.contains(e.currency);
                return inDate && inCurrency;
              }).toList()
                ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

              if (filtered.isEmpty) {
                return const _CalendarEmpty();
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10, indent: 12, endIndent: 12),
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
          colorScheme: const ColorScheme.dark(primary: Color(0xFF6C63FF), surface: Color(0xFF1E1E2C)),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────

class _CurrencyFilterChips extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _CurrencyFilterChips({required this.selected, required this.onChanged});

  static const _allCurrencies = ['USD', 'EUR', 'GBP', 'JPY', 'IDR', 'AUD', 'NZD', 'CHF', 'CAD', 'CNY'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _allCurrencies.map((c) {
        final isSel = selected.contains(c);
        return FilterChip(
          label: Text(c, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          selected: isSel,
          onSelected: (v) {
            final newList = List<String>.from(selected);
            v ? newList.add(c) : newList.remove(c);
            onChanged(newList);
          },
          selectedColor: c == 'USD' ? const Color(0xFF00E676) : (c == 'IDR' ? const Color(0xFFFFB74D) : const Color(0xFF6C63FF)),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        );
      }).toList(),
    );
  }
}

class _EventTile extends ConsumerWidget {
  final EconomicEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPast = event.dateTime.isBefore(DateTime.now().toUtc());
    final hasActual = event.actual != null && event.actual!.isNotEmpty;

    return InkWell(
      onTap: () => _showAiExplain(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time + Impact badge
            Column(
              children: [
                Text(
                  event.formattedTimeWIB,
                  style: TextStyle(
                    color: isPast ? Colors.white38 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: event.impactColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Currency flag + title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CurrencyFlag(currency: event.currency),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            color: isPast ? Colors.white54 : Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (event.forecast != null) _DataBadge(label: 'Fcst', value: event.forecast!, color: Colors.white38),
                      if (event.previous != null) _DataBadge(label: 'Prev', value: event.previous!, color: Colors.white38),
                      if (hasActual) _DataBadge(label: 'Act', value: event.actual!, color: event.impactColor),
                    ],
                  ),
                ],
              ),
            ),

            // AI Explain button
            IconButton(
              icon: const Icon(Icons.psychology_outlined, color: Color(0xFF6C63FF), size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Tanya AI dampak event ini',
              onPressed: () => _showAiExplain(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiExplain(BuildContext context, WidgetRef ref) {
    // Trigger AI Coach dengan prompt khusus event ini
    final prompt = '''
Event Ekonomi: ${event.title}
Mata Uang: ${event.currency}
Waktu (WIB): ${event.formattedTimeWIB} (${event.formattedDateWIB})
Impact: ${event.impactLabel}
Forecast: ${event.forecast ?? 'N/A'}
Previous: ${event.previous ?? 'N/A'}
Actual: ${event.actual ?? 'Belum keluar'}

Jelaskan secara singkat (2-3 kalimat):
1. Apa arti event ini untuk pasar?
2. Dampak potensial ke ${event.currency} pairs (contoh: ${event.currency}USD, EUR${event.currency})?
3. Apakah trader sebaiknya hindari trading saat rilis ini?
Bahasa Indonesia, santai tapi tajam.
''';

    // TODO: Integrate dengan chat provider / AI Coach dialog
    // ref.read(chatProvider.notifier).sendMessage(prompt, isCoach: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🤖 AI Coach: $prompt'), backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.9)),
    );
  }
}

class _CurrencyFlag extends StatelessWidget {
  final String currency;
  const _CurrencyFlag({required this.currency});

  @override
  Widget build(BuildContext context) {
    // Simple flag emoji mapping
    final flags = {
      'USD': '🇺🇸', 'EUR': '🇪🇺', 'GBP': '🇬🇧', 'JPY': '🇯🇵',
      'IDR': '🇮🇩', 'AUD': '🇦🇺', 'NZD': '🇳🇿', 'CHF': '🇨🇭',
      'CAD': '🇨🇦', 'CNY': '🇨🇳',
    };
    return Text(flags[currency] ?? '🏳️', style: const TextStyle(fontSize: 14));
  }
}

class _DataBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DataBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _CalendarLoading extends StatelessWidget {
  const _CalendarLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF))),
  );
}

class _CalendarError extends StatelessWidget {
  final String message;
  const _CalendarError({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.white54, fontSize: 11))),
    ]),
  );
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: Text('Tidak ada event untuk filter ini', style: TextStyle(color: Colors.white38, fontSize: 12))),
  );
}
```

---

## 🔧 4. Scraper `ForexFactoryCalendar` (Jika Belum Ada)

`aura_trading/lib/data/sources/news/forex_factory_calendar.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/economic_event.dart';

class ForexFactoryCalendar {
  static const _url = 'https://nfs.faireconomy.media/ff_calendar_thisweek.json'; // Public FF calendar

  Future<List<EconomicEvent>> fetchCalendar() async {
    try {
      final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => EconomicEvent.fromJson(e)).toList();
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      // Fallback ke Investing.com scraper atau cache lokal
      return _getCachedOrEmpty();
    }
  }

  List<EconomicEvent> _getCachedOrEmpty() {
    // TODO: Implement local cache (SharedPreferences / SQLite)
    return [];
  }
}
```

---

## 📱 5. Integrasi ke Dashboard (Mobile & Desktop)

### Mobile: Tab/Home Screen
```dart
// Di dashboard mobile screen
EconomicCalendarWidget(), // Taruh di bawah Watchlist / di tab terpisah
```

### Desktop: Sidebar Panel
```dart
// Di layout desktop (samping kiri/kanan)
ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 360),
  child: EconomicCalendarWidget(),
),
```

---

## ✅ 6. Checklist Verifikasi Antigravity

| Test | Expected |
|------|----------|
| Load widget | Kalender muncul, auto-fetch hari ini |
| Filter currency | Chip USD/IDR dll berfungsi, list update real-time |
| Date picker | Ganti tanggal → event hari itu muncul |
| Impact badge | 🔴 High (NFP, CPI, FOMC), 🟠 Medium, 🟡 Low |
| Tap event → AI Explain | Snackbar/Dialog muncul dengan analisis AI (mock dulu, nanti hook ke chat provider) |
| Auto-refresh 1 jam | Provider `autoDispose` + `StreamProvider` periodic (optional) |
| Offline | Tampilkan cached data / error state yang informatif |

---

## 🚀 7. Perintah Eksekusi

```bash
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_trading

# 1. Buat model & widget
# 2. Update market_data_provider.dart
# 3. Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Analisis
flutter analyze

# 5. Test manual di desktop
cd ../aura_desktop
flutter run -d windows
```

---

## 💡 Catatan untuk Antigravity
- **ForexFactory JSON** public & gratis, tapi rate-limit. Cache ke lokal (SQLite/SharedPrefs) wajib.
- **Timezone**: FF UTC → convert ke WIB (UTC+7) di model.
- **AI Explain**: Gunakan `InferenceProvider` existing, inject prompt khusus event.
- **IDR events**: Pastikan scraper ambil event BI Rate, Inflasi ID, GDP ID (biasanya di Investing.com Indonesia section).

*Widget ini lengkapi "Situational Awareness" trader di dashboard AURA.*