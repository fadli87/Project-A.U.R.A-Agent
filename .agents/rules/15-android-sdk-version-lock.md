# 📱 ANDROID SDK VERSION LOCK — RULE TETAP

> **Status**: **FINAL & MUTLAK** — Tidak boleh diubah, ditanyakan, atau dinegosiasi.  
> **Target**: Antigravity (Agy) — Eksekusi sekali saja, selesai.  
> **Lokasi**: `.agents/rules/15-android-sdk-version-lock.md`

---

## 🔒 **KEPUTUSAN: compileSdkVersion = 34 (API 34 / Android 14)**

| Parameter | Nilai | Catatan |
|-----------|-------|---------|
| `compileSdkVersion` | **34** | Wajib di `android/app/build.gradle` |
| `targetSdkVersion` | **34** | Wajib di `android/app/build.gradle` |
| `minSdkVersion` | **23** | Tetap (Android 6.0) |
| `gradle.properties` | `android.compileSdkVersion=34`<br>`android.targetSdkVersion=34` | Override untuk semua subprojects/plugin |

---

## 🚫 **LARANGAN MUTLAK (Anti-Looping)**

| Dilarang | Alasan |
|-----------|--------|
| ❌ Naikkan ke **35 (Android 15)** | Plugin `android_file_picker`, `flutter_secure_storage`, `camera`, `path_provider` dll **belum stabil** → error `android-35 hash string not found` |
| ❌ Naikkan ke **36 (Android 16/preview)** | Masih preview, plugin pasti gagal |
| ❌ Tanya "boleh ke 35?" | **TIDAK BOLEH** — sudah 2x gagal (awal project + sekarang) |
| ❌ Coba-coba SDK Manager install 35 | Sudah dicoba → install "complete" tapi build tetap gagal (hash string mismatch) |

---

## ✅ **PROSEDUR EKSEKUSI SATU KALI (Copy-Paste Jalankan)**

```bash
# 1. Masuk folder project mobile
cd C:/devapp/AURA_MonoRepo/Project-A.U.R.A-Agent/aura_mobile

# 2. Set compileSdkVersion & targetSdkVersion ke 34 di build.gradle
#    (Gunakan sed / PowerShell / manual edit - pastikan kedua nilai = 34)

# 3. Tambahkan override di gradle.properties
echo "android.compileSdkVersion=34" >> android/gradle.properties
echo "android.targetSdkVersion=34" >> android/gradle.properties

# 4. Bersihkan & rebuild
flutter clean
flutter pub get
flutter run -d <device_id>
```

---

## 📝 **File yang Harus Diubah (Pastikan Antigravity Edit Ini Saja)**

### `android/app/build.gradle`
```gradle
android {
    namespace "com.aura.aura"
    compileSdkVersion 34          // ← FINAL: 34
    ndkVersion flutter.ndkVersion

    defaultConfig {
        applicationId "com.aura.aura"
        minSdkVersion 23
        targetSdkVersion 34       // ← FINAL: 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
    // ... sisanya biarkan
}
```

### `android/gradle.properties` (Tambahkan di akhir file)
```properties
# ... existing props ...
android.compileSdkVersion=34
android.targetSdkVersion=34
```

---

## 🛡️ **Jika Masih Error Setelah Ini**

| Error | Tindakan Antigravity |
|-------|----------------------|
| `android-34 not found` | Install SDK 34 via SDK Manager → `flutter doctor --android-licenses` |
| Plugin X butuh API 35+ | **Downgrade plugin** ke versi yang support API 34 (cek `pubspec.yaml` versi lama) |
| `minSdkVersion` conflict | Pastikan `minSdkVersion 23` di semua module |
| Gradle cache corrupt | `flutter clean` → delete `.gradle` folder → `flutter pub get` |

**TIDAK BOLEH** naikkan `compileSdkVersion` sebagai solusi. Titik.

---

## 🎯 **Verifikasi Sukses**
Build berhasil jika log menampilkan:
```
✓ Compile SDK version: 34
✓ Target SDK version: 34
BUILD SUCCESSFUL in xx s
Installing APK on device...
Flutter run completed.
```

---

*Rule ini mengikat selamanya untuk project AURA Mobile. Antigravity wajib patuhi tanpa diskusi.*