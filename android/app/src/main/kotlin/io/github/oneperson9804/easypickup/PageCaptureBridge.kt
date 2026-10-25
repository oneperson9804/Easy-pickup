package io.github.oneperson9804.easypickup

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Settings persist; a reading session exists only while the service is alive. */
object PageCaptureBridge {
    internal val platforms = linkedMapOf(
        "com.cainiao.wireless" to "菜鸟",
        "com.taobao.taobao" to "淘宝",
        "com.xunmeng.pinduoduo" to "拼多多",
        "com.jingdong.app.mall" to "京东",
        "com.ss.android.ugc.aweme" to "抖音",
        "com.ss.android.ugc.aweme.mobile" to "抖音海外渠道",
        "com.xingin.xhs" to "小红书",
    )

    private fun preferences(context: Context) = context.getSharedPreferences("page-capture", Context.MODE_PRIVATE)
    internal fun consented(context: Context) = preferences(context).getBoolean("consented", false)
    internal fun selected(context: Context): Set<String> =
        preferences(context).getStringSet("selected", emptySet()).orEmpty().intersect(platforms.keys)

    private fun state(context: Context): Map<String, Any> {
        val component = ComponentName(context, PageCaptureAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            .orEmpty().split(':').any { ComponentName.unflattenFromString(it) == component }
        return mapOf(
            "enabled" to enabled,
            "connected" to (PageCaptureAccessibilityService.instance != null),
            "consented" to consented(context),
            "running" to (PageCaptureAccessibilityService.instance?.running == true),
            "screenshotSupported" to (Build.VERSION.SDK_INT >= 30),
            "selectedPackages" to selected(context).toList(),
            "platforms" to platforms,
        )
    }

    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "easy_pickup/page_capture").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "state" -> result.success(state(activity))
                    "configure" -> {
                        val consent = call.argument<Boolean>("consented") == true
                        val packages = call.argument<List<String>>("selectedPackages").orEmpty().toSet()
                        require(platforms.keys.containsAll(packages)) { "请选择支持的平台" }
                        preferences(activity).edit().putBoolean("consented", consent)
                            .putStringSet("selected", packages).apply()
                        PageCaptureAccessibilityService.instance?.stopSession()
                        result.success(state(activity))
                    }
                    "openSettings" -> {
                        check(consented(activity)) { "请先阅读并同意页面识别说明" }
                        activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "startSession" -> {
                        check(consented(activity)) { "请先阅读并同意页面识别说明" }
                        check(selected(activity).isNotEmpty()) { "请至少选择一个平台" }
                        val service = PageCaptureAccessibilityService.instance
                            ?: throw IllegalStateException("请先在系统辅助功能中开启易取件页面识别，返回后重试")
                        service.startSession()
                        result.success(state(activity))
                    }
                    "stopSession" -> {
                        PageCaptureAccessibilityService.instance?.stopSession()
                        result.success(state(activity))
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("page_capture", error.message ?: "页面识别操作失败", null)
            }
        }
    }
}
