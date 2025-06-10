import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    children: [
                      _buildSettingItem(
                        context,
                        'Editar perfil',
                        Icons.edit,
                        'edit_profile',
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        'Contactos de emergencia',
                        Icons.contact_phone,
                        'emergency_contacts',
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        'Tamaño del audio',
                        Icons.audiotrack,
                        'audio_settings',
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        'Comandos de voz',
                        Icons.mic,
                        'voice_commands',
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        'Detector de decibelios',
                        Icons.volume_up,
                        'decibel_settings',
                      ),
                      const Divider(),
                      _buildSettingItem(
                        context,
                        'Detector de sacudida',
                        Icons.vibration,
                        'shake_settings',
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

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFA03E99)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
