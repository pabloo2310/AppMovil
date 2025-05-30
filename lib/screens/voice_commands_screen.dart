import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';

class VoiceCommandsScreen extends StatelessWidget {
  const VoiceCommandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Comandos de Voz',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF5A623),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5A623), // Naranja
              Color(0xFFA03E99), // Morado
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: CardContainer(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text(
                        'Comandos disponibles',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA03E99),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _buildCommandItem(
                        'ayuda',
                        'Envía un SMS de emergencia',
                        Icons.message,
                      ),
                      const Divider(),
                      _buildCommandItem(
                        'llama',
                        'Realiza una llamada de emergencia',
                        Icons.call,
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Instrucciones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA03E99),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Para activar un comando, simplemente di la palabra clave en voz alta cuando el servicio de reconocimiento de voz esté activo.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Nota: Asegúrate de tener los permisos necesarios activados en la configuración de tu dispositivo.',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommandItem(String command, String description, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFA03E99)),
      title: Text(
        '"$command"',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFFF5A623),
        ),
      ),
      subtitle: Text(description),
    );
  }
}
