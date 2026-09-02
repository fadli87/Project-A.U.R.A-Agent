# 🤖 AURA Trading Assistant — Panduan & Aturan Kerja Antigravity (Agy)

> **Untuk**: Antigravity (Agy) — AI Coding Executor  
> **Dari**: Shin & Fadli Santoso  
> **Proyek**: AURA Trading Assistant (Forex/Gold & Saham IDX)  
> **Lokasi Berkas**: `ANTIGRAVITY_WORKING_RULES.md` (di root `AURA_MonoRepo/`)

---

## 📌 1. Aturan Dasar & Pagar Pengaman (Safety & Architecture Rules)

1. **JANGAN SENTUH `aura_core/`**: Core AI (inference GGUF, memory ObjectBox, agent loop dasar) sudah stabil. Semua fitur trading baru **wajib** diletakkan di package baru `aura_trading/` atau diextend di `aura_mobile`/`aura_desktop`.
2. **Gunakan Path Dependencies**: Di `aura_mobile/pubspec.yaml` dan `aura_desktop/pubspec.yaml`, pastikan mengimpor package lokal dengan benar:
   ```yaml
   aura_trading:
     path: ../aura_trading
   ```
3. **Prinsip Human-in-the-Loop (Prinsip 5)**: Bot/AI **TIDAK BOLEH** mengeksekusi order `BUY`/`SELL` secara otonom ke MT5 tanpa konfirmasi eksplisit dari pengguna melalui modal dialog UI.
4. **Presisi Finansial (Prinsip 1)**: Seluruh perhitungan lot size, stop loss, take profit, dan PnL wajib menggunakan tipe data `Decimal` (bukan `double` sembarangan untuk kalkulasi uang/lot agar terhindar dari floating point rounding errors).
5. **Bahasa Pemrograman**: Dart/Flutter (untuk UI & shared logic) dan Python 3 (untuk MT5 Local Bridge Service di port 8088).

---

## 🔌 2. Target Utama Pekerjaan Selanjutnya (Implementasi MT5 Client & UI)

Script Python bridge lokal sudah tersedia di `tools/mt5_bridge/mt5_service.py` (berjalan di `http://127.0.0.1:8088`). Tugas Anda (Antigravity) adalah **membangun sisi Dart/Flutter** di dalam package `aura_trading` agar dapat berkomunikasi dengan bridge tersebut dan menampilkannya di UI.

Berikut adalah kerangka kode (skeleton) yang **wajib Anda implementasikan secara lengkap dan presisi**.

---

### 📂 Skeleton 1: Interface `Mt5Repository`
*Lokasi*: `aura_trading/lib/data/sources/mt5/mt5_repository.dart`

```dart
import 'package:decimal/decimal.dart';

class Mt5AccountInfo {
  final int login;
  final Decimal balance;
  final Decimal equity;
  final Decimal margin;
  final Decimal freeMargin;
  final String currency;
  final String server;

  const Mt5AccountInfo({
    required this.login,
    required this.balance,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.currency,
    required this.server,
  });

  factory Mt5AccountInfo.fromJson(Map<String, dynamic> json) {
    return Mt5AccountInfo(
      login: json['login'] ?? 0,
      balance: Decimal.parse(json['balance']?.toString() ?? '0'),
      equity: Decimal.parse(json['equity']?.toString() ?? '0'),
      margin: Decimal.parse(json['margin']?.toString() ?? '0'),
      freeMargin: Decimal.parse(json['free_margin']?.toString() ?? '0'),
      currency: json['currency'] ?? 'USD',
      server: json['server'] ?? '',
    );
  }
}

class Mt5Position {
  final int ticket;
  final String symbol;
  final String type; // 'BUY' or 'SELL'
  final Decimal volume;
  final Decimal openPrice;
  final Decimal currentPrice;
  final Decimal sl;
  final Decimal tp;
  final Decimal profit;

  const Mt5Position({
    required this.ticket,
    required this.symbol,
    required this.type,
    required this.volume,
    required this.openPrice,
    required this.currentPrice,
    required this.sl,
    required this.tp,
    required this.profit,
  });

  factory Mt5Position.fromJson(Map<String, dynamic> json) {
    return Mt5Position(
      ticket: json['ticket'] ?? 0,
      symbol: json['symbol'] ?? '',
      type: json['type'] ?? 'BUY',
      volume: Decimal.parse(json['volume']?.toString() ?? '0'),
      openPrice: Decimal.parse(json['open_price']?.toString() ?? '0'),
      currentPrice: Decimal.parse(json['current_price']?.toString() ?? '0'),
      sl: Decimal.parse(json['sl']?.toString() ?? '0'),
      tp: Decimal.parse(json['tp']?.toString() ?? '0'),
      profit: Decimal.parse(json['profit']?.toString() ?? '0'),
    );
  }
}

abstract class Mt5Repository {
  Future<bool> checkConnection();
  Future<Mt5AccountInfo> getAccountInfo();
  Future<List<Mt5Position>> getOpenPositions();
  Future<String> placeOrder({
    required String symbol,
    required String type, // 'BUY' or 'SELL'
    required Decimal volume,
    Decimal? stopLoss,
    Decimal? takeProfit,
  });
  Future<String> closePosition(int ticket);
}
```

---

### 📂 Skeleton 2: Implementasi `Mt5Client` (HTTP REST Client)
*Lokasi*: `aura_trading/lib/data/sources/mt5/mt5_client.dart`

```dart
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'mt5_repository.dart';

class Mt5Client implements Mt5Repository {
  final String baseUrl;
  final http.Client httpClient;

  Mt5Client({this.baseUrl = 'http://127.0.0.1:8088', http.Client? client})
      : httpClient = client ?? http.Client();

  @override
  Future<bool> checkConnection() async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['connected'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Mt5AccountInfo> getAccountInfo() async {
    final response = await httpClient.get(Uri.parse('$baseUrl/account'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return Mt5AccountInfo.fromJson(data);
      }
      throw Exception(data['message'] ?? 'Failed to get account info');
    }
    throw Exception('HTTP Error: ${response.statusCode}');
  }

  @override
  Future<List<Mt5Position>> getOpenPositions() async {
    final response = await httpClient.get(Uri.parse('$baseUrl/positions'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        final list = data['positions'] as List<dynamic>? ?? [];
        return list.map((e) => Mt5Position.fromJson(e)).toList();
      }
      throw Exception(data['message'] ?? 'Failed to get positions');
    }
    throw Exception('HTTP Error: ${response.statusCode}');
  }

  @override
  Future<String> placeOrder({
    required String symbol,
    required String type,
    required Decimal volume,
    Decimal? stopLoss,
    Decimal? takeProfit,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'symbol': symbol,
        'type': type,
        'volume': volume.toDouble(),
        'sl': stopLoss?.toDouble() ?? 0.0,
        'tp': takeProfit?.toDouble() ?? 0.0,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['order_id'].toString();
    }
    throw Exception(data['message'] ?? 'Order execution failed');
  }

  @override
  Future<String> closePosition(int ticket) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/close_position'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ticket': ticket}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['ticket'].toString();
    }
    throw Exception(data['message'] ?? 'Close position failed');
  }
}
```

---

### 📂 Skeleton 3: Riverpod State Management (`mt5_provider.dart`)
*Lokasi*: `aura_trading/lib/presentation/providers/mt5_provider.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/sources/mt5/mt5_client.dart';
import '../../data/sources/mt5/mt5_repository.dart';

part 'mt5_provider.g.dart';

@riverpod
Mt5Repository mt5Repository(Mt5RepositoryRef ref) {
  return Mt5Client();
}

@riverpod
Future<bool> mt5ConnectionStatus(Mt5ConnectionStatusRef ref) async {
  final repo = ref.watch(mt5RepositoryProvider);
  return await repo.checkConnection();
}

@riverpod
Future<Mt5AccountInfo> mt5Account(Mt5AccountRef ref) async {
  final repo = ref.watch(mt5RepositoryProvider);
  return await repo.getAccountInfo();
}

@riverpod
Future<List<Mt5Position>> mt5Positions(Mt5PositionsRef ref) async {
  final repo = ref.watch(mt5RepositoryProvider);
  return await repo.getOpenPositions();
}
```

---

### 📂 Skeleton 4: UI Konfirmasi Eksekusi (Prinsip 5)
*Lokasi*: `aura_trading/lib/presentation/widgets/mt5_execution_dialog.dart`

```dart
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

class Mt5ExecutionDialog extends StatelessWidget {
  final String symbol;
  final String type; // 'BUY' or 'SELL'
  final Decimal volume;
  final Decimal? stopLoss;
  final Decimal? takeProfit;
  final VoidCallback onConfirm;

  const Mt5ExecutionDialog({
    Key? key,
    required this.symbol,
    required this.type,
    required this.volume,
    this.stopLoss,
    this.takeProfit,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isBuy = type.toUpperCase() == 'BUY';
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: isBuy ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          const Text('⚠️ Konfirmasi Eksekusi MT5'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Anda akan mengirim order live/demo ke MetaTrader 5:'),
          const SizedBox(height: 12),
          _buildRow('Symbol', symbol),
          _buildRow('Tipe', type),
          _buildRow('Volume', '$volume Lot'),
          _buildRow('Stop Loss', stopLoss?.toString() ?? 'Tidak ada'),
          _buildRow('Take Profit', takeProfit?.toString() ?? 'Tidak ada'),
          const SizedBox(height: 12),
          const Text(
            'Pastikan parameter risiko sudah sesuai dengan rencana trading Anda.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isBuy ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm();
          },
          child: Text('EKSEKUSI $type'),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
```

---

## 🛠️ 3. Instruksi Eksekusi untuk Antigravity

Ketika Anda (Antigravity) mulai bekerja pada task ini, ikuti urutan berikut:
1. **Buat file-file di atas** sesuai struktur folder package `aura_trading`.
2. **Jalankan `flutter pub run build_runner build --delete-conflicting-outputs`** di dalam folder `aura_trading` untuk men-generate file `.g.dart` Riverpod.
3. **Hubungkan widget `RiskCard` atau screen trading** dengan `Mt5ExecutionDialog` dan `Mt5Repository`.
4. **Verifikasi** dengan menjalankan script Python `tools/mt5_bridge/mt5_service.py` lalu test koneksi dari Flutter desktop/mobile.

---
*Dokumen aturan dan skeleton ini adalah instruksi operasional baku bagi Antigravity.*