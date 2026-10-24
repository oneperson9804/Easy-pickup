package com.sidutech.express.migration;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.os.Bundle;
import android.graphics.Color;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONObject;

/** One-time exporter running inside the old application's sandbox. */
public final class ExportActivity extends Activity {
    private static final int CREATE_BACKUP = 1057;
    private TextView status;
    private Button exportButton;
    private String pendingBackupName;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        pendingBackupName = state == null ? null : state.getString("pending_backup_name");
        getWindow().setStatusBarColor(Color.rgb(20, 125, 136));
        ScrollView scroll = new ScrollView(this);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        int padding = (int) (24 * getResources().getDisplayMetrics().density);
        layout.setPadding(padding, padding, padding, padding);
        layout.setBackgroundColor(Color.rgb(244, 247, 241));
        scroll.addView(layout);
        TextView title = new TextView(this);
        title.setText("迁移到易取件");
        title.setTextSize(27);
        title.setTextColor(Color.rgb(20, 125, 136));
        layout.addView(title);
        TextView explanation = new TextView(this);
        explanation.setText("此工具只读取旧版的取件记录、站点顺序和识别规则，保存为易取件备份文件。\n\n"
                + "1. 点击下方按钮，在系统文件界面保存 JSON 文件。\n"
                + "2. 打开易取件，在设置中的备份与恢复导入该文件。\n"
                + "3. 核对待取、已取和站点后，再决定是否卸载旧版。\n\n"
                + "备份包含取件记录、详细位置、原始通知、识别规则和排列设置。请选择保存位置并妥善保管文件。");
        explanation.setTextSize(16);
        explanation.setTextColor(Color.rgb(23, 45, 40));
        explanation.setPadding(0, padding, 0, padding);
        layout.addView(explanation);
        exportButton = new Button(this);
        exportButton.setText("导出旧版数据");
        exportButton.setTextColor(Color.WHITE);
        exportButton.setBackgroundTintList(android.content.res.ColorStateList.valueOf(Color.rgb(23, 107, 89)));
        layout.addView(exportButton);
        status = new TextView(this);
        status.setText("导出完成后，旧版仍可照常使用。");
        status.setTextSize(15);
        status.setPadding(0, padding, 0, 0);
        layout.addView(status);
        setContentView(scroll);
        exportButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View view) { prepareBackup(); }
        });
    }

    @Override protected void onSaveInstanceState(Bundle state) {
        super.onSaveInstanceState(state);
        if (pendingBackupName != null) state.putString("pending_backup_name", pendingBackupName);
    }

    private File pendingFile() throws IOException {
        if (pendingBackupName == null) throw new IOException("导出准备信息已失效，请重新导出");
        return new File(getCacheDir(), pendingBackupName);
    }

    private void prepareBackup() {
        exportButton.setEnabled(false);
        status.setText("正在读取旧版数据…");
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                    JSONObject snapshot = readSnapshot();
                    byte[] data = snapshot.toString(2).getBytes(StandardCharsets.UTF_8);
                    final File preparedFile = new File(getCacheDir(), "easy-pickup-migration-" + UUID.randomUUID() + ".json");
                    try (FileOutputStream output = new FileOutputStream(preparedFile)) { output.write(data); }
                    final int count = snapshot.getJSONArray("parcels").length();
                    final int warnings = snapshot.getJSONObject("legacyMigration").getJSONArray("warnings").length();
                    runOnUiThread(new Runnable() {
                        @Override public void run() {
                            if (isFinishing() || isDestroyed()) return;
                            pendingBackupName = preparedFile.getName();
                            status.setText("已准备 " + count + " 条记录，请选择保存位置。"
                                    + (warnings == 0 ? "" : "旧版缺失信息已原样保留，详情见备份的 legacyMigration.warnings。"));
                            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                            intent.addCategory(Intent.CATEGORY_OPENABLE);
                            intent.setType("application/json");
                            intent.putExtra(Intent.EXTRA_TITLE, "easy-pickup-migration-"
                                    + new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(new Date()) + ".json");
                            try { startActivityForResult(intent, CREATE_BACKUP); }
                            catch (RuntimeException error) { showFailure("无法打开系统文件选择器：", error); }
                        }
                    });
                } catch (final Exception error) { showFailure("准备导出失败：", error); }
            }
        }, "easy-pickup-export-prepare").start();
    }

    @Override protected void onActivityResult(int request, int result, Intent intent) {
        super.onActivityResult(request, result, intent);
        if (request != CREATE_BACKUP) return;
        if (result != RESULT_OK || intent == null || intent.getData() == null) {
            exportButton.setEnabled(true);
            status.setText("已取消保存，旧数据保持不变。");
            return;
        }
        final Uri destination = intent.getData();
        status.setText("正在保存备份…");
        new Thread(new Runnable() {
            @Override public void run() {
                try (FileInputStream input = new FileInputStream(pendingFile());
                        OutputStream output = getContentResolver().openOutputStream(destination, "wt")) {
                    if (output == null) throw new IOException("无法打开所选文件");
                    byte[] buffer = new byte[16384];
                    int count;
                    while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                    output.flush();
                } catch (final Exception error) { showFailure("保存失败：", error); return; }
                runOnUiThread(new Runnable() {
                    @Override public void run() {
                        if (isFinishing() || isDestroyed()) return;
                        exportButton.setEnabled(true);
                        status.setText("备份已保存。请到易取件的设置 → 备份与恢复中导入，并核对记录。旧版数据保持不变。");
                    }
                });
            }
        }, "easy-pickup-export-save").start();
    }

    private void showFailure(final String prefix, final Exception error) {
        runOnUiThread(new Runnable() {
            @Override public void run() {
                if (isFinishing() || isDestroyed()) return;
                exportButton.setEnabled(true);
                String detail = error.getMessage();
                status.setText(prefix + (detail == null ? error.getClass().getSimpleName() : detail)
                        + "。旧数据未被修改，可重新尝试。");
            }
        });
    }

    private JSONObject readSnapshot() throws Exception {
        File databaseFile = getDatabasePath("express.db");
        if (!databaseFile.isFile()) throw new IOException("尚未找到旧版记录库，请确认在保留数据的旧版上安装了迁移包");
        String installation;
        synchronized (ExportActivity.class) {
            SharedPreferences migration = getSharedPreferences("easy_pickup_migration", MODE_PRIVATE);
            installation = migration.getString("installation_id", null);
            if (installation == null) {
                installation = UUID.randomUUID().toString();
                if (!migration.edit().putString("installation_id", installation).commit()) {
                    throw new IOException("无法保存迁移标识，请检查剩余存储空间");
                }
            }
        }
        final long exportTime = System.currentTimeMillis();
        JSONArray parcels = new JSONArray();
        JSONArray warnings = new JSONArray();
        JSONArray originalDetails = new JSONArray();
        try (SQLiteDatabase database = SQLiteDatabase.openDatabase(databaseFile.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY);
                Cursor cursor = database.rawQuery("SELECT _id,address,pickup_code,company,message,date,received,received_date,deleted,detail_address FROM express_items ORDER BY _id", null)) {
            while (cursor.moveToNext()) {
                long oldId = cursor.getLong(0);
                String id = "legacy:" + installation + ":" + oldId;
                long arrived = cursor.getLong(5);
                boolean collected = cursor.getInt(6) != 0;
                long collectedAt = cursor.getLong(7);
                boolean deleted = cursor.getInt(8) != 0;
                JSONObject record = new JSONObject();
                record.put("id", id);
                String station = text(cursor, 1);
                record.put("station", station.trim().isEmpty() ? "待确认站点" : station);
                record.put("code", text(cursor, 2));
                record.put("company", text(cursor, 3));
                record.put("raw_text", text(cursor, 4));
                record.put("detail_address", text(cursor, 9));
                record.put("arrived_at", arrived);
                record.put("collected_at", collected ? Long.valueOf(collectedAt) : JSONObject.NULL);
                record.put("deleted_at", deleted ? Long.valueOf(exportTime) : JSONObject.NULL);
                record.put("source", "backup");
                record.put("source_key", id);
                parcels.put(record);
                JSONObject detail = new JSONObject();
                detail.put("id", id);
                detail.put("old_id", oldId);
                detail.put("address", station);
                detail.put("detail_address", text(cursor, 9));
                originalDetails.put(detail);
                if (arrived <= 0) warnings.put(id + ": 原始到件时间缺失，保留原始值 " + arrived);
                if (collected && collectedAt <= 0) warnings.put(id + ": 原始已取时间缺失，保留原始值 " + collectedAt);
                if (text(cursor, 1).trim().isEmpty()) warnings.put(id + ": 原始站点为空，请导入后补充");
            }
        }
        JSONArray rules = new JSONArray();
        appendRules(rules, "address_rule_list", "address_rule_key", "address", installation);
        appendRules(rules, "company_rule_list", "company_rule_key", "company", installation);
        String orderText = getSharedPreferences("address_order", MODE_PRIVATE).getString("order_list", "[]");
        JSONArray order = new JSONArray(orderText == null ? "[]" : orderText);
        JSONArray stationOrder = new JSONArray();
        for (int index = 0; index < order.length(); index++) stationOrder.put(order.getString(index));
        int sort = getSharedPreferences("config", MODE_PRIVATE).getInt("pickup_code_sort_mode", 0);
        JSONObject settings = new JSONObject();
        settings.put("stationOrder", stationOrder);
        settings.put("sortMode", sort == 1 ? "codeAsc" : sort == 2 ? "codeDesc" : "arrival");
        JSONObject legacy = new JSONObject();
        legacy.put("sourcePackage", "com.sidutech.express");
        legacy.put("installationId", installation);
        legacy.put("warnings", warnings);
        legacy.put("originalDetails", originalDetails);
        legacy.put("deletedTimePolicy", "旧版只有删除标记，没有删除时间；deleted_at 使用导出时间表示原删除状态。");
        SimpleDateFormat iso = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT);
        iso.setTimeZone(TimeZone.getTimeZone("UTC"));
        JSONObject result = new JSONObject();
        result.put("format", "easy-pickup");
        result.put("schemaVersion", 1);
        result.put("exportedAt", iso.format(new Date(exportTime)));
        result.put("parcels", parcels);
        result.put("codes", new JSONArray());
        result.put("rules", rules);
        result.put("settings", settings);
        result.put("legacyMigration", legacy);
        return result;
    }

    private void appendRules(JSONArray destination, String preference, String key, String kind, String installation) throws Exception {
        Set<String> values = getSharedPreferences(preference, MODE_PRIVATE).getStringSet(key, Collections.<String>emptySet());
        List<String> ordered = new ArrayList<String>(values);
        Collections.sort(ordered);
        for (int index = 0; index < ordered.size(); index++) {
            String value = ordered.get(index);
            JSONObject rule = new JSONObject();
            String contentId = UUID.nameUUIDFromBytes((kind + ":" + value).getBytes(StandardCharsets.UTF_8)).toString();
            rule.put("id", "legacy-rule:" + installation + ":" + contentId);
            rule.put("kind", kind);
            rule.put("pattern", value);
            rule.put("replacement", value);
            destination.put(rule);
        }
    }

    private static String text(Cursor cursor, int index) { return cursor.isNull(index) ? "" : cursor.getString(index); }
}
