# 📱 ANDROID SDK VERSION LOCK — RULE TETAP

> **Status**: **FINAL & MUTLAK** — Tidak boleh diubah, ditanyakan, atau dinegosiasi.  
> **Target**: Antigravity (Agy) — Eksekusi sekali saja, selesai.  
> **Lokasi**: `.agents/rules/15-android-sdk-version-lock.md`

---

## 🔒 **KEPUTUSAN: compileSdkVersion = 36 (API 36 / Android 16 / Preview)**

| Parameter | Nilai | Catatan |
|-----------|-------|---------|
| `compileSdkVersion` | **36** | Sudah terbukti build berhasil di `aura_mobile` |
| `targetSdkVersion` | **34** | Tetap 34 untuk kompatibilitas plugin stabil |
| `minSdkVersion` | **26** | Android 8.0 (Oreo) - sudah di build.gradle.kts |
| `gradle.properties` | `android.compileSdk=36`<br>`android.targetSdk=34` | Override untuk semua subprojects/plugin |

---

## 🚫 **LARANGAN MUTLAK (Anti-Looping)**

| Dilarang | Alasan |
|-----------|--------|
| ❌ Turunkan ke **35 / 34** | **Sudah terbukti 36 jalan** — tidak perlu downgrade |
| ❌ Tanya "boleh ke 35?" | **TIDAK BOLEH** — build sudah sukses di 36 |
| ❌ Coba-coba SDK Manager install 35 | Tidak perlu, 36 sudah terinstall & jalan |

---

## ✅ **KONFIGURASI FINAL (Sudah Di Kode)**

### `android/app/build.gradle.kts`
```kotlin
android {
    namespace = "com.aura.aura"
    compileSdk = 36          // ← FINAL: 36 (TERBUKTI JALAN)
    ndkVersion = "26.1.10909125"
    // ...
    defaultConfig {
        minSdk = 26
        targetSdk = flutter.targetSdkVersion  // ← Akan ambil 34 dari gradle.properties
    }
}
```

### `android/gradle.properties`
```properties
android.compileSdk=36
android.targetSdk=34
```

---

## 🛡️ **Jika Error di Masa Depan**

| Error | Tindakan |
|-------|----------|
| Plugin butuh API < 36 | Upgrade plugin, **jangan downgrade compileSdk** |
| `android-36 not found` | `flutter doctor --android-licenses` → install SDK 36 via SDK Manager |
| Gradle cache corrupt | `flutter clean` → delete `.gradle` → `flutter pub get` |

**compileSdkVersion 36 terkunci selamanya untuk AURA Mobile.**

---

*Rule ini mengikuti realita build terakhir: **SDK 36 BERJALAN NORMAL**.*