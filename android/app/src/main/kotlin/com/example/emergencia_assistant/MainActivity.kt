package com.example.emergencia_assistant

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "voice_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceService" -> {
                    Log.d("VoiceService", "Servicio de voz iniciado desde Flutter")
                    simulateVoiceCommand(flutterEngine)
                    result.success(null)
                }
                "stopVoiceService" -> {
                    Log.d("VoiceService", "Servicio de voz detenido")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun simulateVoiceCommand(flutterEngine: FlutterEngine) {
        Handler(Looper.getMainLooper()).postDelayed({
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onCommandRecognized", "llamar a emergencias")
        }, 3000)
    }
}
