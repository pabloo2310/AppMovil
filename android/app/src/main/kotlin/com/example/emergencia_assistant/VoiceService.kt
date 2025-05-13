package com.example.emergencia_assistant

import android.app.Service
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.IBinder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class VoiceService : Service() {
    private lateinit var recognizer: SpeechRecognizer
    private lateinit var channel: MethodChannel
    private lateinit var engine: FlutterEngine

    override fun onCreate() {
        super.onCreate()
        engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "voice_channel")

        recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val command = matches?.get(0)?.lowercase() ?: return

                Log.d("VoiceService", "Comando: $command")
                channel.invokeMethod("onCommandRecognized", command)

                when {
                    command.contains("ayuda") -> enviarSMS()
                    command.contains("llama") -> realizarLlamada()
                }

                startListening()
            }

            override fun onError(error: Int) {
                Log.e("VoiceService", "Error: $error")
                startListening()
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        startListening()
    }

    private fun startListening() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-CL")
        }
        recognizer.startListening(intent)
    }

    private fun realizarLlamada() {
        val intent = Intent(Intent.ACTION_CALL).apply {
            data = Uri.parse("tel:133")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun enviarSMS() {
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("smsto:123456789")
            putExtra("sms_body", "¡Emergencia detectada! Necesito ayuda.")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    override fun onDestroy() {
        recognizer.destroy()
        engine.destroy()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
