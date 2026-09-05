package com.aura.network

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * AuraNetworkPlugin — registers all native channels for aura_network.
 *
 * Channels:
 *   - com.aura.network/telephony → NativeTelephonyHandler
 *   - com.aura.network/wifi      → NativeWifiHandler
 *
 * Ported & adapted from G-Net Track clone (NativeTelephonyPlugin.kt).
 * Battle-tested on: Xiaomi Mi A1 (PixelExperience 12), Infinix Hot 12i (XOS).
 */
class AuraNetworkPlugin : FlutterPlugin {

    private lateinit var telephonyChannel: MethodChannel
    private lateinit var wifiChannel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext

        telephonyChannel = MethodChannel(binding.binaryMessenger, "com.aura.network/telephony")
        telephonyChannel.setMethodCallHandler(NativeTelephonyHandler(context))

        wifiChannel = MethodChannel(binding.binaryMessenger, "com.aura.network/wifi")
        wifiChannel.setMethodCallHandler(NativeWifiHandler(context))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        telephonyChannel.setMethodCallHandler(null)
        wifiChannel.setMethodCallHandler(null)
    }
}

// =============================================================================
// TELEPHONY HANDLER — port dari G-Net Track NativeTelephonyPlugin.kt
// =============================================================================

class NativeTelephonyHandler(private val context: Context) : MethodCallHandler {

    private val telephonyManager: TelephonyManager by lazy {
        context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCellInfo"  -> handleGetCellInfo(call, result)
            "getSimSlots"  -> handleGetSimSlots(result)
            else           -> result.notImplemented()
        }
    }

    private fun handleGetCellInfo(call: MethodCall, result: Result) {
        try {
            val subscriptionId = call.argument<Int?>("subscriptionId")
            val manager = if (subscriptionId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                telephonyManager.createForSubscriptionId(subscriptionId)
            } else {
                telephonyManager
            }

            val networkType = getNetworkTypeString(manager)
            val allCellInfo: List<CellInfo> = try { manager.allCellInfo ?: emptyList() } catch (e: SecurityException) { emptyList() }

            val servingCell = allCellInfo
                .firstOrNull { it.isRegistered }
                ?.let { cellInfoToMap(it) }

            val neighborCells = allCellInfo
                .filter { !it.isRegistered }
                .mapNotNull { cellInfoToMap(it) }

            result.success(mapOf(
                "subscriptionId"       to subscriptionId,
                "networkType"          to networkType,
                "simOperator"          to (manager.simOperator ?: ""),
                "simOperatorName"      to (manager.simOperatorName ?: ""),
                "networkOperator"      to (manager.networkOperator ?: ""),
                "networkOperatorName"  to (manager.networkOperatorName ?: ""),
                "servingCell"          to servingCell,
                "neighborCells"        to neighborCells,
            ))
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "READ_PHONE_STATE or ACCESS_FINE_LOCATION not granted", null)
        } catch (e: Exception) {
            result.error("TELEPHONY_ERROR", e.message, null)
        }
    }

    private fun handleGetSimSlots(result: Result) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
                result.success(emptyList<Any>())
                return
            }
            val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            val subs = try { subscriptionManager?.activeSubscriptionInfoList } catch (e: SecurityException) { null }
            if (subs == null) {
                result.success(emptyList<Any>())
                return
            }
            val slotList = subs.map { info ->
                mapOf(
                    "subscriptionId" to info.subscriptionId,
                    "simSlotIndex"   to info.simSlotIndex,
                    "carrierName"    to (info.carrierName?.toString() ?: ""),
                    "displayName"    to (info.displayName?.toString() ?: ""),
                    "iccId"          to (try { info.iccId } catch (e: SecurityException) { null }),
                    "isActive"       to true,
                )
            }
            result.success(slotList)
        } catch (e: Exception) {
            result.success(emptyList<Any>())
        }
    }

    // ---- Cell info mappers --------------------------------------------------

    private fun cellInfoToMap(info: CellInfo): Map<String, Any?>? {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && info is CellInfoNr  -> nrToMap(info)
            info is CellInfoLte    -> lteToMap(info)
            info is CellInfoWcdma  -> wcdmaToMap(info)
            info is CellInfoGsm    -> gsmToMap(info)
            else                   -> null
        }
    }

    @Suppress("NewApi")
    private fun nrToMap(info: CellInfoNr): Map<String, Any?> {
        val identity = info.cellIdentity as? CellIdentityNr
        val signal = info.cellSignalStrength as? CellSignalStrengthNr
        return mapOf(
            "cellType"         to "NR",
            "isRegistered"     to info.isRegistered,
            "connectionStatus" to connectionStatus(info),
            "cellId"           to identity?.nci?.toInt(),
            "pci"              to identity?.pci,
            "tac"              to identity?.tac,
            "arfcn"            to identity?.nrarfcn,
            "band"             to try { identity?.bands?.firstOrNull()?.let { "n$it" } } catch (e: Exception) { null },
            "mcc"              to identity?.mccString,
            "mnc"              to identity?.mncString,
            "ssRsrp"           to signal?.ssRsrp?.takeIf { it != Int.MIN_VALUE },
            "ssRsrq"           to signal?.ssRsrq?.takeIf { it != Int.MIN_VALUE },
            "ssSinr"           to signal?.ssSinr?.takeIf { it != Int.MIN_VALUE },
            "csiRsrp"          to signal?.csiRsrp?.takeIf { it != Int.MIN_VALUE },
            "csiRsrq"          to signal?.csiRsrq?.takeIf { it != Int.MIN_VALUE },
            "csiSinr"          to signal?.csiSinr?.takeIf { it != Int.MIN_VALUE },
            "level"            to signal?.level,
        )
    }

    private fun lteToMap(info: CellInfoLte): Map<String, Any?> {
        val identity = info.cellIdentity
        val signal = info.cellSignalStrength
        val bandNumber = arfcnToLteBand(identity.earfcn)
        return mapOf(
            "cellType"         to "LTE",
            "isRegistered"     to info.isRegistered,
            "connectionStatus" to connectionStatus(info),
            "cellId"           to identity.ci.takeIf { it != Int.MAX_VALUE },
            "pci"              to identity.pci.takeIf { it != Int.MAX_VALUE },
            "tac"              to identity.tac.takeIf { it != Int.MAX_VALUE },
            "arfcn"            to identity.earfcn.takeIf { it != Int.MAX_VALUE },
            "band"             to bandNumber?.let { "B$it" },
            "mcc"              to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) identity.mccString else identity.mcc.takeIf { it != Int.MAX_VALUE }?.toString()),
            "mnc"              to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) identity.mncString else identity.mnc.takeIf { it != Int.MAX_VALUE }?.toString()),
            "rsrp"             to signal.rsrp.takeIf { it != Int.MIN_VALUE },
            "rsrq"             to signal.rsrq.takeIf { it != Int.MIN_VALUE },
            "sinr"             to signal.rssnr.takeIf { it != Int.MIN_VALUE },
            "cqi"              to signal.cqi.takeIf { it != Int.MIN_VALUE },
            "timingAdvance"    to signal.timingAdvance.takeIf { it != Int.MAX_VALUE },
            "level"            to signal.level,
        )
    }

    private fun wcdmaToMap(info: CellInfoWcdma): Map<String, Any?> {
        val identity = info.cellIdentity
        val signal = info.cellSignalStrength
        return mapOf(
            "cellType"         to "WCDMA",
            "isRegistered"     to info.isRegistered,
            "connectionStatus" to connectionStatus(info),
            "cellId"           to identity.cid.takeIf { it != Int.MAX_VALUE },
            "pci"              to identity.psc.takeIf { it != Int.MAX_VALUE },
            "lac"              to identity.lac.takeIf { it != Int.MAX_VALUE },
            "arfcn"            to identity.uarfcn.takeIf { it != Int.MAX_VALUE },
            "mcc"              to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) identity.mccString else identity.mcc.takeIf { it != Int.MAX_VALUE }?.toString()),
            "mnc"              to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) identity.mncString else identity.mnc.takeIf { it != Int.MAX_VALUE }?.toString()),
            "rssi"             to signal.dbm.takeIf { it != Int.MIN_VALUE },
            "dbm"              to signal.dbm.takeIf { it != Int.MIN_VALUE },
            "level"            to signal.level,
        )
    }

    private fun gsmToMap(info: CellInfoGsm): Map<String, Any?> {
        val identity = info.cellIdentity
        val signal = info.cellSignalStrength
        return mapOf(
            "cellType"         to "GSM",
            "isRegistered"     to info.isRegistered,
            "connectionStatus" to connectionStatus(info),
            "cellId"           to identity.cid.takeIf { it != Int.MAX_VALUE },
            "lac"              to identity.lac.takeIf { it != Int.MAX_VALUE },
            "arfcn"            to identity.arfcn.takeIf { it != Int.MAX_VALUE },
            "mcc"              to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) identity.mccString else identity.mcc.takeIf { it != Int.MAX_VALUE }?.toString()),
            "mnc"              to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) identity.mncString else identity.mnc.takeIf { it != Int.MAX_VALUE }?.toString()),
            "rssi"             to signal.dbm.takeIf { it != Int.MIN_VALUE },
            "dbm"              to signal.dbm.takeIf { it != Int.MIN_VALUE },
            "level"            to signal.level,
        )
    }

    private fun connectionStatus(info: CellInfo): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return when (info.cellConnectionStatus) {
                CellInfo.CONNECTION_PRIMARY_SERVING   -> "PRIMARY"
                CellInfo.CONNECTION_SECONDARY_SERVING -> "SECONDARY"
                CellInfo.CONNECTION_NONE              -> "NONE"
                else                                  -> "UNKNOWN"
            }
        }
        return if (info.isRegistered) "PRIMARY" else "NONE"
    }

    private fun getNetworkTypeString(manager: TelephonyManager): String {
        return try {
            when (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                manager.dataNetworkType
            } else {
                @Suppress("DEPRECATION")
                manager.networkType
            }) {
                TelephonyManager.NETWORK_TYPE_LTE  -> "4G LTE"
                TelephonyManager.NETWORK_TYPE_NR   -> "5G NR"
                TelephonyManager.NETWORK_TYPE_HSPA,
                TelephonyManager.NETWORK_TYPE_UMTS -> "3G WCDMA"
                TelephonyManager.NETWORK_TYPE_GSM,
                TelephonyManager.NETWORK_TYPE_EDGE,
                TelephonyManager.NETWORK_TYPE_GPRS -> "2G GSM"
                else                               -> "UNKNOWN"
            }
        } catch (e: SecurityException) {
            "UNKNOWN"
        }
    }

    /** Konversi EARFCN ke LTE Band number. */
    private fun arfcnToLteBand(earfcn: Int): Int? {
        if (earfcn == Int.MAX_VALUE || earfcn < 0) return null
        return when (earfcn) {
            in 0..599         -> 1
            in 600..1199      -> 2
            in 1200..1949     -> 3
            in 1950..2399     -> 4
            in 2400..2649     -> 5
            in 2750..3449     -> 7
            in 3450..3799     -> 8
            in 6150..6449     -> 11
            in 5000..5179     -> 13
            in 5180..5279     -> 14
            in 5730..5849     -> 17
            in 5850..5999     -> 18
            in 6000..6149     -> 19
            in 6450..6599     -> 20
            in 6600..6749     -> 21
            in 6750..7699     -> 22
            in 7700..8039     -> 25
            in 8040..8689     -> 26
            in 9210..9659     -> 28
            in 9660..9769     -> 29
            in 9770..9869     -> 30
            in 9870..9919     -> 31
            in 36000..36199   -> 40
            in 36200..36349   -> 41
            in 36350..36949   -> 42
            in 36950..37549   -> 43
            in 37550..37749   -> 44
            in 37750..38249   -> 45
            in 38250..38649   -> 46
            in 38650..39649   -> 48
            else              -> null
        }
    }
}

// =============================================================================
// WIFI HANDLER
// =============================================================================

class NativeWifiHandler(private val context: Context) : MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getWifiInfo" -> handleGetWifiInfo(result)
            else          -> result.notImplemented()
        }
    }

    @Suppress("Deprecation")
    private fun handleGetWifiInfo(result: Result) {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val wifiInfo = wifiManager?.connectionInfo

            if (wifiManager == null || !wifiManager.isWifiEnabled || wifiInfo == null ||
                wifiInfo.networkId == -1) {
                result.success(mapOf("isConnected" to false))
                return
            }

            val ssid = wifiInfo.ssid?.removePrefix("\"")?.removeSuffix("\"") ?: ""
            val rssi = wifiInfo.rssi
            val linkSpeed = wifiInfo.linkSpeed
            val channel = frequencyToChannel(wifiInfo.frequency)
            val band = if (wifiInfo.frequency > 4900) "5 GHz" else "2.4 GHz"
            val ip = intToIp(wifiInfo.ipAddress)

            val dhcpInfo = wifiManager.dhcpInfo
            val gateway = intToIp(dhcpInfo?.gateway ?: 0)

            result.success(mapOf(
                "isConnected"    to true,
                "ssid"           to ssid,
                "bssid"          to (wifiInfo.bssid ?: ""),
                "rssiDbm"        to rssi,
                "linkSpeedMbps"  to linkSpeed,
                "channel"        to channel,
                "band"           to band,
                "ipAddress"      to ip,
                "gateway"        to gateway,
            ))
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "ACCESS_FINE_LOCATION required to read WiFi info", null)
        } catch (e: Exception) {
            result.error("WIFI_ERROR", e.message, null)
        }
    }

    private fun frequencyToChannel(freq: Int): Int? {
        return when {
            freq in 2412..2484 -> (freq - 2407) / 5
            freq in 5170..5825 -> (freq - 5000) / 5
            else -> null
        }
    }

    private fun intToIp(ip: Int): String {
        return "${ip and 0xff}.${ip shr 8 and 0xff}.${ip shr 16 and 0xff}.${ip shr 24 and 0xff}"
    }
}
