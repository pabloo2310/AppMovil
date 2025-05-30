import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SosApp extends StatefulWidget {
  const SosApp({super.key, required this.title});

  final String title;

  @override
  State<SosApp> createState() => _SosAppState();
}

class _SosAppState extends State<SosApp> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _command = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermissions();
  }

  void _requestPermissions() async {
    if (await Permission.microphone.request().isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permiso de micrófono denegado")),
      );
    }

    if (await Permission.sms.request().isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permiso para enviar SMS denegado")),
      );
    }
  }

  void _sendSOSMessage() async {
    const String message = "¡SOS! Necesito ayuda urgente.";
    const List<String> recipients = ["1234567890"]; // Número de emergencia
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("Estado: $status"),
      onError: (error) => print("Error: $error"),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _command = result.recognizedWords;
            if (_command.toLowerCase().contains("sos")) {
              _sendSOSMessage();
            }
          });
        },
      );
    } else {
      setState(() => _isListening = false);
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isListening ? _stopListening : _startListening,
              child: Text(
                _isListening
                    ? "Detener Reconocimiento"
                    : "Iniciar Reconocimiento",
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Comando detectado: $_command",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}