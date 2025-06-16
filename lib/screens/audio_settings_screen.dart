import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:app_bullying/widgets/button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  double _recordingDuration = 30.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('info_usuario')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _recordingDuration = (data['AudioDuracion'] as num?)?.toDouble() ?? 
                                (data['recordingDuration'] as num?)?.toDouble() ?? 
                                30.0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading audio settings: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Duración del Audio',
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
                  child: Column(
                    children: [
                      const Text(
                        'Configuración de Grabación',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA03E99),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Ajusta la duración de las grabaciones de audio de emergencia',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      // Duración actual destacada
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA03E99).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFFA03E99),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Duración Actual',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA03E99),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${_recordingDuration.toStringAsFixed(0)} segundos',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA03E99),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Control deslizante
                      const Text(
                        'Ajustar duración:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Slider(
                        value: _recordingDuration,
                        min: 10.0,
                        max: 60.0,
                        divisions: 50,
                        activeColor: const Color(0xFFA03E99),
                        inactiveColor: Colors.grey.shade300,
                        onChanged: (value) {
                          setState(() {
                            _recordingDuration = value;
                          });
                        },
                      ),
                      
                      // Indicadores de rango
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('10s', style: TextStyle(color: Colors.grey)),
                            Text('60s', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Información
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue.shade600),
                                const SizedBox(width: 8),
                                const Text(
                                  'Información',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Duración recomendada: 30 segundos\n'
                              '• Mayor duración = más información\n'
                              '• Menor duración = activación más rápida\n'
                              '• El audio se sube automáticamente',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      CustomButton(
                        text: 'Guardar Configuración',
                        icon: Icons.save,
                        onPressed: () async {
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final settingsRef = FirebaseFirestore.instance
                                  .collection('info_usuario')
                                  .doc(user.uid);

                              await settingsRef.set({
                                'AudioDuracion': _recordingDuration,
                                'AudioTimestamp': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎵 Duración de audio guardada exitosamente'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error: Usuario no autenticado'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al guardar configuración: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
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
