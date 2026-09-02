# 📋 IMPLEMENTATION VERIFICATION GUIDE
## Koneksi RiskCardWidget → Mt5OrderDialog → MT5 Bridge

> **Target**: Antigravity (Agy)  
> **Status Kode**: **Sudah Terimplementasi** (perlu verifikasi & testing)  
> **File Utama**: `aura_trading/lib/presentation/widgets/risk_card.dart`  
> **Tujuan**: Memastikan alur *Risk Calculation → Confirmation Dialog → MT5 Execution* berfungsi end-to-end dengan benar.

---

## ✅ 1. Status Kode Saat Ini (Sudah Ada)

### `risk_card.dart` (Baris 178-191)
```dart
// Sudah terhubung ke Mt5OrderDialog
OutlinedButton.icon(
  onPressed: () {
    final entry = Decimal.tryParse(_entryController.text) ?? Decimal.zero;
    final sl = Decimal.tryParse(_slController.text) ?? Decimal.zero;
    final action = entry >= sl ? 'BUY' : 'SELL'; // Logika sederhana

    Mt5OrderDialog.show(
      context,
      symbol: 'XAUUSD',              // ⚠️ HARDCODED - perlu dinamis
      action: action,
      volume: _calcResult!.recommendedLots,
      entryPrice: entry,
      stopLoss: sl,
      maxLossAmount: _calcResult!.maxLoss,
      // takeProfit: null,           // ⚠️ BELUM ADA INPUT TP
    );
  },
  icon: const Icon(Icons.send_to_mobile, size: 14),
  label: const Text('Kirim ke MT5'),
)
```

### `mt5_order_dialog.dart` (Sudah Lengkap)
- Multi-layer confirmation (Prinsip 5)
- Loading state saat mengirim order
- Success/Error feedback visual
- Menggunakan `Mt5Client` langsung (bukan via Repository provider)

---

## 🔧 2. Item yang Perlu Diperbaiki / Dilengkapi (Action Items untuk Antigravity)

| # | Item | Deskripsi | File Target | Prioritas |
|---|------|-----------|-------------|-----------|
| **1** | **Simbol Dinamis** | Ganti hardcoded `'XAUUSD'` dengan dropdown/picker simbol aktif (Forex pairs, Gold, Indeks). | `risk_card.dart` | 🔴 **Tinggi** |
| **2** | **Input Take Profit** | Tambah `TextField` TP di RiskCard, teruskan ke `Mt5OrderDialog.show(takeProfit: tp)`. | `risk_card.dart` + dialog | 🔴 **Tinggi** |
| **3** | **Validasi Pre-Eksekusi** | Sebelum buka dialog: cek `Mt5Client.checkHealth()` → jika offline, tampilkan warning, jangan buka dialog. | `risk_card.dart` | 🟡 **Sedang** |
| **4** | **Gunakan Repository Provider** | Dialog saat ini pakai `Mt5Client` langsung. Sebaiknya pakai `ref.read(mt5RepositoryProvider)` agar konsisten dengan arsitektur & testable. | `mt5_order_dialog.dart` | 🟡 **Sedang** |
| **5** | **Auto-Fill dari Chart** | Jika user klik simbol di Watchlist/Chart → RiskCard auto-fill simbol, entry (harga saat ini), SL default (ATR-based). | `risk_card.dart` + provider | 🟢 **Rendah** |
| **6** | **Risk:Reward Ratio Display** | Tampilkan RR ratio di hasil kalkulasi (misal: `RR 1:2.5`) sebelum kirim ke MT5. | `risk_card.dart` | 🟢 **Rendah** |

---

## 🧪 3. Checklist Testing End-to-End (Wajib Dilakukan Antigravity)

### Persiapan Environment
- [ ] MT5 Terminal berjalan & login ke akun (Demo/Real)
- [ ] `Allow WebRequest for http://127.0.0.1:8088` + `Allow DLL imports` aktif di MT5 → Tools > Options > Expert Advisors
- [ ] Python environment: `pip install MetaTrader5 Flask Flask-CORS`
- [ ] Jalankan bridge: `python tools/mt5_bridge/mt5_service.py` → log `🚀 AURA MT5 Local Bridge Service starting on http://127.0.0.1:8088`

### Test Case 1: Koneksi Dasar
- [ ] Buka `aura_desktop` / `aura_mobile`
- [ ] Cek `Mt5StatusBarWidget` di header: harus muncul **🟢 MT5 Connected** + Balance/Equity/Free Margin
- [ ] Jika 🔴 Offline → cek firewall, port 8088, MT5 terminal running

### Test Case 2: Kalkulasi Risiko
- [ ] Isi Equity: `10000`, Risk: `2%`, Entry: `2650`, SL: `2630` (Gold)
- [ ] Tekan **"Hitung Lot Safe"**
- [ ] Verifikasi hasil: Lot ≈ `0.10`, Max Loss ≈ `$200` (2% dari $10k)

### Test Case 3: Kirim ke MT5 (Full Flow)
- [ ] Setelah kalkulasi valid, tekan **"Kirim ke MT5"**
- [ ] **Dialog Konfirmasi Muncul** dengan detail:
  - Symbol: XAUUSD
  - Action: BUY/SELL
  - Volume: 0.10 Lot
  - Entry: 2650
  - SL: 2630
  - Max Risk: $200.00
  - Badge "Prinsip 5: Order hanya dikirim..."
- [ ] Tekan **"🚀 Eksekusi ke MT5"**
- [ ] Loading spinner → Success message di dialog
- [ ] Cek MT5 Terminal: **Order baru terbuka** di tab Trade dengan Magic Number `234000` & Comment `AURA Risk-First Execution`

### Test Case 4: Error Handling
- [ ] Matikan MT5 Terminal → coba kirim order → dialog harus tampil error "MT5 initialization failed" / "Order execution failed"
- [ ] Masukkan SL = Entry (invalid) → kalkulasi tidak jalan / tampil warning
- [ ] Margin tidak cukup → MT5 return error → dialog tampilkan pesan error dari bridge

### Test Case 5: Close Position
- [ ] Buka `Mt5PositionsWidget` (harus muncul di dashboard)
- [ ] Posisi yang baru dibuka muncul di list dengan PnL real-time
- [ ] Tekan tombol **Close (X)** → dialog konfirmasi "Yakin ingin menutup posisi #...?"
- [ ] Konfirmasi → posisi tertutup di MT5 → list refresh otomatis

---

## 📝 4. Kode Referensi Perbaikan (Siap Pakai Antigravity)

### Fix 1: Simbol Dinamis + TP Input + Health Check (Update `risk_card.dart`)

```dart
// Tambah di _RiskCardWidgetState:
final _tpController = TextEditingController(); // Take Profit optional
String _selectedSymbol = 'XAUUSD'; // Default, nanti dari provider

// Di build(), ganti tombol "Kirim ke MT5" dengan:
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Color(0xFF00E676)),
      foregroundColor: const Color(0xFF00E676),
      padding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: () async {
      // 1. Validasi input
      final entry = Decimal.tryParse(_entryController.text) ?? Decimal.zero;
      final sl = Decimal.tryParse(_slController.text) ?? Decimal.zero;
      final tpText = _tpController.text.trim();
      final tp = tpText.isNotEmpty ? Decimal.tryParse(tpText) : null;
      
      if (entry <= Decimal.zero || sl <= Decimal.zero || entry == sl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry & SL harus valid & berbeda')),
        );
        return;
      }

      // 2. Cek koneksi MT5 dulu (via Repository Provider)
      final repo = context.read(mt5RepositoryProvider); // butuh ProviderScope ancestor
      final connected = await repo.isConnected();
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ MT5 Bridge offline. Jalankan python bridge.')),
        );
        return;
      }

      // 3. Tentukan action (bisa ditambah toggle BUY/SELL manual)
      final action = entry >= sl ? 'BUY' : 'SELL';

      // 4. Buka dialog konfirmasi
      if (mounted) {
        Mt5OrderDialog.show(
          context,
          symbol: _selectedSymbol,
          action: action,
          volume: _calcResult!.recommendedLots,
          entryPrice: entry,
          stopLoss: sl,
          takeProfit: tp,
          maxLossAmount: _calcResult!.maxLoss,
        );
      }
    },
    icon: const Icon(Icons.send_to_mobile, size: 14),
    label: const Text('Kirim ke MT5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  ),
)
```

### Fix 2: Update `Mt5OrderDialog` pakai Repository Provider (bukan Mt5Client langsung)

```dart
// Di mt5_order_dialog.dart, ubah:
class _Mt5OrderDialogState extends State<Mt5OrderDialog> {
  // HAPUS: final Mt5Client _client = Mt5Client();
  
  // TAMBAHKAN:
  late final Mt5Repository _repo;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambil repository via ProviderScope (butuh Consumer ancestor)
    _repo = ProviderScope.containerOf(context).read(mt5RepositoryProvider);
  }

  // Di _executeOrder():
  final result = await _repo.executeOrder(request); // Ganti _client.sendOrder(request)
}
```

> **Catatan**: Karena `Mt5OrderDialog` dipakai via `showDialog` (bukan widget tree biasa), perlu `ProviderScope` di `main.dart` atau wrap dialog dengan `ProviderScope` manual. Alternatif simpel: pass `Mt5Repository` instance ke `Mt5OrderDialog.show()`.

---

## 🚀 5. Perintah Eksekusi untuk Antigravity

```bash
# 1. Masuk folder package trading
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_trading

# 2. Generate Riverpod code (jika ada provider baru)
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Analisis kode
flutter analyze

# 4. Test unit yang ada
flutter test test/position_sizer_test.dart

# 5. Jalankan aplikasi desktop untuk manual testing
cd ../aura_desktop
flutter run -d windows

# ATAU mobile (butuh device/emulator)
cd ../aura_mobile
flutter run
```

---

## 📌 6. Catatan Penting untuk Antigravity

1. **Jangan ubah `aura_core`** — hanya kerja di `aura_trading`, `aura_mobile`, `aura_desktop`.
2. **Decimal wajib** untuk semua kalkulasi uang/lot (sudah benar di kode).
3. **Prinsip 5 non-negotiable**: Tidak ada auto-execute. Selalu dialog konfirmasi.
4. **Magic Number `234000`** di bridge Python — jangan diganti kecuali koordinasi dengan tim.
5. **Commit message format**: `feat(trading): connect RiskCard to MT5 execution dialog` dll.

---

*Dokumen ini adalah panduan verifikasi & perbaikan. Kode dasar sudah berjalan — tugas Antigravity: **testing nyata di device + perbaikan item #1-#4 di atas**.*