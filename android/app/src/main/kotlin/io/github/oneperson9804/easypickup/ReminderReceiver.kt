package io.github.oneperson9804.easypickup

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import org.json.JSONArray
import java.util.Calendar

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == ACTION_REMIND) {
                val allowed = Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                if (allowed) {
                    val count = ParcelStore(context).use { it.pending(0).first }
                    if (count > 0) {
                        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notifications.createNotificationChannel(NotificationChannel(CHANNEL_ID, "取件提醒", NotificationManager.IMPORTANCE_DEFAULT))
                        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        notifications.notify(61, Notification.Builder(context, CHANNEL_ID)
                            .setSmallIcon(R.drawable.ic_pickup_notification)
                            .setContentTitle("还有 $count 件快递等你")
                            .setContentText("顺路取件，轻装回家。点开易取件查看站点与取件码。")
                            .setContentIntent(open).setAutoCancel(true).build())
                    }
                }
            }
            reschedule(context)
            if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) PickupWidget.refreshAll(context)
        } catch (error: Exception) {
            Log.e("EasyPickup", "Reminder scheduling failed: ${error.javaClass.simpleName}")
        }
    }

    companion object {
        private const val CHANNEL_ID = "pickup_reminders"
        private const val ACTION_REMIND = "io.github.oneperson9804.easypickup.REMIND"

        fun configure(context: Context, arguments: Map<*, *>) {
            val enabled = arguments["enabled"] as? Boolean ?: false
            val hour = (arguments["hour"] as? Number)?.toInt() ?: 18
            val minute = (arguments["minute"] as? Number)?.toInt() ?: 0
            val weekdays = (arguments["weekdays"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: (1..7).toList()
            require(hour in 0..23 && minute in 0..59 && weekdays.all { it in 1..7 }) { "提醒时间不正确" }
            ParcelStore(context).use {
                it.putSetting("reminderEnabled", enabled)
                it.putSetting("reminderHour", hour)
                it.putSetting("reminderMinute", minute)
                it.putSetting("reminderWeekdays", weekdays)
            }
            reschedule(context)
        }

        fun reschedule(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            ParcelStore(context).use { store ->
                val enabled = store.setting("reminderEnabled") as? Boolean ?: false
                val hour = (store.setting("reminderHour") as? Number)?.toInt() ?: 18
                val minute = (store.setting("reminderMinute") as? Number)?.toInt() ?: 0
                val saved = store.setting("reminderWeekdays") as? JSONArray
                val days = if (saved == null) (1..7).toSet() else (0 until saved.length()).map { saved.getInt(it) }.toSet()
                for (weekday in 1..7) {
                    val pending = PendingIntent.getBroadcast(context, 610 + weekday, Intent(context, ReminderReceiver::class.java).setAction(ACTION_REMIND), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    alarm.cancel(pending)
                    if (!enabled || weekday !in days) continue
                    val next = Calendar.getInstance().apply {
                        set(Calendar.DAY_OF_WEEK, if (weekday == 7) Calendar.SUNDAY else weekday + 1)
                        set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute)
                        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
                        if (timeInMillis <= System.currentTimeMillis()) add(Calendar.WEEK_OF_YEAR, 1)
                    }
                    // Inexact reminders avoid a special exact-alarm permission and follow system battery scheduling.
                    alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending)
                }
            }
        }
    }
}
