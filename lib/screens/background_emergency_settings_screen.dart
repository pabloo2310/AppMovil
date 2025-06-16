import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:app_bullying/widgets/button.dart';
import 'package:app_bullying/services/emergency_background_manager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BackgroundEmergencySettingsScreen extends StatefulWidget {
  const BackgroundEmergencySettingsScreen({super.key});

  @override
  State<BackgroundEmergencySettingsScreen> createState() => _BackgroundEmergencySettingsScreenState();
}

class _BackgroundEmergencySettingsScreenState extends State<BackgroundEmergencySettingsScreen> {
  final EmergencyBackgroundManager _backgroundManager = EmergencyBackgroundManager();
  
  bool _isLoading = true;
  bool _isServiceRunning = false;
  bool _decibelEnabled = true;
  bool _shakeEnabled = true;
  double _decibelThreshold = 80.0;
  double _shakeThreshold = 15.0;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadSettings();
  }

  Future<void> _initializeAndLoadSettings() async {
    try {
      await _backgroundManager.initialize();
      await _loadCurrentSettings();
    } catch (e) {
      print('Error inicializando configuración: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inicializando: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCurrentSettings() async {
    try {
      final status = await _backgroundManager.getServiceStatus();
      
      if (mounted) {
        setState(() {
          _isServiceRunning = status['isRunning'] ?? false;
          _decibelEnabled = status['decibelEnabled'] ?? true;
          _shakeEnabled = status['shakeEnabled'] ?? true;
          _decibelThreshold = status['decibelThreshold'] ?? 80.0;
          _shakeThreshold = status['shakeThreshold'] ?? 15.0;
        });
      }
    } catch (e) {
      print('Error cargando configuración: $e');
    }
  }

  Future<void> _toggleBackgroundService() async {
    try {
      if (_isServiceRunning) {
        // Detener servicio
        bool success = await _backgroundManager.stopBackgroundMonitoring();
        await WakelockPlus.disable();
        
        if (success && mounted) {
          setState(() {
            _isServiceRunning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛑 Monitoreo en segundo plano detenido'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Iniciar servicio
        bool success = await _backgroundManager.startBackgroundMonitoring();
        await WakelockPlus.enable();
        
        if (success && mounted) {
          setState(() {
            _isServiceRunning = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚀 Monitoreo en segundo plano iniciado'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error iniciando monitoreo en segundo plano'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateDecibelSettings() async {
    try {
      await _backgroundManager.updateDecibelSettings(_decibelEnabled, _decibelThreshold);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔊 Configuración de decibelios actualizada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error actualizando decibelios: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateShakeSettings() async {
    try {
      await _backgroundManager.updateShakeSettings(_shakeEnabled, _shakeThreshold);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📳 Configuración de sacudidas actualizada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error actualizando sacudidas: $e'),
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
          'Protección en Segundo Plano',
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
                          'Protección Automática 24/7',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA03E99),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Estado del servicio principal
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isServiceRunning ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isServiceRunning ? Colors.green.shade300 : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isServiceRunning ? Icons.shield : Icons.shield_outlined,
                                    color: _isServiceRunning ? Colors.green.shade700 : Colors.grey.shade600,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Monitoreo en Segundo Plano',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          _isServiceRunning 
                                              ? 'Activo - Detectando emergencias automáticamente'
                                              : 'Inactivo - Toca para activar protección 24/7',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _isServiceRunning ? Colors.green.shade600 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isServiceRunning,
                                    activeColor: const Color(0xFFA03E99),
                                    onChanged: (value) => _toggleBackgroundService(),
                                  ),
                                ],
                              ),
                              if (_isServiceRunning) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'El protocolo de emergencia se activará automáticamente al detectar sacudidas o ruido alto',
                                          style: TextStyle(fontSize: 12),
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

                        // Configuración de decibelios
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.volume_up, color: Colors.purple.shade700),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Detección de Ruido Alto',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _decibelEnabled,
                                    activeColor: const Color(0xFFA03E99),
                                    onChanged: (value) {
                                      setState(() {
                                        _decibelEnabled = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_decibelEnabled) ...[
                                const SizedBox(height: 16),
                                Text('Umbral: ${_decibelThreshold.toInt()} dB'),
                                Slider(
                                  value: _decibelThreshold,
                                  min: 60.0,
                                  max: 100.0,
                                  divisions: 8,
                                  activeColor: const Color(0xFFA03E99),
                                  onChanged: (value) {
                                    setState(() {
                                      _decibelThreshold = value;
                                    });
                                  },
                                ),
                                ElevatedButton(
                                  onPressed: _updateDecibelSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Actualizar Decibelios'),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Configuración de sacudidas
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.vibration, color: Colors.orange.shade700),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Detección de Sacudidas',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _shakeEnabled,
                                    activeColor: const Color(0xFFA03E99),
                                    onChanged: (value) {
                                      setState(() {
                                        _shakeEnabled = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_shakeEnabled) ...[
                                const SizedBox(height: 16),
                                Text('Sensibilidad: ${_shakeThreshold.toInt()}'),
                                Slider(
                                  value: _shakeThreshold,
                                  min: 5.0,
                                  max: 30.0,
                                  divisions: 25,
                                  activeColor: const Color(0xFFA03E99),
                                  onChanged: (value) {
                                    setState(() {
                                      _shakeThreshold = value;
                                    });
                                  },
                                ),
                                ElevatedButton(
                                  onPressed: _updateShakeSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Actualizar Sacudidas'),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Información importante
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.yellow.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange.shade600),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Información Importante',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• El monitoreo en segundo plano consume batería\n'
                                '• Se recomienda desactivar optimización de batería\n'
                                '• El protocolo se activa automáticamente al detectar emergencias\n'
                                '• Funciona incluso con la app cerrada',
                                style: TextStyle(fontSize: 14),
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
