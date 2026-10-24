package io.github.oneperson9804.easypickup

import android.content.Context
import android.content.Intent
import android.net.Uri

object OfficialApps {
    data class Destination(val packageName: String, val uri: String)
    private const val TAOBAO_BASE = "taobao://m.taobao.com/tbopen/index.html?h5Url="
    private val destinations = mapOf(
        "cainiao_code" to Destination("com.cainiao.wireless", "cainiao://desktop/station_code"),
        "taobao_code" to Destination("com.taobao.taobao", TAOBAO_BASE + "https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code%3Fx-ssr%3Dtrue"),
        "pinduoduo_code" to Destination("com.xunmeng.pinduoduo", "pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE&entry_source=11"),
        "pinduoduo_pickup" to Destination("com.xunmeng.pinduoduo", "pinduoduo://com.xunmeng.pinduoduo/mdkd/package"),
        "jd_orders" to Destination("com.jingdong.app.mall", "openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22orderlist%22%7D"),
        "taobao_orders" to Destination("com.taobao.taobao", TAOBAO_BASE + "https%3A%2F%2Fh5.m.taobao.com%2Fawp%2Fbase%2Forder%2Flistul.htm")
    )

    fun available(context: Context): List<String> = destinations.filter { (_, dest) ->
        context.packageManager.resolveActivity(Intent(Intent.ACTION_VIEW, Uri.parse(dest.uri)).setPackage(dest.packageName), 0) != null
    }.keys.toList()

    fun open(context: Context, id: String): Boolean {
        val destination = destinations[id] ?: throw IllegalArgumentException("未知的官方入口")
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(destination.uri))
            .setPackage(destination.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (context.packageManager.resolveActivity(intent, 0) == null) return false
        context.startActivity(intent)
        return true
    }
}
