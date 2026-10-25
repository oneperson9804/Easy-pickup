package io.github.oneperson9804.easypickup

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.FlutterInjector
import org.json.JSONObject

object OfficialApps {
    private data class AppRoute(val packageName: String, val uri: String)
    private data class Destination(val id: String, val apps: List<AppRoute>)

    private fun destinations(context: Context): List<Destination> {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/platforms.json")
        val json = context.assets.open(key).bufferedReader().use { JSONObject(it.readText()) }
        val entries = json.getJSONArray("destinations")
        return (0 until entries.length()).map { index ->
            val item = entries.getJSONObject(index)
            val apps = item.getJSONArray("apps")
            Destination(item.getString("id"), (0 until apps.length()).map { routeIndex ->
                val route = apps.getJSONObject(routeIndex)
                AppRoute(route.getString("package"), route.getString("uri"))
            })
        }
    }

    fun available(context: Context): List<String> = destinations(context).filter { destination ->
        destination.apps.any { route ->
            try {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(route.packageName, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }.map { it.id }

    fun open(context: Context, id: String): Map<String, String> {
        val destination = destinations(context).firstOrNull { it.id == id }
            ?: throw IllegalArgumentException("未知的官方入口")
        var reason = "route_unavailable"
        for (route in destination.apps) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(route.uri))
                .setPackage(route.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
                return mapOf("id" to id, "status" to "app")
            } catch (_: ActivityNotFoundException) {
                // A package visibility query cannot determine whether a URI may be opened.
            } catch (_: SecurityException) {
                reason = "access_denied"
            }
        }
        return mapOf("id" to id, "status" to "unavailable", "reason" to reason)
    }
}
