import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:app_bullying/widgets/button.dart';
import 'package:app_bullying/services/decibel_detector_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class DecibelSettingsScreen extends StatefulWidget {
  const DecibelSettingsScreen({super.key});

  @override
  State<DecibelSettingsScreen> createState() => _DecibelSettingsScreenState();
}

class _DecibelSettingsScreenState extends State<DecibelSettingsScreen> {
  final DecibelDetectorService _decibelService = DecibelDetectorService();

  double _threshold = 80.0;
  bool _isEnabled = true;
  bool _notificationsEnabled = true;
  bool _backgroundMonitoring = false;
  bool _isLoading = true;
  bool _isRecording = false;
  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _decibelService.init(
      onDecibelUpdate: (decibel) {
        if (mounted) {
          setState(() {
            _currentDecibel = decibel;
          });
        }
      },
      onMaxDecibelUpdate: (maxDecibel) {
        if (mounted) {
          setState(() {
            _maxDecibel = maxDecibel;
          });
        }
      },
      onHighDecibelDetected: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🚨 Nivel de ruido alto detectado: ${_currentDecibel.toStringAsFixed(1)} dB',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('info_usuario')
                .doc(user.uid)
                .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _threshold = (data['DecibelThreshold'] as num?)?.toDouble() ?? 80.0;
            _isEnabled = data['DecibelEnabled'] ?? true;
            _notificationsEnabled = data['DecibelNotifications'] ?? true;
            _backgroundMonitoring = _decibelService.isBackgroundMonitoring;
            _isLoading = false;
          });
        } else {
          setState(() {
            _threshold = _decibelService.notificationThreshold;
            _notificationsEnabled = _decibelService.notificationsEnabled;
            _backgroundMonitoring = _decibelService.isBackgroundMonitoring;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading decibel settings: $e');
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
              'DecibelNotifications': _notificationsEnabled,
              'DecibelTimestamp': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        _decibelService.setThreshold(_threshold);
        _decibelService.setNotificationsEnabled(_notificationsEnabled);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🔊 Configuración de decibelios guardada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _decibelService.stopRecording();
      setState(() {
        _isRecording = false;
        _currentDecibel = 0.0;
      });
    } else {
      await _decibelService.startRecording();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _toggleBackgroundMonitoring() async {
    if (_backgroundMonitoring) {
      await _decibelService.stopBackgroundMonitoring();
      await WakelockPlus.disable();
      setState(() {
        _backgroundMonitoring = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monitoreo en segundo plano detenido'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      await _decibelService.startBackgroundMonitoring();
      await WakelockPlus.enable();
      setState(() {
        _backgroundMonitoring = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monitoreo en segundo plano iniciado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _resetMaxDecibel() {
    _decibelService.resetMaxDecibel();
    setState(() {
      _maxDecibel = 0.0;
    });
  }

  Color _getDecibelColor(double decibel) {
    return _decibelService.getDecibelColor(decibel);
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

  @override
  void dispose() {
    _decibelService.dispose();
    super.dispose();
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
                          'Monitor de Decibelios',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA03E99),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Medidor principal
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getDecibelColor(
                              _currentDecibel,
                            ).withOpacity(0.1),
                            border: Border.all(
                              color: _getDecibelColor(_currentDecibel),
                              width: 3,
                            ),
                            boxShadow:
                                _isRecording
                                    ? [
                                      BoxShadow(
                                        color: _getDecibelColor(
                                          _currentDecibel,
                                        ).withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ]
                                    : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: _getDecibelColor(_currentDecibel),
                                ),
                                child: Text(
                                  '${_currentDecibel.toStringAsFixed(1)}',
                                ),
                              ),
                              Text(
                                'dB',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _getDecibelColor(_currentDecibel),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Nivel de ruido
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _getNoiseLevel(_currentDecibel),
                            key: ValueKey(_getNoiseLevel(_currentDecibel)),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Monitoreo en segundo plano
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                _backgroundMonitoring
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _backgroundMonitoring
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _backgroundMonitoring
                                        ? Icons.autorenew
                                        : Icons.pause_circle_outline,
                                    color:
                                        _backgroundMonitoring
                                            ? Colors.green.shade700
                                            : Colors.grey.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Monitoreo en Segundo Plano',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          _backgroundMonitoring
                                              ? 'Activo - Monitoreando continuamente'
                                              : 'Inactivo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                _backgroundMonitoring
                                                    ? Colors.green.shade600
                                                    : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _backgroundMonitoring,
                                    activeColor: const Color(0xFFA03E99),
                                    onChanged:
                                        (value) =>
                                            _toggleBackgroundMonitoring(),
                                  ),
                                ],
                              ),
                              if (_backgroundMonitoring) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.battery_alert,
                                      size: 16,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Consumo de batería activo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Configuración de umbral
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

                        const SizedBox(height: 10),

                        SwitchListTile(
                          title: const Text(
                            'Notificaciones habilitadas',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Recibir alertas cuando el ruido sea alto',
                          ),
                          value: _notificationsEnabled,
                          activeColor: const Color(0xFFA03E99),
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                          },
                        ),

                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Umbral de alerta (dB):'),
                              Text(
                                _threshold.toStringAsFixed(0),
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
                          min: 60.0,
                          max: 100.0,
                          divisions: 8,
                          activeColor: const Color(0xFFA03E99),
                          inactiveColor: Colors.grey.shade300,
                          onChanged:
                              _isEnabled
                                  ? (value) {
                                    setState(() {
                                      _threshold = value;
                                    });
                                  }
                                  : null,
                        ),

                        const SizedBox(height: 20),

                        // Máximo registrado
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Máximo registrado',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${_maxDecibel.toStringAsFixed(1)} dB',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFA03E99),
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: _resetMaxDecibel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade300,
                                  foregroundColor: Colors.grey.shade700,
                                ),
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Información
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
                            '• 60-70 dB: Conversación normal\n'
                            '• 70-80 dB: Tráfico, aspiradora\n'
                            '• 80-90 dB: Muy ruidoso\n'
                            '• 90+ dB: Peligroso para la audición',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Botones de control
                        if (!_backgroundMonitoring) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _toggleRecording,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _isRecording
                                            ? Colors.red
                                            : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isRecording ? Icons.stop : Icons.mic,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isRecording
                                            ? 'Detener'
                                            : 'Iniciar Detección',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                        ],

                        CustomButton(
                          text: 'Guardar Configuración',
                          icon: Icons.save,
                          onPressed: _saveSettings,
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
