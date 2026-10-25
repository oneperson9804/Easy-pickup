package io.github.oneperson9804.easypickup

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.WindowInsets
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.util.concurrent.Executors

/** Reads after a floating control is pressed; window events inspect metadata only. */
class PageCaptureAccessibilityService : AccessibilityService() {
    @Volatile var running = false
        private set
    private var foregroundPackage = ""
    private var overlay: View? = null
    private var captureBusy = false
    @Volatile private var sessionGeneration = 0
    private var windowGeneration = 0
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val manager by lazy { getSystemService(WINDOW_SERVICE) as WindowManager }
    private val overlayParams by lazy {
        WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.END; x = dp(8); y = dp(180) }
    }

    override fun onServiceConnected() { instance = this }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!running) { foregroundPackage = ""; hideOverlay(); return }
        // Our non-focusable toolbar must not replace the actual foreground platform.
        if (windows.any { it.id == event.windowId && it.type == AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY }) return
        windowGeneration++
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        foregroundPackage = packageName
        refreshOverlay()
    }

    override fun onInterrupt() { stopSession() }
    override fun onDestroy() {
        stopSession()
        if (instance === this) instance = null
        worker.shutdown()
        super.onDestroy()
    }

    fun startSession() {
        check(PageCaptureBridge.consented(this) && PageCaptureBridge.selected(this).isNotEmpty())
        sessionGeneration++
        running = true
        refreshOverlay()
    }

    fun stopSession() {
        sessionGeneration++
        running = false
        foregroundPackage = ""
        hideOverlay()
    }

    private fun allowed(packageName: String) = running && PageCaptureBridge.consented(this) &&
        packageName in PageCaptureBridge.selected(this)

    fun refreshOverlay() {
        if (allowed(foregroundPackage) && !captureBusy) showOverlay() else hideOverlay()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun showOverlay() {
        if (overlay != null) return
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6), dp(2), dp(6), dp(6))
            elevation = dp(5).toFloat()
            background = GradientDrawable().apply {
                setColor(Color.argb(238, 15, 58, 65)); cornerRadius = dp(18).toFloat()
                setStroke(dp(1), Color.argb(150, 199, 164, 91))
            }
        }
        val handle = TextView(this).apply {
            text = "易取件 · 拖动移动"
            setTextColor(Color.rgb(205, 231, 231)); textSize = 11f
            gravity = Gravity.CENTER; setPadding(dp(10), dp(6), dp(10), dp(6))
        }
        var startX = 0f; var startY = 0f; var originalX = 0; var originalY = 0
        handle.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = event.rawX; startY = event.rawY
                    originalX = overlayParams.x; originalY = overlayParams.y; true
                }
                MotionEvent.ACTION_MOVE -> {
                    val maxX = (resources.displayMetrics.widthPixels - container.width).coerceAtLeast(0)
                    val maxY = (resources.displayMetrics.heightPixels - container.height).coerceAtLeast(0)
                    overlayParams.x = (originalX - (event.rawX - startX)).toInt().coerceIn(0, maxX)
                    overlayParams.y = (originalY + (event.rawY - startY)).toInt().coerceIn(0, maxY)
                    overlay?.let { manager.updateViewLayout(it, overlayParams) }; true
                }
                else -> true
            }
        }
        container.addView(handle)
        val row = LinearLayout(this)
        fun action(label: String, listener: () -> Unit) {
            row.addView(Button(this).apply {
                text = label; textSize = 12f; isAllCaps = false
                minWidth = dp(56); minimumWidth = dp(56); minHeight = dp(48); minimumHeight = dp(48)
                setPadding(dp(8), 0, dp(8), 0)
                setTextColor(Color.rgb(229, 242, 240))
                backgroundTintList = android.content.res.ColorStateList.valueOf(Color.rgb(33, 83, 89))
                setOnClickListener { listener() }
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(48)))
        }
        action("读取本页") { readVisibleText() }
        if (Build.VERSION.SDK_INT >= 30) action("截图") { captureScreenshot() }
        action("结束") { stopSession(); toast("页面识别已结束") }
        container.addView(row)
        try {
            manager.addView(container, overlayParams)
            overlay = container
        } catch (_: WindowManager.BadTokenException) { stopSession(); toast("系统暂时无法显示识别按钮，请重新开始") }
        catch (_: SecurityException) { stopSession(); toast("请在系统辅助功能中开启页面识别") }
    }

    private fun hideOverlay() {
        val view = overlay ?: return
        overlay = null
        manager.removeView(view)
    }

    private fun readVisibleText() {
        if (captureBusy || !allowed(foregroundPackage)) return
        val root = rootInActiveWindow ?: run { toast("页面暂时无法读取，可使用截图"); return }
        try {
            val target = root.packageName?.toString().orEmpty()
            if (!allowed(target) || target != foregroundPackage) {
                toast("请在选定平台的取件页面读取"); return
            }
            val lines = linkedSetOf<String>()
            val queue = java.util.ArrayDeque<AccessibilityNodeInfo>()
            queue.add(root)
            var visited = 0
            var characters = 0
            val screen = Rect(0, 0, resources.displayMetrics.widthPixels, resources.displayMetrics.heightPixels)
            // Bounds prevent malformed/very large accessibility trees from blocking the service.
            while (queue.isNotEmpty() && visited++ < 4000 && characters < 100000) {
                val node = queue.removeFirst()
                try {
                    if (!node.isVisibleToUser || node.isPassword || node.isEditable) continue
                    val bounds = Rect(); node.getBoundsInScreen(bounds)
                    if (!Rect.intersects(screen, bounds)) continue
                    val nodePackage = node.packageName?.toString()
                    if (nodePackage != null && nodePackage != target) continue
                    for (value in listOf(node.text, node.contentDescription)) {
                        val text = value?.toString()?.trim().orEmpty()
                        if (text.isNotEmpty() && lines.add(text)) characters += text.length
                    }
                    for (index in 0 until node.childCount) node.getChild(index)?.let { queue.add(it) }
                } finally { if (node !== root) recycle(node) }
            }
            while (queue.isNotEmpty()) recycle(queue.removeFirst())
            val text = lines.joinToString("\n")
            if (text.isBlank()) {
                toast(if (Build.VERSION.SDK_INT >= 30) "本页没有可读文字，可点击截图识别" else "本页没有可读文字，可使用系统截图后导入")
                return
            }
            stageCapture { SharedImports.stageText(this, text) }
        } finally { recycle(root) }
    }

    private fun captureScreenshot() {
        if (Build.VERSION.SDK_INT < 30 || captureBusy || !allowed(foregroundPackage)) return
        val target = foregroundPackage
        val generation = sessionGeneration
        captureBusy = true
        hideOverlay()
        handler.postDelayed({
            if (generation != sessionGeneration || !allowed(target) || foregroundPackage != target) {
                captureBusy = false; refreshOverlay(); return@postDelayed
            }
            val captureTarget = activeCaptureTarget()
            if (captureTarget?.packageName != target) {
                captureBusy = false; refreshOverlay(); toast("页面已切换，请回到取件页重试"); return@postDelayed
            }
            val modeError = screenshotModeError(captureTarget)
            if (modeError != null) {
                captureBusy = false; refreshOverlay(); toast(modeError); return@postDelayed
            }
            val capturedWindowGeneration = windowGeneration
            val callback = object : TakeScreenshotCallback {
                override fun onSuccess(screenshot: ScreenshotResult) {
                    val buffer = screenshot.hardwareBuffer
                    var bitmap: Bitmap? = null
                    try {
                        if (generation == sessionGeneration && allowed(target) && foregroundPackage == target &&
                            capturedWindowGeneration == windowGeneration && activeCaptureTarget() == captureTarget &&
                            screenshotModeError(captureTarget) == null) {
                            val hardware = Bitmap.wrapHardwareBuffer(buffer, screenshot.colorSpace)
                                ?: throw IllegalStateException("无法读取截图")
                            try { bitmap = hardware.copy(Bitmap.Config.ARGB_8888, false) }
                            finally { hardware.recycle() }
                        }
                    } catch (_: Exception) {
                        toast("截图读取失败，请使用系统截图后导入")
                    } finally { buffer.close() }
                    val copy = bitmap
                    if (copy == null) {
                        captureBusy = false; refreshOverlay()
                        if (generation == sessionGeneration && running) toast("页面发生变化，本次截图未保存，请在取件页重试")
                        return
                    }
                    stageCapture(generation, onDiscard = { copy.recycle() }) {
                        try { SharedImports.stageBitmap(this@PageCaptureAccessibilityService, copy) }
                        finally { copy.recycle() }
                    }
                }

                override fun onFailure(errorCode: Int) {
                    captureBusy = false; refreshOverlay()
                    toast(if (errorCode == ERROR_TAKE_SCREENSHOT_SECURE_WINDOW) "当前页面不允许截图，可使用页面文字或手动添加"
                        else "系统未能截图，请稍后重试或使用系统截图导入")
                }
            }
            try {
                if (Build.VERSION.SDK_INT >= 34) {
                    takeScreenshotOfWindow(captureTarget.windowId, mainExecutor, callback)
                } else {
                    takeScreenshot(Display.DEFAULT_DISPLAY, mainExecutor, callback)
                }
            } catch (_: SecurityException) {
                captureBusy = false; refreshOverlay(); toast("系统未允许截图，请检查辅助功能设置")
            } catch (_: IllegalStateException) {
                captureBusy = false; refreshOverlay(); toast("截图服务暂时不可用，请重新开始识别")
            }
        }, 180)
    }

    private data class CaptureTarget(val packageName: String, val windowId: Int)

    private fun activeCaptureTarget(): CaptureTarget? {
        val root = rootInActiveWindow ?: return null
        return try {
            val packageName = root.packageName?.toString().orEmpty()
            if (!allowed(packageName)) null else CaptureTarget(packageName, root.windowId)
        } finally { recycle(root) }
    }

    private fun screenshotModeError(target: CaptureTarget): String? {
        val visibleWindows = windows
        val window = visibleWindows.firstOrNull { it.id == target.windowId }
        if (window == null || window.type != AccessibilityWindowInfo.TYPE_APPLICATION) {
            return "取件窗口暂时不可用，请返回平台页面重试"
        }
        if (Build.VERSION.SDK_INT >= 34) return null
        // Before API 34, Android can only capture the display. Permit it only when
        // one application occupies the display, so another app never enters a draft.
        if (Build.VERSION.SDK_INT < 30) return "请使用系统截图后导入"
        if (window.displayId != Display.DEFAULT_DISPLAY) return "请使用系统截图选择取件页面后导入"
        val metrics = manager.maximumWindowMetrics
        val displayBounds = Rect(metrics.bounds)
        val insets = metrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
        val availableBounds = Rect(displayBounds).apply { inset(insets.left, insets.top, insets.right, insets.bottom) }
        val targetBounds = Rect().also { window.getBoundsInScreen(it) }
        if (!targetBounds.contains(availableBounds)) return "分屏或浮窗模式请使用系统截图选择取件页面后导入"
        if (visibleWindows.any { other ->
            other.id != target.windowId &&
                (other.type == AccessibilityWindowInfo.TYPE_APPLICATION || other.layer > window.layer) &&
                Rect.intersects(availableBounds, Rect().also { other.getBoundsInScreen(it) })
        }) return "有其他应用窗口可见，请使用系统截图选择取件页面后导入"
        if (visibleWindows.any { it.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD }) return "请收起键盘后截图，或使用系统截图选择取件页面后导入"
        return null
    }

    private fun stageCapture(generation: Int = sessionGeneration, onDiscard: () -> Unit = {}, write: () -> Unit) {
        captureBusy = true
        hideOverlay()
        worker.execute {
            try {
                if (generation != sessionGeneration || !running || !PageCaptureBridge.consented(this)) {
                    onDiscard(); return@execute
                }
                write()
                handler.post {
                    captureBusy = false
                    sendBroadcast(Intent(MainActivity.ACTION_RECORDS_CHANGED).setPackage(packageName))
                    if (generation == sessionGeneration && running) {
                        foregroundPackage = ""
                        val launch = Intent(this, MainActivity::class.java)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        try { startActivity(launch) }
                        catch (_: android.content.ActivityNotFoundException) { toast("内容已暂存，请打开易取件查看") }
                        catch (_: SecurityException) { toast("内容已暂存，请打开易取件查看") }
                    }
                }
            } catch (_: Exception) {
                handler.post { captureBusy = false; refreshOverlay(); toast("内容暂存失败，请重试") }
            } finally {
                handler.post { captureBusy = false; refreshOverlay() }
            }
        }
    }

    private fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    @Suppress("DEPRECATION") private fun recycle(node: AccessibilityNodeInfo) { node.recycle() }

    companion object { @Volatile var instance: PageCaptureAccessibilityService? = null; private set }
}
