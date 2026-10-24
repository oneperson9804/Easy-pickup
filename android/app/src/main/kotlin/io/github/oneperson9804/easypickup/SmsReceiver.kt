package io.github.oneperson9804.easypickup

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import java.util.concurrent.Executors

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return
        val address = messages[0].originatingAddress.orEmpty()
        val date = messages[0].timestampMillis
        val body = messages.joinToString("") { it.messageBody.orEmpty() }
        val pending = goAsync()
        executor.execute {
            try {
                val changed = ParcelStore(context.applicationContext).use { store ->
                    store.insertSms(address, date, body, System.currentTimeMillis()) == 1
                }
                if (changed) {
                    PickupWidget.refreshAll(context)
                    context.sendBroadcast(Intent(MainActivity.ACTION_RECORDS_CHANGED).setPackage(context.packageName))
                }
            } catch (error: Exception) {
                // Only failure category is logged; private SMS content never enters logs.
                Log.e("EasyPickup", "SMS import failed: ${error.javaClass.simpleName}")
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private val executor = Executors.newSingleThreadExecutor()
    }
}
