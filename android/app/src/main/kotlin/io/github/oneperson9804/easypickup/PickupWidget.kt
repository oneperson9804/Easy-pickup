package io.github.oneperson9804.easypickup

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.util.concurrent.Executors

class PickupWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_COLLECT) return
        val id = intent.getStringExtra("parcelId") ?: return
        val pending = goAsync()
        executor.execute {
            try {
                ParcelStore(context.applicationContext).use { it.collect(id) }
                refreshAll(context)
                context.sendBroadcast(Intent(MainActivity.ACTION_RECORDS_CHANGED).setPackage(context.packageName))
            } catch (error: Exception) {
                Log.e("EasyPickup", "Widget update failed: ${error.javaClass.simpleName}")
            } finally { pending.finish() }
        }
    }

    companion object {
        private const val ACTION_COLLECT = "io.github.oneperson9804.easypickup.WIDGET_COLLECT"
        private val executor = Executors.newSingleThreadExecutor()

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, PickupWidget::class.java)).forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.pickup_widget)
            val open = PendingIntent.getActivity(context, id, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_header, open)
            views.setOnClickPendingIntent(R.id.widget_empty, open)
            try {
                ParcelStore(context.applicationContext).use { store ->
                    val style = store.setting("widgetStyle") as? String ?: "jade"
                    val showCodes = store.setting("widgetShowCodes") as? Boolean ?: true
                    val dark = style != "ivory"
                    val foreground = Color.parseColor(if (dark) "#F5F8F2" else "#173D32")
                    val secondary = Color.parseColor(if (dark) "#B9CDC1" else "#60766A")
                    views.setInt(R.id.widget_root, "setBackgroundResource", if (dark) R.drawable.widget_jade else R.drawable.widget_ivory)
                    views.setTextColor(R.id.widget_title, foreground)
                    views.setTextColor(R.id.widget_count, Color.parseColor(if (dark) "#E2C683" else "#176B59"))
                    views.setTextColor(R.id.widget_empty, secondary)
                    views.setTextColor(R.id.widget_footer, secondary)
                    val (count, items) = store.pending()
                    val options = manager.getAppWidgetOptions(id)
                    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 120)
                    val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 240)
                    val capacity = ((height - 85) / 57).coerceIn(0, 12)
                    views.setTextViewText(R.id.widget_title, "易取件")
                    views.setTextViewText(R.id.widget_count, "$count 件待取")
                    views.removeAllViews(R.id.widget_rows)
                    views.setViewVisibility(R.id.widget_rows, if (capacity > 0 && count > 0) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.widget_empty, if (capacity == 0 || count == 0) View.VISIBLE else View.GONE)
                    views.setTextViewText(R.id.widget_empty, if (count == 0) "都取好了，轻装出发" else "打开查看待取件 · 拉高组件显示清单")
                    for (item in items.take(capacity)) {
                        val row = RemoteViews(context.packageName, R.layout.pickup_widget_row)
                        row.setTextViewText(R.id.widget_station, item.station)
                        row.setTextViewText(R.id.widget_code, if (showCodes) item.code else "取件码已隐藏")
                        row.setTextColor(R.id.widget_station, secondary)
                        row.setTextColor(R.id.widget_code, foreground)
                        row.setFloat(R.id.widget_code, "setTextSize", if (width < 190) 16f else 20f)
                        row.setOnClickPendingIntent(R.id.widget_row_info, open)
                        val action = Intent(context, PickupWidget::class.java).apply {
                            this.action = ACTION_COLLECT
                            data = Uri.parse("easypickup://widget/collect/${item.id}")
                            putExtra("parcelId", item.id)
                        }
                        row.setOnClickPendingIntent(R.id.widget_collect, PendingIntent.getBroadcast(context, 0, action, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                        views.addView(R.id.widget_rows, row)
                    }
                    views.setTextViewText(R.id.widget_footer, if (count > capacity && capacity > 0) "还有 ${count - capacity} 件 · 点标题查看全部" else "标记已取仅更新本机记录")
                }
            } catch (error: Exception) {
                views.removeAllViews(R.id.widget_rows)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty, "暂时无法读取记录，请打开易取件")
                Log.e("EasyPickup", "Widget read failed: ${error.javaClass.simpleName}")
            }
            manager.updateAppWidget(id, views)
        }
    }
}
