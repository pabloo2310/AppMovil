package com.example.app_bullying

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "voice_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startVoiceService") {
                val duration = call.argument<Double>("duration")?.toLong() ?: 30L
                val quality = call.argument<String>("quality") ?: "Media"
                val intent = Intent(this, Class.forName("com.example.bullyng_1.VoiceService"))
                intent.putExtra("duration", duration)
                intent.putExtra("quality", quality)
                startService(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
