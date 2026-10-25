package io.github.oneperson9804.easypickup

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView

class WidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(28), dp(48), dp(28), dp(24))
            setBackgroundColor(Color.parseColor("#F1F7F7"))
        }
        layout.addView(TextView(this).apply { text = "把易取件放到桌面"; textSize = 25f; setTextColor(Color.parseColor("#173943")) })
        layout.addView(TextView(this).apply { text = "添加后长按组件，拖动边框调整大小。较大的组件会显示更多待取件。"; textSize = 15f; setPadding(0, dp(16), 0, dp(20)) })
        val group = RadioGroup(this)
        val jade = RadioButton(this).apply { text = "灵青玻璃"; this.id = 101 }
        val ivory = RadioButton(this).apply { text = "雾白玻璃"; this.id = 102 }
        group.addView(jade); group.addView(ivory)
        val privacy = Switch(this).apply { text = "在桌面显示取件码"; setPadding(0, dp(20), 0, dp(20)) }
        val opacityLabel = TextView(this).apply { textSize = 14f; setPadding(0, dp(20), 0, 0) }
        val opacity = SeekBar(this).apply { max = 72; contentDescription = "小组件背景浓度" }
        ParcelStore(this).use { store ->
            group.check(if (store.setting("widgetStyle") == "ivory") 102 else 101)
            privacy.isChecked = store.setting("widgetShowCodes") as? Boolean ?: true
            opacity.progress = (((store.setting("widgetOpacity") as? Number)?.toDouble() ?: .42) * 100).toInt().coerceIn(18, 90) - 18
        }
        opacityLabel.text = "背景浓度 " + (opacity.progress + 18) + "%"
        opacity.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) { opacityLabel.text = "背景浓度 " + (progress + 18) + "%" }
            override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
        })
        layout.addView(group); layout.addView(opacityLabel); layout.addView(opacity); layout.addView(privacy)
        layout.addView(TextView(this).apply { text = "组件显示站点与取件码；点击“已取”可记录已经取走的包裹。"; textSize = 13f; setPadding(0, 0, 0, dp(24)) })
        layout.addView(Button(this).apply {
            text = "添加到桌面"
            setOnClickListener {
                ParcelStore(this@WidgetConfigActivity).use { store ->
                    store.putSetting("widgetStyle", if (group.checkedRadioButtonId == 102) "ivory" else "jade")
                    store.putSetting("widgetShowCodes", privacy.isChecked)
                    store.putSetting("widgetOpacity", (opacity.progress + 18) / 100.0)
                }
                PickupWidget.refreshAll(this@WidgetConfigActivity)
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
                finish()
            }
        })
        setContentView(layout)
    }
}
