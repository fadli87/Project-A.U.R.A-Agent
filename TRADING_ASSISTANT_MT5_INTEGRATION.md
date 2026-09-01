# 🔌 [ANALISIS & DESAIN INTEGRASI] AURA <-> METATRADER 5 (MT5) PLATFORM

> **Kategori**: Dokumentasi Arsitektur Integrasi MT5 (Forex & Gold Broker Execution)  
> *Lokasi Berkas*: Root Project (`Project-A.U.R.A-Agent/TRADING_ASSISTANT_MT5_INTEGRATION.md`)  
> *Terakhir diperbarui*: 1 September 2026

---

## 🎯 1. Tujuan Integrasi

Menghubungkan **AURA Trading Assistant** (`aura_trading`, `aura_desktop`, `aura_mobile`) dengan terminal **MetaTrader 5 (MT5)** untuk:
1. **Mengambil Data Tick & Candle Real-time** langsung dari server broker terhubung (IC Markets, Pepperstone, Exness, dll).
2. **Sinkronisasi Saldo & Posisi Terbuka**: Membaca saldo akun riil (*Balance, Equity, Margin*) dan posisi terbuka dari MT5 ke *Risk Dashboard* AURA.
3. **Eksekusi Order Terbimbing (Risk-Managed Execution)**: Mengirim order `BUY`/`SELL` beserta `Stop Loss`, `Take Profit`, dan `Lot Size` hasil kalkulasi `PositionSizer` langsung ke terminal MT5 dengan **konfirmasi manual manusia (Prinsip 5)**.

---

## 🏗️ 2. Pilihan Arsitektur Integrasi (MT5 Bridge Options)

Karena terminal MT5 berjalan sebagai aplikasi Windows desktop native (.exe) atau MQL5 environment, ada **3 pendekatan utama** untuk menghubungkan `aura_trading` (Dart/Flutter):

```
+-----------------------------------------------------------------------------------+
|                              AURA Application Layer                               |
|                     (aura_desktop / aura_mobile / aura_trading)                   |
+-----------------------------------------------------------------------------------+
                                         |
                       (Local HTTP REST / WebSocket JSON)
                                         |
        +--------------------------------+--------------------------------+
        |                                |                                |
        v                                v                                v
[ 🐍 Pilihan A: Python MT5 Bridge ]  [ ⚡ Pilihan B: MQL5 ZeroMQ EA ]  [ 🌐 Pilihan C: WebAPI ]
 - Menggunakan library resmi         - EA MQL5 terpasang di chart      - Berbayar / butuh
   MetaTrader5 Python               - Membuka ZeroMQ socket port       kredensial broker
 - Jalur paling stabil & cepat       - Komunikasi MQL5 direct          server manager
```

---

### 🔍 Perbandingan Pendekatan

| Fitur / Parameter | Pilihan A: Python MT5 Local Service (Rekomendasi Utama) | Pilihan B: MQL5 EA + ZeroMQ Bridge | Pilihan C: Broker REST WebAPI |
| :--- | :--- | :--- | :--- |
| **Kemudahan Setup** | **Tinggi**: Cukup jalankan script Python kecil di background. | **Sedang**: Perlu install EA MQL5 & DLL ZeroMQ di MT5. | **Rendah**: Terbatas hanya broker tertentu yang membuka WebAPI. |
| **Kecepatan Exec** | **Sangat Cepat** (< 10 ms via IPC/Localhost). | **Sangat Cepat** (< 5 ms via socket). | Tergantung latensi jaringan internet. |
| **Dukungan Broker** | **100% Semua Broker MT5** (bekerja di atas MT5 Terminal Windows). | **100% Semua Broker MT5**. | Hanya broker pendukung. |
| **Stabilitas** | **Tinggi**: Menggunakan API resmi MetaQuotes Python. | **Sedang**: Tergantung kestabilan socket MQL5. | Tinggi. |

---

## 📐 3. Detail Desain Pilihan A: Python MT5 Local Bridge (Rekomendasi)

### A. Komponen Script Python (`mt5_bridge_service.py`)
Script Python ringan yang berjalan di background Windows (Port `127.0.0.1:8088`):

```python
import MetaTrader5 as mt5
from flask import Flask, request, jsonify

app = Flask(__name__)

# Initialize connection to running MT5 Terminal
if not mt5.initialize():
    print("MT5 initialization failed:", mt5.last_error())

@app.route('/account', methods=['GET'])
def get_account():
    acc = mt5.account_info()
    if acc is None:
        return jsonify({"status": "error", "message": "Failed to get account info"}), 500
    return jsonify({
        "status": "success",
        "login": acc.login,
        "balance": acc.balance,
        "equity": acc.equity,
        "margin": acc.margin,
        "free_margin": acc.margin_free
    })

@app.route('/order', methods=['POST'])
def place_order():
    data = request.json
    symbol = data['symbol']
    order_type = mt5.ORDER_TYPE_BUY if data['type'] == 'BUY' else mt5.ORDER_TYPE_SELL
    price = mt5.symbol_info_tick(symbol).ask if data['type'] == 'BUY' else mt5.symbol_info_tick(symbol).bid
    
    request_dict = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": float(data['volume']),
        "type": order_type,
        "price": price,
        "sl": float(data.get('sl', 0.0)),
        "tp": float(data.get('tp', 0.0)),
        "deviation": 20,
        "magic": 234000,
        "comment": "AURA AI Execution",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    
    result = mt5.order_send(request_dict)
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        return jsonify({"status": "error", "message": f"Order failed: {result.comment}"}), 400
        
    return jsonify({"status": "success", "order_id": result.order, "price": result.price})

if __name__ == '__main__':
    app.run(port=8088)
```

---

### B. Abstraksi Repository di `aura_trading`

Dibuatlah interface `Mt5Repository` di `aura_trading`:

```dart
// aura_trading/lib/data/sources/mt5/mt5_repository.dart

import 'package:decimal/decimal.dart';

class Mt5AccountInfo {
  final int login;
  final Decimal balance;
  final Decimal equity;
  final Decimal margin;
  final Decimal freeMargin;

  const Mt5AccountInfo({
    required this.login,
    required this.balance,
    required this.equity,
    required this.margin,
    required this.freeMargin,
  });
}

class Mt5OrderRequest {
  final String symbol;
  final String type; // 'BUY' / 'SELL'
  final Decimal volume; // Lot size
  final Decimal? stopLoss;
  final Decimal? takeProfit;

  const Mt5OrderRequest({
    required this.symbol,
    required this.type,
    required this.volume,
    this.stopLoss,
    this.takeProfit,
  });
}

abstract class Mt5Repository {
  Future<bool> isConnected();
  Future<Mt5AccountInfo> getAccountInfo();
  Future<String> placeOrder(Mt5OrderRequest order);
}
```

---

## 🛡️ 4. Menyesuaikan dengan Pagar Keamanan (Rules AURA)

### 🔴 Prinsip 5: Manusia SELALU Pemicu Akhir (Dilarang Otonom Penuh)
Order **TIDAK BISA** ditempatkan langsung oleh AI tanpa dialog konfirmasi UI:

```
[ AI Coach / Risk Card ]
          │
          ▼  Generates recommendation (Symbol: XAUUSD, Lot: 0.10, SL: 2630)
[ User Interface ]
          │
          ▼  Displays Confirmation Modal Dialog:
          │  ┌──────────────────────────────────────────────┐
          │  │ ⚠️ KONFIRMASI EKSEKUSI MT5                   │
          │  │ Symbol : XAUUSD (BUY)                        │
          │  │ Volume : 0.10 Lot                            │
          │  │ SL     : 2630.00  | TP: 2690.00             │
          │  │ Risk   : $200.00 (2.0% Equity)               │
          │  │                                              │
          │  │ [ BATAL ]       [ 🚀 EKSEKUSI KE MT5 ]       │
          │  └──────────────────────────────────────────────┘
          │
          ▼ User explicitly clicks [ EKSEKUSI KE MT5 ]
[ Mt5Repository.placeOrder() ]
          │
          ▼ Sends HTTP POST to Local Python Bridge
[ MetaTrader 5 Terminal Executed ]
```

### 🔴 Prinsip 1: Presisi `Decimal`
Seluruh perhitungan saldo, PnL, harga SL, TP, dan Lot di AURA diproses dalam `Decimal` sebelum dikonversi ke string numerik yang presisi saat dikirimkan ke MT5 API.

---

## 🚀 5. Langkah-Langkah Rencana Implementasi

1. **Phase MT5-1: Local Bridge Script**: Buat folder `tools/mt5_bridge/` di root repo yang berisi `mt5_bridge_service.py` dan `requirements.txt` (`MetaTrader5`, `Flask`).
2. **Phase MT5-2: `Mt5Client` di `aura_trading`**: Buat REST client `Mt5Client` yang melakukan HTTP request ke `http://127.0.0.1:8088`.
3. **Phase MT5-3: UI Dialog Konfirmasi Eksekusi MT5**: Tambahkan tombol *"Kirim ke MT5"* di `RiskCardWidget` dan `desktop_trading_screen.dart` yang membuka dialog konfirmasi multi-layer sebelum order dikirim.
4. **Phase MT5-4: Sync Live Balance**: Tampilkan indikator status koneksi MT5 (*Connected / Disconnected*) di Header Bar `aura_desktop` beserta update saldo akun riil.

---

*Dokumen analisis ini siap digunakan sebagai acuan pengembangan integrasi MT5 di AURA Trading Assistant.*
