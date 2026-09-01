import 'mt5_client.dart';
import 'mt5_models.dart';

abstract class Mt5Repository {
  Future<bool> isConnected();
  Future<Mt5AccountInfo?> getAccountInfo();
  Future<List<Mt5Position>> getOpenPositions();
  Future<Mt5OrderResult> executeOrder(Mt5OrderRequest order);
  Future<bool> closePosition(int ticket);
}

class Mt5RepositoryImpl implements Mt5Repository {
  final Mt5Client _client;

  Mt5RepositoryImpl({Mt5Client? client}) : _client = client ?? Mt5Client();

  @override
  Future<bool> isConnected() async {
    return await _client.checkHealth();
  }

  @override
  Future<Mt5AccountInfo?> getAccountInfo() async {
    try {
      return await _client.fetchAccountInfo();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Mt5Position>> getOpenPositions() async {
    try {
      return await _client.fetchPositions();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Mt5OrderResult> executeOrder(Mt5OrderRequest order) async {
    return await _client.sendOrder(order);
  }

  @override
  Future<bool> closePosition(int ticket) async {
    return await _client.closePosition(ticket);
  }
}
