import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:app_bullying/widgets/button.dart';
import 'package:app_bullying/services/shake_detector_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShakeSettingsScreen extends StatefulWidget {
  const ShakeSettingsScreen({super.key});

  @override
  State<ShakeSettingsScreen> createState() => _ShakeSettingsScreenState();
}

class _ShakeSettingsScreenState extends State<ShakeSettingsScreen> {
  final ShakeDetectorService _shakeService = ShakeDetectorService();
  bool _isEnabled = false;
  double _sensitivity = 5.0; // 1 (baja) a 10 (alta)
  bool _isLoading = true;

  // Mapea sensibilidad de usuario (1-10) a umbral interno (30-5)
  double _mapSensitivityToThreshold(double sensitivity) {
    return 30.0 - ((sensitivity - 1) * (25.0 / 9.0));
  }

  // Mapea umbral interno a sensibilidad de usuario
  double _mapThresholdToSensitivity(double threshold) {
    return 1 + ((30.0 - threshold) * 9.0 / 25.0);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await _shakeService.init();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('info_usuario')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            // Cargar estado habilitado/deshabilitado
            _isEnabled = data['ShakeEnable'] ?? false;
            
            // Cargar sensibilidad (convertir de threshold a sensibilidad)
            final threshold = (data['ShakeSensibilty'] as num?)?.toDouble() ?? 15.0;
            _sensitivity = _mapThresholdToSensitivity(threshold);
            
            _isLoading = false;
          });
          
          // Aplicar configuración al servicio
          _shakeService.setEnabled(_isEnabled);
          _shakeService.setThreshold(_mapSensitivityToThreshold(_sensitivity));
        } else {
          setState(() {
            _isEnabled = _shakeService.isEnabled;
            _sensitivity = _mapThresholdToSensitivity(_shakeService.shakeThreshold);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isEnabled = _shakeService.isEnabled;
          _sensitivity = _mapThresholdToSensitivity(_shakeService.shakeThreshold);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading shake settings: $e');
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
          'Detector de Sacudida',
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
                        'Detecta cuando sacudes tu teléfono para activar alertas de emergencia',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      // Switch para activar/desactivar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isEnabled ? Icons.vibration : Icons.phone_android,
                              color: _isEnabled ? Colors.green : Colors.grey,
                              size: 30,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detector de Sacudida',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _isEnabled ? 'Activo' : 'Inactivo',
                                    style: TextStyle(
                                      color: _isEnabled ? Colors.green : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isEnabled,
                              activeColor: const Color(0xFFA03E99),
                              onChanged: (value) {
                                setState(() {
                                  _isEnabled = value;
                                });
                                _shakeService.setEnabled(value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Configuración de sensibilidad (ahora de 1 a 10)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sensibilidad:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _sensitivity.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA03E99),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Slider(
                        value: _sensitivity,
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        activeColor: const Color(0xFFA03E99),
                        inactiveColor: Colors.grey.shade300,
                        onChanged: _isEnabled
                            ? (value) {
                                setState(() {
                                  _sensitivity = value;
                                });
                                // Mapea sensibilidad a threshold y lo guarda
                                _shakeService.setThreshold(_mapSensitivityToThreshold(value));
                              }
                            : null,
                      ),
                      const SizedBox(height: 20),
                      // Información sobre sensibilidad
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
                                  'Información de Sensibilidad',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• 10: Muy sensible (detecta sacudidas suaves)\n'
                              '• 1: Poco sensible (requiere sacudida fuerte)',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Solo botón guardar
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'Guardar',
                              icon: Icons.save,
                              onPressed: () async {
                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    await FirebaseFirestore.instance
                                        .collection('info_usuario')
                                        .doc(user.uid)
                                        .set({
                                      'ShakeEnable': _isEnabled,
                                      'ShakeSensibilty': _mapSensitivityToThreshold(_sensitivity),
                                      'ShakeTimestamp': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('📳 Configuración de sacudida guardada exitosamente'),
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
                          ),
                        ],
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
