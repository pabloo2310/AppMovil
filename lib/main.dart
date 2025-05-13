import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const EmergenciaApp());
}

class EmergenciaApp extends StatefulWidget {
  const EmergenciaApp({super.key});

  @override
  State<EmergenciaApp> createState() => _EmergenciaAppState();
}

class _EmergenciaAppState extends State<EmergenciaApp> {
  static const platform = MethodChannel('voice_channel');
  String lastCommand = 'Esperando comando...';

  @override
  void initState() {
    super.initState();
    requestPermissions().then((_) {
      platform.setMethodCallHandler(_onVoiceCommand);
      startService(); // esto inicia el servicio automáticamente
    });
  }

  Future<void> requestPermissions() async {
    await [Permission.microphone, Permission.sms, Permission.phone].request();
  }

  Future<void> _onVoiceCommand(MethodCall call) async {
    if (call.method == 'onCommandRecognized') {
      setState(() {
        lastCommand = call.arguments;
      });
    }
  }

  void startService() => platform.invokeMethod('startVoiceService');
  void stopService() => platform.invokeMethod('stopVoiceService');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Asistente de Emergencia')),
        body: Center(
          child: Text(lastCommand, style: const TextStyle(fontSize: 20)),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: startService,
              child: const Icon(Icons.play_arrow),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              onPressed: stopService,
              child: const Icon(Icons.stop),
            ),
          ],
        ),
      ),
    );
  }
}
