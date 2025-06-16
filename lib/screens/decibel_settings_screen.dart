import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:app_bullying/widgets/button.dart';
import 'package:app_bullying/services/decibel_detector_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_bullying/services/emergency_background_manager.dart';

class DecibelSettingsScreen extends StatefulWidget {
  const DecibelSettingsScreen({super.key});

  @override
  State<DecibelSettingsScreen> createState() => _DecibelSettingsScreenState();
}

class _DecibelSettingsScreenState extends State<DecibelSettingsScreen> {
  final DecibelDetectorService _decibelService = DecibelDetectorService();
  final EmergencyBackgroundManager _backgroundManager = EmergencyBackgroundManager();
  
  double _threshold = 80.0;
  bool _isEnabled = true;
  bool _backgroundMonitoring = false;
  bool _isLoading = true;
  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _backgroundManager.initialize();
      
      // CORREGIDO: Usar métodos públicos para configurar callbacks
      _decibelService.setOnDecibelUpdate((decibel) {
        if (mounted) {
          setState(() {
            _currentDecibel = decibel;
          });
        }
      });
      
      _decibelService.setOnMaxDecibelUpdate((maxDecibel) {
        if (mounted) {
          setState(() {
            _maxDecibel = maxDecibel;
          });
        }
      });

      await _loadSettings();
    } catch (e) {
      print('Error inicializando servicio: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
            _threshold = (data['DecibelThreshold'] as num?)?.toDouble() ?? 80.0;
            _isEnabled = data['DecibelEnabled'] ?? true;
            _backgroundMonitoring = data['DecibelBackgroundEnabled'] ?? false;
          });
        }
        
        // Sincronizar con el manager de segundo plano
        final status = await _backgroundManager.getServiceStatus();
        if (mounted) {
          setState(() {
            _backgroundMonitoring = status['isRunning'] ?? false;
          });
        }
      } catch (e) {
        print('Error loading decibel settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('info_usuario')
            .doc(user.uid)
            .set({
              'DecibelThreshold': _threshold,
              'DecibelEnabled': _isEnabled,
              'DecibelBackgroundEnabled': _backgroundMonitoring,
              'DecibelTimestamp': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        // Actualizar configuración del servicio global
        _decibelService.setThreshold(_threshold);
        // CORREGIDO: Ahora es async
        await _decibelService.setNotificationsEnabled(_isEnabled);
        
        // Actualizar configuración de segundo plano
        await _backgroundManager.updateDecibelSettings(_isEnabled, _threshold);
        
        if (_backgroundMonitoring && !_backgroundManager.isServiceRunning) {
          await _backgroundManager.startBackgroundMonitoring();
          // Si activamos segundo plano, detener el de primer plano
          if (_decibelService.isRecording) {
            await _decibelService.stopRecording();
          }
        } else if (!_backgroundMonitoring && _backgroundManager.isServiceRunning) {
          await _backgroundManager.stopBackgroundMonitoring();
          // Si desactivamos segundo plano y está habilitado, iniciar en primer plano
          if (_isEnabled && !_decibelService.isRecording) {
            await _decibelService.startRecording();
          }
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar configuración: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getNoiseLevel(double decibel) {
    if (decibel < 30) return 'Silencioso';
    if (decibel < 40) return 'Biblioteca';
    if (decibel < 50) return 'Hogar tranquilo';
    if (decibel < 60) return 'Conversación normal';
    if (decibel < 70) return 'Tráfico ligero';
    if (decibel < 80) return 'Tráfico pesado';
    if (decibel < 90) return 'Muy ruidoso';
    return 'Peligroso';
  }

  Color _getDecibelColor(double decibel) {
    return _decibelService.getDecibelColor(decibel);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detector de Decibelios',
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const Text(
                          'Configuración de Decibelios',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA03E99),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Medidor visual (siempre visible si está activo globalmente)
                        if (_isEnabled) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getDecibelColor(_currentDecibel).withOpacity(0.1),
                              border: Border.all(
                                color: _getDecibelColor(_currentDecibel),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _getDecibelColor(_currentDecibel).withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _getDecibelColor(_currentDecibel),
                                  ),
                                  child: Text('${_currentDecibel.toStringAsFixed(1)}'),
                                ),
                                Text(
                                  'dB',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _getDecibelColor(_currentDecibel),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _getNoiseLevel(_currentDecibel),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _backgroundMonitoring 
                                      ? 'Activo en segundo plano'
                                      : 'Activo en toda la app',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Activar/Desactivar detector
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isEnabled ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isEnabled ? Colors.green.shade300 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isEnabled ? Icons.volume_up : Icons.volume_off,
                                color: _isEnabled ? Colors.green.shade700 : Colors.grey.shade600,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Detector de Ruido Alto',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _isEnabled ? 'Activo - Detectando niveles de ruido en toda la app' : 'Inactivo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _isEnabled ? Colors.green.shade600 : Colors.grey.shade600,
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
                                  _saveSettings();
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Configuración de umbral
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Umbral de Activación',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getDecibelColor(_threshold),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_threshold.toStringAsFixed(0)} dB',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Nivel: ${_getNoiseLevel(_threshold)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getDecibelColor(_threshold),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Slider(
                                value: _threshold,
                                min: 60.0,
                                max: 100.0,
                                divisions: 8,
                                activeColor: const Color(0xFFA03E99),
                                inactiveColor: Colors.grey.shade300,
                                onChanged: _isEnabled ? (value) {
                                  setState(() {
                                    _threshold = value;
                                  });
                                } : null,
                                onChangeEnd: (value) {
                                  _saveSettings();
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Monitoreo en segundo plano
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _backgroundMonitoring ? Colors.blue.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _backgroundMonitoring ? Colors.blue.shade300 : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _backgroundMonitoring ? Icons.shield : Icons.shield_outlined,
                                    color: _backgroundMonitoring ? Colors.blue.shade700 : Colors.grey.shade600,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Protección en Segundo Plano',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          _backgroundMonitoring 
                                              ? 'Activo - Monitoreando 24/7'
                                              : 'Inactivo - Solo cuando la app esté abierta',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _backgroundMonitoring ? Colors.blue.shade600 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _backgroundMonitoring,
                                    activeColor: const Color(0xFFA03E99),
                                    onChanged: _isEnabled ? (value) {
                                      setState(() {
                                        _backgroundMonitoring = value;
                                      });
                                      _saveSettings();
                                    } : null,
                                  ),
                                ],
                              ),
                              if (_backgroundMonitoring) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.battery_alert, size: 16, color: Colors.orange.shade700),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Funciona incluso con la app cerrada. Puede consumir más batería.',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Información de niveles
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
                                    'Referencia de Niveles',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• 60-70 dB: Conversación normal\n'
                                '• 70-80 dB: Tráfico, aspiradora\n'
                                '• 80-90 dB: Muy ruidoso (recomendado)\n'
                                '• 90+ dB: Peligroso para la audición\n\n'
                                '⚠️ Al superar el umbral, se activará automáticamente el protocolo de emergencia',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Estado actual
                        if (_isEnabled)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Configuración guardada automáticamente',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),
                      ],
                    ),
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
