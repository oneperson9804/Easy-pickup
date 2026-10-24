package io.github.oneperson9804.easypickup

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import org.json.JSONArray
import org.json.JSONTokener
import java.util.UUID

data class ParsedSms(val station: String, val code: String, val company: String)
data class WidgetParcel(val id: String, val station: String, val code: String)

class ParcelStore(context: Context) : SQLiteOpenHelper(context, "easy_pickup.db", null, 1) {
    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.enableWriteAheadLogging()
        db.rawQuery("PRAGMA busy_timeout=5000", null).use { it.moveToFirst() }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS parcels(id TEXT PRIMARY KEY,station TEXT NOT NULL,code TEXT NOT NULL,detail_address TEXT NOT NULL DEFAULT '',company TEXT NOT NULL DEFAULT '',raw_text TEXT NOT NULL DEFAULT '',arrived_at INTEGER NOT NULL,collected_at INTEGER,deleted_at INTEGER,source TEXT NOT NULL DEFAULT 'manual',source_key TEXT UNIQUE)")
        db.execSQL("CREATE INDEX IF NOT EXISTS parcels_state ON parcels(deleted_at,collected_at,arrived_at)")
        db.execSQL("CREATE TABLE IF NOT EXISTS saved_codes(id TEXT PRIMARY KEY,label TEXT NOT NULL,value TEXT NOT NULL,format TEXT NOT NULL DEFAULT 'qr',created_at INTEGER NOT NULL)")
        db.execSQL("CREATE TABLE IF NOT EXISTS rules(id TEXT PRIMARY KEY,kind TEXT NOT NULL,pattern TEXT NOT NULL,replacement TEXT NOT NULL)")
        db.execSQL("CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        throw IllegalStateException("Unsupported database migration $oldVersion → $newVersion")
    }

    fun setting(key: String): Any? = readableDatabase.rawQuery(
        "SELECT value FROM settings WHERE key=?", arrayOf(key)
    ).use { cursor ->
        if (cursor.moveToFirst()) JSONTokener(cursor.getString(0)).nextValue() else null
    }

    fun putSetting(key: String, value: Any) {
        val encoded = when (value) {
            is String -> org.json.JSONObject.quote(value)
            is Collection<*> -> JSONArray(value).toString()
            else -> value.toString()
        }
        writableDatabase.insertWithOnConflict("settings", null, ContentValues().apply {
            put("key", key); put("value", encoded)
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun parseSms(body: String): ParsedSms? {
        val parsed = SmsParser.parse(body) ?: return null
        var station = parsed.station
        var company = parsed.company
        readableDatabase.rawQuery("SELECT kind,pattern,replacement FROM rules ORDER BY rowid", null).use { rows ->
            while (rows.moveToNext()) {
                val pattern = rows.getString(1)
                if (pattern.isNotEmpty() && body.replace("\u200b", "").replace('：', ':').contains(pattern)) {
                    when (rows.getString(0)) {
                        "address", "station" -> station = rows.getString(2)
                        "company" -> company = rows.getString(2)
                    }
                }
            }
        }
        return parsed.copy(station = station, company = company)
    }

    /** 1 = added, 0 = duplicate, -1 = not a pickup message. */
    fun insertSms(address: String, sourceDate: Long, body: String, receivedAt: Long = sourceDate): Int {
        val parsed = parseSms(body) ?: return -1
        val sourceKey = "sms:$address:$sourceDate:$body"
        // Legacy exports lack the SMS sender. Link only one unambiguous migrated
        // record, preserving its edited location and collected timestamp.
        val migrated = readableDatabase.rawQuery(
            "SELECT id FROM parcels WHERE source_key LIKE 'legacy:%' AND raw_text=? AND ABS(arrived_at - ?) <= 60000 LIMIT 2",
            arrayOf(body, receivedAt.toString())
        ).use { rows ->
            if (rows.count == 1 && rows.moveToFirst()) rows.getString(0) else null
        }
        if (migrated != null) {
            val linked = ContentValues().apply { put("source_key", sourceKey) }
            writableDatabase.updateWithOnConflict("parcels", linked, "id=?", arrayOf(migrated), SQLiteDatabase.CONFLICT_IGNORE)
            return 0
        }
        val values = ContentValues().apply {
            put("id", UUID.randomUUID().toString())
            put("station", parsed.station)
            put("code", parsed.code)
            put("company", parsed.company)
            put("raw_text", body)
            put("arrived_at", receivedAt)
            put("source", "sms")
            put("source_key", sourceKey)
        }
        return if (writableDatabase.insertWithOnConflict("parcels", null, values, SQLiteDatabase.CONFLICT_IGNORE) == -1L) 0 else 1
    }

    fun pending(limit: Int = 12): Pair<Int, List<WidgetParcel>> {
        val db = readableDatabase
        val count = db.rawQuery("SELECT COUNT(*) FROM parcels WHERE deleted_at IS NULL AND collected_at IS NULL", null).use {
            it.moveToFirst(); it.getInt(0)
        }
        val items = mutableListOf<WidgetParcel>()
        db.rawQuery("SELECT id,station,code FROM parcels WHERE deleted_at IS NULL AND collected_at IS NULL ORDER BY arrived_at DESC LIMIT ?", arrayOf(limit.toString())).use {
            while (it.moveToNext()) items.add(WidgetParcel(it.getString(0), it.getString(1), it.getString(2)))
        }
        return count to items
    }

    fun collect(id: String) {
        writableDatabase.execSQL("UPDATE parcels SET collected_at=? WHERE id=? AND deleted_at IS NULL AND collected_at IS NULL", arrayOf<Any>(System.currentTimeMillis(), id))
    }
}

object SmsParser {
    // These patterns intentionally mirror lib/core/parser.dart; both use the same SMS fixtures.
    private val codePattern = Regex("(?:取件|提货|取货|领件|出库|提取)码\\s*[:为是]?\\s*([A-Za-z0-9][A-Za-z0-9\\-－— ]{1,24})", RegexOption.IGNORE_CASE)
    private val stationPattern = Regex("(?:已到达?|已放至?|送至|存放[于在]?|请到|已入库[至到]?|在)\\s*([^，。；;！!\\n]{2,60}?(?:菜鸟驿站|驿站|快递柜|丰巢|菜鸟柜|自提柜|服务站|代收点|快递站|超市|便利店|门卫室|门卫|收发室))")
    private val namedStation = Regex("([^，。；;！!\\n:]{1,32}(?:驿站|快递柜|丰巢|自提柜|代收点|超市|便利店|门卫室|收发室))")
    private val companies = listOf("中通", "圆通", "申通", "韵达", "顺丰", "极兔", "邮政", "EMS", "京东", "德邦", "菜鸟", "百世", "丰网")

    fun parse(body: String): ParsedSms? {
        val cleaned = body.replace("\u200b", "").replace('：', ':').trim()
        val match = codePattern.find(cleaned) ?: return null
        val code = match.groupValues[1].trim().replace('－', '-').replace('—', '-')
        if (!code.any { it.isDigit() }) return null
        val station = (stationPattern.find(cleaned)?.groupValues?.get(1)
            ?: namedStation.find(cleaned)?.groupValues?.get(1) ?: "待确认站点").trim()
        val companyText = Regex("【([^】]{1,20})】").find(cleaned)?.groupValues?.get(1) ?: cleaned
        val company = companies.firstOrNull { companyText.contains(it) } ?: ""
        return ParsedSms(station, code, company)
    }
}
