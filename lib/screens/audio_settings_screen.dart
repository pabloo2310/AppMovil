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
  String _selectedQuality = 'Media';
  final List<String> _qualities = ['Baja', 'Media', 'Alta'];
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
            // Cargar duración de audio
            _recordingDuration = (data['AudioDuracion'] as num?)?.toDouble() ?? 
                                (data['recordingDuration'] as num?)?.toDouble() ?? 
                                30.0;
            
            // Cargar calidad de audio
            final quality = data['AudioCalidad'] ?? data['quality'];
            _selectedQuality = _qualities.contains(quality) ? quality : 'Media';
            
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          'Configuración de Audio',
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
                        'Ajusta la duración y calidad de las grabaciones de audio',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Duración (segundos):'),
                            Text(
                              _recordingDuration.toStringAsFixed(0),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA03E99),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Calidad de grabación:'),
                            DropdownButton<String>(
                              value: _selectedQuality,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFFA03E99),
                              ),
                              elevation: 16,
                              style: const TextStyle(color: Color(0xFFA03E99)),
                              underline: Container(
                                height: 2,
                                color: const Color(0xFFA03E99),
                              ),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedQuality = value!;
                                });
                              },
                              items:
                                  _qualities.map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),
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
                          '• Mayor duración consume más espacio\n'
                          '• Mayor calidad mejora el reconocimiento\n'
                          '• Calidad alta consume más batería',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      const Spacer(),
          CustomButton(
            text: 'Guardar Configuración',
            icon: Icons.save,
            onPressed: () async {
              try {
                // Guarda la configuración en Firestore
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final settingsRef = FirebaseFirestore.instance
                      .collection('info_usuario')
                      .doc(user.uid);

                  await settingsRef.set({
                    'AudioDuracion': _recordingDuration,
                    'AudioCalidad': _selectedQuality,
                    'AudioTimestamp': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '🎵 Configuración de audio guardada exitosamente',
                      ),
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
