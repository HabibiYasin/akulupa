package id.akulupa.aku_lupa

import android.Manifest
import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.provider.Settings
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {
    private lateinit var integrations: MethodChannel
    private val documentState get() = getSharedPreferences("documents", MODE_PRIVATE)
    private var picker: MethodChannel.Result? = null
    private var source: File? = null
    private var permission: MethodChannel.Result? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        integrations = MethodChannel(engine.dartExecutor.binaryMessenger, "id.akulupa/integrations")
        integrations.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "recoverDocument" -> {
                        val message = documentState.getString("message", null)
                        documentState.edit().remove("message").apply()
                        result.success(message)
                    }
                    "saveDocument", "openDocument" -> {
                        check(picker == null) { "Pemilih file masih terbuka." }
                        val save = call.method == "saveDocument"
                        source = if (save) File(call.argument<String>("path")!!).canonicalFile.also {
                            require(it.path.startsWith(cacheDir.canonicalPath + File.separator))
                        } else null
                        val intent = Intent(if (save) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE).setType("application/json")
                        if (save) intent.putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        documentState.edit().putString("source", source?.path).putBoolean("pending", true).commit()
                        picker = result
                        try { startActivityForResult(intent, if (save) 7011 else 7012) }
                        catch (e: Exception) { picker = null; documentState.edit().remove("source").remove("pending").apply(); throw e }
                    }
                    "openCalendar" -> {
                        startActivity(Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI)
                            .putExtra(CalendarContract.Events.TITLE, call.argument<String>("title"))
                            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, call.argument<Number>("start")!!.toLong())
                            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, call.argument<Number>("end")!!.toLong()))
                        result.success(null)
                    }
                    "updateWidget" -> {
                        getSharedPreferences("integrations", MODE_PRIVATE).edit()
                            .putString("widget", call.argument<String>("snapshot")).apply()
                        ScheduleWidget.refresh(this); result.success(null)
                    }
                    "pinWidget" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        check(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported) {
                            "Tambahkan widget Aku Lupa lewat menu widget di layar utama HP."
                        }
                        manager.requestPinAppWidget(ComponentName(this, ScheduleWidget::class.java), null, null)
                        result.success(null)
                    }
                    "locationStatus" -> result.success(Places.status(this))
                    "requestLocation" -> {
                        check(permission == null) { "Permintaan izin masih terbuka." }
                        permission = result
                        requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 7013)
                    }
                    "openLocationSettings" -> {
                        if (Build.VERSION.SDK_INT == 29 && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), 7014)
                        } else startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "currentLocation" -> {
                        check(Places.status(this)["fine"] == true) { "Izinkan lokasi presisi terlebih dahulu." }
                        val cancel = CancellationTokenSource()
                        val handler = Handler(Looper.getMainLooper())
                        val timeout = Runnable { cancel.cancel() }
                        handler.postDelayed(timeout, 20000)
                        LocationServices.getFusedLocationProviderClient(this)
                            .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cancel.token)
                            .addOnCompleteListener { task ->
                                handler.removeCallbacks(timeout)
                                val location = if (task.isSuccessful) task.result else null
                                if (location == null) result.error("location", "Lokasi belum ditemukan. Aktifkan GPS dan coba di luar ruangan.", null)
                                else result.success(mapOf("latitude" to location.latitude, "longitude" to location.longitude))
                            }
                    }
                    "registerPlace" -> Places.register(this, JSONObject(call.arguments as Map<*, *>)) { error ->
                        if (error == null) result.success(null) else result.error("location", error, null)
                    }
                    "removePlace" -> Places.remove(this, call.argument<Number>("id")!!.toInt()) { error ->
                        if (error == null) result.success(null) else result.error("location", error, null)
                    }
                    "clearPlaces" -> Places.clear(this) { error ->
                        if (error == null) result.success(null) else result.error("location", error, null)
                    }
                    "placeEvents" -> {
                        val events = Places.events(this)
                        result.success(events.keys().asSequence().associateWith { events.getLong(it) })
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                val message = if (e is ActivityNotFoundException && call.method == "openCalendar")
                    "Belum ada aplikasi Kalender yang mendukung penambahan acara. Pasang atau aktifkan Google Calendar, lalu coba lagi."
                    else e.message ?: "Tidak dapat membuka aplikasi Android."
                result.error("integration", message, null)
            }
        }
    }

    override fun onRequestPermissionsResult(code: Int, names: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, names, grants)
        if (code == 7013) { permission?.success(null); permission = null }
    }

    @Deprecated("Android activity result bridge")
    override fun onActivityResult(request: Int, response: Int, intent: Intent?) {
        super.onActivityResult(request, response, intent)
        if (request != 7011 && request != 7012) return
        val result = picker
        if (result == null && !documentState.getBoolean("pending", false)) return
        picker = null
        val file = source ?: documentState.getString("source", null)?.let { File(it) }
        source = null
        val uri = intent?.data
        if (response != Activity.RESULT_OK || uri == null) {
            documentState.edit().remove("source").remove("pending").apply()
            result?.success(if (request == 7011) false else null); return
        }
        Thread {
            var imported: File? = null
            try {
                val value: Any = if (request == 7011) {
                    require(file != null && file.canonicalPath.startsWith(cacheDir.canonicalPath + File.separator))
                    contentResolver.openOutputStream(uri, "wt")!!.use { output -> file!!.inputStream().use { it.copyTo(output) } }
                    true
                } else {
                    val target = File.createTempFile("akulupa-import-", ".json", cacheDir)
                    imported = target
                    contentResolver.openInputStream(uri)!!.use { input ->
                        target.outputStream().use { output ->
                            val buffer = ByteArray(8192); var total = 0
                            while (true) {
                                val count = input.read(buffer); if (count < 0) break
                                total += count; require(total <= 32 * 1024 * 1024) { "Cadangan melebihi 32 MB." }
                                output.write(buffer, 0, count)
                            }
                        }
                    }
                    target.path
                }
                documentState.edit().remove("source").remove("pending").commit()
                if (result == null) {
                    imported?.delete()
                    if (request == 7011) file?.delete()
                    recovered(if (request == 7011) "Cadangan berhasil disimpan. Android sempat menutup aplikasi saat pemilih file terbuka."
                        else "Android sempat menutup aplikasi. Pilih kembali file dari Cadangan & pemulihan; catatan belum diubah.")
                } else runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                imported?.delete()
                documentState.edit().remove("source").remove("pending").commit()
                if (result == null) recovered("Cadangan terputus dan belum berhasil. Buat ulang cadangan dari Pengaturan.")
                else runOnUiThread { result.error("document", e.message ?: "File tidak dapat dibaca atau disimpan.", null) }
            }
        }.start()
    }
    private fun recovered(message: String) {
        documentState.edit().putString("message", message).commit()
        runOnUiThread { integrations.invokeMethod("documentRecovered", null) }
    }
}
