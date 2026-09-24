package id.akulupa.aku_lupa

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class ScheduleWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context)
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) refresh(context)
    }
    companion object {
        fun refresh(c: Context) {
            val manager = AppWidgetManager.getInstance(c)
            val ids = manager.getAppWidgetIds(ComponentName(c, ScheduleWidget::class.java))
            if (ids.isEmpty()) return
            val rows = mutableListOf<Pair<Int, String>>()
            val day = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val now = Date(); val today = day.format(now)
            val weekday = (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            val raw = c.getSharedPreferences("integrations", Context.MODE_PRIVATE).getString("widget", null)
            try {
                val data = JSONObject(raw ?: "{}")
                val reminders = data.optJSONArray("reminders")
                if (reminders != null) for (i in 0 until reminders.length()) {
                    val row = reminders.getJSONObject(i); val date = Date(row.getLong("at"))
                    if (day.format(date) == today) {
                        val cal = Calendar.getInstance().apply { time = date }
                        rows.add(Pair(cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE), row.getString("title")))
                    }
                }
                val habits = data.optJSONArray("habits"); val logs = data.optJSONArray("logs")
                if (habits != null) for (i in 0 until habits.length()) {
                    val row = habits.getJSONObject(i)
                    if (row.optInt("weekday", 0) !in listOf(0, weekday)) continue
                    var skip = false; var progress = 0
                    if (logs != null) for (j in 0 until logs.length()) {
                        val log = logs.getJSONObject(j)
                        if (log.getInt("id") == row.getInt("id") && log.getString("date") == today) {
                            skip = log.getString("status") != "pending"; progress = log.getInt("progress")
                        }
                    }
                    if (!skip) rows.add(Pair(row.getInt("minutes"), row.getString("title") +
                        if (row.getInt("target") > 1) " ($progress/${row.getInt("target")})" else ""))
                }
            } catch (_: Exception) { rows.clear() }
            rows.sortBy { it.first }
            val views = RemoteViews(c.packageName, R.layout.schedule_widget)
            views.setTextViewText(R.id.widget_date, SimpleDateFormat("EEEE, d MMM", Locale.forLanguageTag("id-ID")).format(now))
            views.setTextViewText(R.id.widget_rows, if (raw == null) "Buka Aku Lupa untuk menampilkan jadwal." else if (rows.isEmpty())
                "Hari ini masih lapang." else rows.take(3).joinToString("\n") { "%02d:%02d  %s".format(it.first / 60, it.first % 60, it.second) })
            views.setTextViewText(R.id.widget_footer, if (rows.size > 3) "+${rows.size - 3} lainnya · Ketuk untuk membuka" else "Ketuk untuk membuka Aku Lupa")
            views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(c, 0,
                Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            manager.updateAppWidget(ids, views)
        }
    }
}
