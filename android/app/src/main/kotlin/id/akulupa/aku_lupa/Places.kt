package id.akulupa.aku_lupa

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONObject

object Places {
    private fun prefs(c: Context) = c.getSharedPreferences("places", Context.MODE_PRIVATE)
    private fun definitions(c: Context) = JSONObject(prefs(c).getString("definitions", "{}")!!)
    fun events(c: Context) = JSONObject(prefs(c).getString("events", "{}")!!)
    private fun pending(c: Context) = PendingIntent.getBroadcast(c, 7015,
        Intent(c, PlaceReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))
    fun status(c: Context): Map<String, Any> = mapOf(
        "fine" to (c.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED),
        "background" to (Build.VERSION.SDK_INT < 29 || c.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED),
        "notifications" to c.getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
        "gps" to c.getSystemService(LocationManager::class.java).isProviderEnabled(LocationManager.GPS_PROVIDER),
        "playServices" to (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(c) == 0)
    )
    fun register(c: Context, row: JSONObject, done: (String?) -> Unit) {
        val s = status(c)
        if (s.values.any { it != true }) {
            done("Aktifkan GPS, notifikasi, lokasi presisi dan izin lokasi Sepanjang waktu. Google Play Services juga diperlukan."); return
        }
        val key = row.getInt("id").toString()
        if (events(c).has(key)) { done(null); return }
        try {
            val fence = Geofence.Builder().setRequestId(key)
                .setCircularRegion(row.getDouble("latitude"), row.getDouble("longitude"), row.getInt("radius").toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER).build()
            val request = GeofencingRequest.Builder().setInitialTrigger(0).addGeofence(fence).build()
            LocationServices.getGeofencingClient(c).addGeofences(request, pending(c))
                .addOnSuccessListener {
                    val all = definitions(c); all.put(key, row)
                    prefs(c).edit().putString("definitions", all.toString()).commit()
                    done(null)
                }.addOnFailureListener { done("Lokasi belum aktif: ${it.message}") }
        } catch (e: Exception) { done("Lokasi belum aktif: ${e.message}") }
    }
    fun remove(c: Context, id: Int, done: (String?) -> Unit) {
        // Remove the local definition first: delayed broadcasts can no longer fire.
        val all = definitions(c); val exists = all.has(id.toString()); all.remove(id.toString())
        val events = events(c); events.remove(id.toString())
        prefs(c).edit().putString("definitions", all.toString()).putString("events", events.toString()).commit()
        c.getSystemService(NotificationManager::class.java).cancel(1500000000 + id)
        if (!exists) { done(null); return }
        LocationServices.getGeofencingClient(c).removeGeofences(listOf(id.toString()))
            .addOnCompleteListener { done(null) }
    }
    fun clear(c: Context, done: (String?) -> Unit) {
        val all = definitions(c)
        for (key in all.keys()) c.getSystemService(NotificationManager::class.java).cancel(1500000000 + key.toInt())
        prefs(c).edit().clear().commit()
        if (all.length() == 0) { done(null); return }
        LocationServices.getGeofencingClient(c).removeGeofences(pending(c)).addOnCompleteListener { done(null) }
    }
    fun restore(c: Context, done: () -> Unit) {
        val all = definitions(c)
        val rows = all.keys().asSequence().filter { !events(c).has(it) }.map { all.getJSONObject(it) }.toList()
        var remaining = rows.size
        if (remaining == 0) { done(); return }
        rows.forEach { row -> register(c, row) { if (--remaining == 0) done() } }
    }
    fun entered(c: Context, id: String) {
        val all = definitions(c)
        val row = all.optJSONObject(id) ?: return
        val events = events(c)
        if (events.has(id) || status(c)["notifications"] != true) return
        val manager = c.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("place_reminders", "Pengingat lokasi", NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "place_reminders") else Notification.Builder(c)
        manager.notify(1500000000 + id.toInt(), builder.setSmallIcon(R.drawable.ic_stat_memory)
            .setContentTitle(row.getString("title")).setContentText("Kamu tiba di ${row.getString("placeName")}")
            .setContentIntent(open).setAutoCancel(true).build())
        events.put(id, System.currentTimeMillis())
        prefs(c).edit().putString("events", events.toString()).commit()
        LocationServices.getGeofencingClient(c).removeGeofences(listOf(id))
    }
}

class PlaceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError() || event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return
        event.triggeringGeofences?.forEach { Places.entered(context, it.requestId) }
    }
}
class IntegrationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ScheduleWidget.refresh(context)
        val pending = goAsync()
        Places.restore(context) { pending.finish() }
    }
}
