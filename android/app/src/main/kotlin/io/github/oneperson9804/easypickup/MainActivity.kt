package io.github.oneperson9804.easypickup

import android.Manifest
import android.appwidget.AppWidgetManager
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var permissionKind: String? = null
    private val executor = Executors.newSingleThreadExecutor()
    private var platformChannel: MethodChannel? = null
    private var recordsReceiverRegistered = false
    @Volatile private var sharedIntentStaged = false
    @Volatile private var sharedImportError: String? = null
    private val recordsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_RECORDS_CHANGED) platformChannel?.invokeMethod("recordsChanged", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        sharedIntentStaged = savedInstanceState?.getBoolean("sharedIntentStaged") ?: false
        if (!sharedIntentStaged && intent?.action == Intent.ACTION_SEND && intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY == 0) stageShare(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("sharedIntentStaged", sharedIntentStaged)
        super.onSaveInstanceState(outState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_SEND) {
            sharedIntentStaged = false
            stageShare(intent)
        }
    }

    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(recordsReceiver, IntentFilter(ACTION_RECORDS_CHANGED), Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(recordsReceiver, IntentFilter(ACTION_RECORDS_CHANGED))
        }
        recordsReceiverRegistered = true
    }

    override fun onStop() {
        if (recordsReceiverRegistered) unregisterReceiver(recordsReceiver)
        recordsReceiverRegistered = false
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        platformChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "easy_pickup/platform")
        platformChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getDatabasePath" -> {
                        getDatabasePath("easy_pickup.db").parentFile?.mkdirs()
                        result.success(getDatabasePath("easy_pickup.db").absolutePath)
                    }
                    "getPermissions" -> result.success(permissionState())
                    "consumeSharedImport" -> {
                        executor.execute {
                            try {
                                val error = sharedImportError
                                sharedImportError = null
                                if (error != null) throw IllegalStateException(error)
                                val value = SharedImports.peek(this)
                                runOnUiThread { result.success(value) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("share_import", "无法读取分享内容，请重新选择或使用手动添加。", null) }
                            }
                        }
                    }
                    "ackSharedImport" -> {
                        val id = call.argument<String>("draftId") ?: ""
                        executor.execute {
                            try {
                                SharedImports.acknowledge(this, id)
                                runOnUiThread { result.success(null) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("share_ack", error.message ?: "无法确认分享草稿", null) }
                            }
                        }
                    }
                    "requestSms" -> requestPermissionSet("sms", arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS), result)
                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT >= 33) requestPermissionSet("notifications", arrayOf(Manifest.permission.POST_NOTIFICATIONS), result)
                        else result.success(notificationsEnabled())
                    }
                    "importSms" -> {
                        if (!granted(Manifest.permission.READ_SMS)) {
                            result.error("sms_permission", "请先在权限说明中允许读取短信；也可使用粘贴、截图或手动添加。", null)
                        } else {
                            val since = call.argument<Number>("sinceMs")?.toLong() ?: System.currentTimeMillis() - 30L * 86400000
                            executor.execute {
                                try {
                                    val counts = importSms(since)
                                    runOnUiThread { result.success(counts) }
                                } catch (error: Exception) {
                                    runOnUiThread { result.error("sms_import", "短信导入失败：${error.javaClass.simpleName}", null) }
                                }
                            }
                        }
                    }
                    "refreshWidgets" -> { PickupWidget.refreshAll(this); result.success(null) }
                    "pinWidget" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        if (manager.isRequestPinAppWidgetSupported) {
                            result.success(manager.requestPinAppWidget(ComponentName(this, PickupWidget::class.java), null, null))
                        } else result.success(false)
                    }
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "openOfficial" -> result.success(OfficialApps.open(this, call.argument<String>("id") ?: ""))
                    "scheduleReminders" -> {
                        ReminderReceiver.configure(this, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("platform", error.message ?: "系统操作失败", null)
            }
        }
    }

    private fun granted(permission: String) = checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    private fun notificationsEnabled(): Boolean =
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || granted(Manifest.permission.POST_NOTIFICATIONS))

    private fun permissionState(): Map<String, Any> = mapOf(
        "platform" to "android",
        "readSms" to granted(Manifest.permission.READ_SMS),
        "receiveSms" to granted(Manifest.permission.RECEIVE_SMS),
        "notifications" to notificationsEnabled(),
        "camera" to granted(Manifest.permission.CAMERA),
        "batteryOptimized" to !(getSystemService(POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(packageName),
        "widgetSupported" to true,
        "widgetStatus" to "支持桌面添加与尺寸调整",
        "availableApps" to OfficialApps.available(this)
    )

    private fun requestPermissionSet(kind: String, permissions: Array<String>, result: MethodChannel.Result) {
        if (permissionResult != null) {
            result.error("permission_busy", "请先完成当前权限请求", null)
            return
        }
        if (permissions.all { granted(it) }) { result.success(kind != "notifications" || notificationsEnabled()); return }
        permissionResult = result
        permissionKind = kind
        requestPermissions(permissions, 4101)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4101) return
        val allowed = when (permissionKind) {
            "sms" -> granted(Manifest.permission.READ_SMS) && granted(Manifest.permission.RECEIVE_SMS)
            "notifications" -> notificationsEnabled()
            else -> false
        }
        permissionResult?.success(allowed)
        permissionResult = null
        permissionKind = null
    }

    private fun importSms(sinceMs: Long): Map<String, Int> {
        var added = 0; var duplicates = 0; var unrecognized = 0
        ParcelStore(this).use { store ->
            contentResolver.query(Telephony.Sms.Inbox.CONTENT_URI, arrayOf("address", "date", "date_sent", "body"), "date >= ?", arrayOf(sinceMs.toString()), "date ASC")?.use { cursor ->
                while (cursor.moveToNext()) {
                    val receivedAt = cursor.getLong(1)
                    val sourceDate = cursor.getLong(2).takeIf { it > 0 } ?: receivedAt
                    when (store.insertSms(cursor.getString(0).orEmpty(), sourceDate, cursor.getString(3).orEmpty(), receivedAt)) {
                        1 -> added++
                        0 -> duplicates++
                        else -> unrecognized++
                    }
                }
            } ?: throw IllegalStateException("系统未提供短信列表")
        }
        PickupWidget.refreshAll(this)
        return mapOf("added" to added, "duplicates" to duplicates, "unrecognized" to unrecognized)
    }

    private fun stageShare(shared: Intent) {
        executor.execute {
            try {
                SharedImports.stage(this, shared)
                sharedIntentStaged = true
                sharedImportError = null
            } catch (error: Exception) {
                sharedImportError = "无法读取分享内容，请重新分享，或使用粘贴和截图添加。"
            }
            runOnUiThread { platformChannel?.invokeMethod("recordsChanged", null) }
        }
    }

    companion object {
        const val ACTION_RECORDS_CHANGED = "io.github.oneperson9804.easypickup.RECORDS_CHANGED"
    }
}
