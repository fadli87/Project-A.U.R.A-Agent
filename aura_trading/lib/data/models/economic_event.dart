import 'package:flutter/material.dart';
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
  final String? detailUrl;

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
      id: json['id']?.toString() ?? '',
      dateTime: DateTime.tryParse(json['date']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      currency: json['country']?.toString() ?? json['currency']?.toString() ?? '',
      title: json['title']?.toString() ?? json['event']?.toString() ?? '',
      impact: _parseImpact(json['impact']),
      forecast: json['forecast']?.toString(),
      previous: json['previous']?.toString(),
      actual: json['actual']?.toString(),
      detailUrl: json['url']?.toString(),
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
      case EventImpact.high:
        return const Color(0xFFFF5252);
      case EventImpact.medium:
        return const Color(0xFFFFB74D);
      case EventImpact.low:
        return const Color(0xFFFFEB3B);
      default:
        return Colors.white38;
    }
  }

  String get impactLabel {
    switch (impact) {
      case EventImpact.high:
        return 'TINGGI';
      case EventImpact.medium:
        return 'SEDANG';
      case EventImpact.low:
        return 'RENDAH';
      default:
        return '';
    }
  }

  String get formattedTimeWIB {
    final wib = dateTime.add(const Duration(hours: 7));
    return DateFormat('HH:mm').format(wib);
  }

  String get formattedDateWIB {
    final wib = dateTime.add(const Duration(hours: 7));
    return DateFormat('EEEE, d MMMM yyyy').format(wib);
  }
}
