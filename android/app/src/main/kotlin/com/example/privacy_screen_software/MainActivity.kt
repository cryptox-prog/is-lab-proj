package com.example.privacy_screen_software

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.content.Context

class MainActivity : FlutterActivity(), SensorEventListener {
    private lateinit var sensors: SensorManager
    private var sink: EventChannel.EventSink? = null
    private val matrix = FloatArray(9)
    private val angles = FloatArray(3)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "privacy_screen/orientation")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sensors.unregisterListener(this@MainActivity)
                    val sensor = sensors.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
                    if (sensor == null) {
                        events.error("unavailable", "Gyroscope-based orientation is unavailable on this device.", null)
                        return
                    }
                    sink = events
                    if (!sensors.registerListener(this@MainActivity, sensor, 50000)) {
                        sink = null
                        events.error("unavailable", "Unable to start motion sensors.", null)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    sensors.unregisterListener(this@MainActivity)
                    sink = null
                }
            })
    }

    override fun onSensorChanged(event: SensorEvent) {
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        SensorManager.getOrientation(matrix, angles)
        // Android's pitch and azimuth signs differ from Core Motion's.
        sink?.success(mapOf("theta" to -angles[1].toDouble(), "phi" to -angles[0].toDouble()))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        if (::sensors.isInitialized) sensors.unregisterListener(this)
        sink = null
        super.onDestroy()
    }
}
