import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:app_bullying/widgets/button.dart';

class DecibelSettingsScreen extends StatefulWidget {
  const DecibelSettingsScreen({super.key});

  @override
  State<DecibelSettingsScreen> createState() => _DecibelSettingsScreenState();
}

class _DecibelSettingsScreenState extends State<DecibelSettingsScreen> {
  double _threshold = 75.0;
  bool _isEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detector de Decibelios',
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
                  child: Column(
                    children: [
                      const Text(
                        'Configuración del Detector',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA03E99),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Ajusta el umbral de decibelios para activar la alerta',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      SwitchListTile(
                        title: const Text(
                          'Activar detector de decibelios',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: _isEnabled,
                        activeColor: const Color(0xFFA03E99),
                        onChanged: (value) {
                          setState(() {
                            _isEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Umbral (dB):'),
                            Text(
                              _threshold.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA03E99),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Slider(
                        value: _threshold,
                        min: 50.0,
                        max: 100.0,
                        divisions: 50,
                        activeColor: const Color(0xFFA03E99),
                        inactiveColor: Colors.grey.shade300,
                        onChanged: _isEnabled
                            ? (value) {
                                setState(() {
                                  _threshold = value;
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Información:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA03E99),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '• 50-60 dB: Conversación normal\n'
                          '• 70-80 dB: Tráfico, aspiradora\n'
                          '• 90+ dB: Concierto, maquinaria pesada',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      const Spacer(),
                      CustomButton(
                        text: 'Guardar Configuración',
                        icon: Icons.save,
                        onPressed: () {
                          // Funcionalidad para guardar configuración (no implementada)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Configuración guardada'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
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
}
