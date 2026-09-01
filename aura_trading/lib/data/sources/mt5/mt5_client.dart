import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mt5_models.dart';

/// REST client communicating with the local Python MT5 Bridge Service (http://127.0.0.1:8088).
class Mt5Client {
  final String baseUrl;
  final http.Client _httpClient;

  Mt5Client({
    this.baseUrl = 'http://127.0.0.1:8088',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Checks if the MT5 bridge service and MT5 terminal are online.
  Future<bool> checkHealth() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['connected'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Fetches real-time account information from MT5.
  Future<Mt5AccountInfo> fetchAccountInfo() async {
    final response = await _httpClient
        .get(Uri.parse('$baseUrl/account'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return Mt5AccountInfo.fromJson(data);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch MT5 account info.');
      }
    } else {
      throw Exception('HTTP error ${response.statusCode} from MT5 bridge.');
    }
  }

  /// Fetches active open positions from MT5.
  Future<List<Mt5Position>> fetchPositions() async {
    final response = await _httpClient
        .get(Uri.parse('$baseUrl/positions'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        final list = data['positions'] as List<dynamic>? ?? [];
        return list.map((p) => Mt5Position.fromJson(p as Map<String, dynamic>)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch MT5 positions.');
      }
    } else {
      throw Exception('HTTP error ${response.statusCode} from MT5 bridge.');
    }
  }

  /// Sends an order request to MT5.
  Future<Mt5OrderResult> sendOrder(Mt5OrderRequest order) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/order'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(order.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Mt5OrderResult.fromJson(data);
    } else {
      final msg = data['message'] ?? 'Order execution failed.';
      return Mt5OrderResult(
        success: false,
        orderId: '',
        executedPrice: order.volume, // fallback
        volume: order.volume,
        message: msg,
      );
    }
  }

  /// Closes an open position by ticket ID.
  Future<bool> closePosition(int ticket) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/close_position'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'ticket': ticket}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'success';
    }
    return false;
  }
}
