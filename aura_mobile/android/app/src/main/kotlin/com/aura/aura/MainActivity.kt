package com.aura.aura

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aura.aura/system"
    private var methodChannel: MethodChannel? = null
    private var initialSessionId: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent != null && intent.hasExtra("sessionId")) {
            val sessionId = intent.getIntExtra("sessionId", -1)
            if (sessionId != -1) {
                initialSessionId = sessionId
                methodChannel?.invokeMethod("onNotificationTap", sessionId)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val content = call.argument<String>("content") ?: ""
                    val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                    val sessionId = call.argument<Int>("sessionId") ?: -1

                    scheduleAlarm(id, title, content, timeInMillis, sessionId)
                    result.success(null)
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelAlarm(id)
                    result.success(null)
                }
                "getLaunchSessionId" -> {
                    result.success(initialSessionId)
                    // Clear after read to prevent repetitive navigations on hot restart
                    initialSessionId = null
                }
                "searchWeb" -> {
                    val query = call.argument<String>("query") ?: ""
                    searchWeb(query)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleAlarm(id: Int, title: String, content: String, timeInMillis: Long, sessionId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("title", title)
            putExtra("content", content)
            putExtra("sessionId", sessionId)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
        }
    }

    private fun cancelAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun searchWeb(query: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" + Uri.encode(query)))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
