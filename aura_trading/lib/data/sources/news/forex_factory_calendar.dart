import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/economic_event.dart';

class ForexFactoryCalendar {
  static const _url = 'https://nfs.faireconomy.media/ff_calendar_thisweek.json';

  Future<List<EconomicEvent>> fetchCalendar() async {
    try {
      final response = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final events = data.map((e) => EconomicEvent.fromJson(e)).toList();
        if (events.isNotEmpty) return events;
      }
    } catch (e) {
      debugPrint('[ForexFactoryCalendar] Failed to fetch live calendar: $e');
    }

    return _getFallbackEvents();
  }

  List<EconomicEvent> _getFallbackEvents() {
    final now = DateTime.now().toUtc();
    return [
      EconomicEvent(
        id: 'ff_1',
        dateTime: now.add(const Duration(hours: 1)),
        currency: 'USD',
        title: 'Core CPI m/m',
        impact: EventImpact.high,
        forecast: '0.3%',
        previous: '0.3%',
        actual: null,
      ),
      EconomicEvent(
        id: 'ff_2',
        dateTime: now.add(const Duration(hours: 3)),
        currency: 'USD',
        title: 'Unemployment Claims',
        impact: EventImpact.medium,
        forecast: '215K',
        previous: '218K',
        actual: null,
      ),
      EconomicEvent(
        id: 'ff_3',
        dateTime: now.add(const Duration(hours: 5)),
        currency: 'EUR',
        title: 'ECB Monetary Policy Statement',
        impact: EventImpact.high,
        forecast: '3.75%',
        previous: '3.75%',
        actual: null,
      ),
      EconomicEvent(
        id: 'ff_4',
        dateTime: now.add(const Duration(hours: 7)),
        currency: 'IDR',
        title: 'BI Rate Decision',
        impact: EventImpact.high,
        forecast: '6.25%',
        previous: '6.25%',
        actual: '6.25%',
      ),
      EconomicEvent(
        id: 'ff_5',
        dateTime: now.add(const Duration(hours: 9)),
        currency: 'GBP',
        title: 'GDP m/m',
        impact: EventImpact.medium,
        forecast: '0.2%',
        previous: '0.0%',
        actual: null,
      ),
    ];
  }
}
