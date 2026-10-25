package io.github.oneperson9804.easypickup

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class PickupWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_ITEM && intent.action != ACTION_COLLECT) return
        if (intent.getStringExtra("operation") == "open") {
            context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return
        }
        val parcelId = intent.getStringExtra("parcelId") ?: return
        val pending = goAsync()
        executor.execute {
            try {
                ParcelStore(context.applicationContext).use { it.collect(parcelId) }
                refreshAll(context)
                context.sendBroadcast(Intent(MainActivity.ACTION_RECORDS_CHANGED).setPackage(context.packageName))
            } catch (error: Exception) {
                Log.e("EasyPickup", "Widget update failed: " + error.javaClass.simpleName)
            } finally { pending.finish() }
        }
    }

    companion object {
        private const val ACTION_COLLECT = "io.github.oneperson9804.easypickup.WIDGET_COLLECT"
        private const val ACTION_ITEM = "io.github.oneperson9804.easypickup.WIDGET_ITEM"
        private val executor = Executors.newSingleThreadExecutor()

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, PickupWidget::class.java)).forEach { update(context, manager, it) }
        }

        @Suppress("DEPRECATION")
        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.pickup_widget)
            val open = PendingIntent.getActivity(context, id, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_header, open)
            views.setOnClickPendingIntent(R.id.widget_empty, open)
            try {
                ParcelStore(context.applicationContext).use { store ->
                    val appearance = WidgetAppearance.read(store)
                    val options = manager.getAppWidgetOptions(id)
                    val portrait = context.resources.configuration.orientation != Configuration.ORIENTATION_LANDSCAPE
                    val widthKey = if (portrait) AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
                    val heightKey = if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
                    val width = options.getInt(widthKey, 260).coerceAtLeast(100)
                    val height = options.getInt(heightKey, 150).coerceAtLeast(60)
                    views.setImageViewBitmap(R.id.widget_glass, appearance.background(context, width, height))
                    views.setTextColor(R.id.widget_title, appearance.foreground)
                    views.setTextColor(R.id.widget_count, appearance.accent)
                    views.setTextColor(R.id.widget_empty, appearance.secondary)
                    val (count, items) = store.pending()
                    val compact = height < 118
                    views.setTextViewText(R.id.widget_title, "易取件")
                    views.setTextViewText(R.id.widget_count, count.toString() + " 件待取")
                    views.setViewVisibility(R.id.widget_rows, if (!compact && count > 0) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.widget_empty, if (compact || count == 0) View.VISIBLE else View.GONE)
                    views.setTextViewText(R.id.widget_empty, when {
                        count == 0 -> "都取好了，轻装出发"
                        else -> if (appearance.showCodes) items.first().code else items.first().station
                    })
                    val mutable = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
                    val click = PendingIntent.getBroadcast(context, id, Intent(context, PickupWidget::class.java).apply {
                        action = ACTION_ITEM
                        data = Uri.parse("easypickup://widget/items/" + id)
                    }, PendingIntent.FLAG_UPDATE_CURRENT or mutable)
                    views.setPendingIntentTemplate(R.id.widget_rows, click)
                    val adapter = Intent(context, PickupWidgetService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                        putExtra("width", width)
                        data = Uri.parse("easypickup://widget/list/" + id + "/" + width)
                    }
                    views.setRemoteAdapter(R.id.widget_rows, adapter)
                }
            } catch (error: Exception) {
                views.setViewVisibility(R.id.widget_rows, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty, "请打开易取件查看记录")
                Log.e("EasyPickup", "Widget read failed: " + error.javaClass.simpleName)
            }
            manager.updateAppWidget(id, views)
            manager.notifyAppWidgetViewDataChanged(id, R.id.widget_rows)
        }
    }
}

internal data class WidgetAppearance(val dark: Boolean, val showCodes: Boolean, val opacity: Double) {
    val foreground = Color.parseColor(if (dark) "#F7FCFD" else "#143A43")
    val secondary = Color.parseColor(if (dark) "#DEEDF0" else "#365861")
    val accent = Color.parseColor(if (dark) "#F4DB9C" else "#476C68")

    fun row(context: Context, item: WidgetParcel, width: Int): RemoteViews {
        return RemoteViews(context.packageName, R.layout.pickup_widget_row).apply {
            setTextViewText(R.id.widget_station, item.station)
            setTextViewText(R.id.widget_code, if (showCodes) item.code.ifEmpty { "待补充" } else "取件码已隐藏")
            setTextColor(R.id.widget_station, secondary)
            setTextColor(R.id.widget_code, foreground)
            setTextColor(R.id.widget_collect, accent)
            setInt(R.id.widget_collect, "setBackgroundResource", if (dark) R.drawable.widget_check_jade else R.drawable.widget_check_ivory)
            setContentDescription(R.id.widget_collect, "标记" + item.station + "的快递已取")
            setContentDescription(R.id.widget_row_info, item.station + if (showCodes) "，取件码" + item.code else "，取件码已隐藏")
            setOnClickFillInIntent(R.id.widget_row_info, Intent().putExtra("operation", "open"))
            setOnClickFillInIntent(R.id.widget_collect, Intent().putExtra("operation", "collect").putExtra("parcelId", item.id))
            if (width < 200) setInt(R.id.widget_station, "setMaxLines", 1)
        }
    }

    fun background(context: Context, width: Int, height: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val scale = minOf(density, 1024f / width, 2048f / height)
        val bitmap = Bitmap.createBitmap((width * scale).roundToInt().coerceAtLeast(1), (height * scale).roundToInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val bounds = RectF(.6f * scale, .6f * scale, bitmap.width - .6f * scale, bitmap.height - .6f * scale)
        val radius = 26f * scale
        val alpha = (opacity * 255).roundToInt()
        val colors = if (dark) intArrayOf(
            Color.argb((alpha + 24).coerceAtMost(255), 55, 119, 130),
            Color.argb(alpha, 21, 58, 70),
            Color.argb((alpha + 14).coerceAtMost(255), 12, 38, 50)
        ) else intArrayOf(
            Color.argb((alpha + 38).coerceAtMost(255), 248, 255, 255),
            Color.argb(alpha, 222, 240, 242),
            Color.argb((alpha + 24).coerceAtMost(255), 208, 229, 233)
        )
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.shader = LinearGradient(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat(), colors, floatArrayOf(0f, .55f, 1f), Shader.TileMode.CLAMP)
        canvas.drawRoundRect(bounds, radius, radius, paint)
        paint.shader = LinearGradient(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat(), intArrayOf(Color.argb(130, 215, 244, 245), Color.argb(35, 224, 207, 151), Color.argb(70, 128, 196, 205)), null, Shader.TileMode.CLAMP)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = scale
        canvas.drawRoundRect(bounds, radius, radius, paint)
        return bitmap
    }

    companion object {
        fun read(store: ParcelStore) = WidgetAppearance(
            dark = store.setting("widgetStyle") != "ivory",
            showCodes = store.setting("widgetShowCodes") as? Boolean ?: true,
            opacity = ((store.setting("widgetOpacity") as? Number)?.toDouble() ?: .42).coerceIn(.18, .9)
        )
    }
}
