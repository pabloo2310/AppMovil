import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_bullying/services/emergency_protocol_service.dart';

class ShakeDetectorService {
  static final ShakeDetectorService _instance = ShakeDetectorService._internal();
  factory ShakeDetectorService() => _instance;
  ShakeDetectorService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isEnabled = false;
  bool _isListening = false;
  
  // Configuración de sensibilidad
  double _shakeThreshold = 15.0;
  int _shakeDuration = 500; // milisegundos
  
  // Variables para detectar sacudida
  DateTime? _lastShakeTime;
  List<double> _accelerationHistory = [];
  final int _historySize = 10;

  // Callback para cuando se detecta una sacudida
  VoidCallback? _onShakeDetected;

  // Referencia al servicio de emergencia
  final EmergencyProtocolService _emergencyService = EmergencyProtocolService();

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  double get shakeThreshold => _shakeThreshold;

  Future<void> init({VoidCallback? onShakeDetected}) async {
    _onShakeDetected = onShakeDetected;
    await _loadSettings();
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
          _isEnabled = data['ShakeEnable'] ?? false;
          _shakeThreshold = (data['ShakeSensibilty'] as num?)?.toDouble() ?? 15.0;
          _shakeDuration = data['ShakeDuration'] ?? 500;
          
          // Aplicar configuración
          if (_isEnabled) {
            startListening();
          }
        }
      } catch (e) {
        print('Error loading shake settings: $e');
      }
    }
  }

  Future<void> saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('info_usuario')
            .doc(user.uid)
            .set({
              'ShakeEnable': _isEnabled,
              'ShakeSensibilty': _shakeThreshold,
              'ShakeTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error saving shake settings: $e');
      }
    }
  }

  void startListening() {
    if (_isListening || !_isEnabled) return;

    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _processAccelerometerData(event);
      },
      onError: (error) {
        print('Error en accelerometer: $error');
      },
    );
    
    _isListening = true;
    print('Shake detector iniciado');
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isListening = false;
    _accelerationHistory.clear();
    print('Shake detector detenido');
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // Calcular la magnitud de la aceleración
    double acceleration = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z
    );
    
    // Añadir a la historia
    _accelerationHistory.add(acceleration);
    if (_accelerationHistory.length > _historySize) {
      _accelerationHistory.removeAt(0);
    }

    // Verificar si hay una sacudida
    if (_accelerationHistory.length >= 3) {
      double maxAcceleration = _accelerationHistory.reduce(max);
      double minAcceleration = _accelerationHistory.reduce(min);
      double difference = maxAcceleration - minAcceleration;

      if (difference > _shakeThreshold) {
        _handleShakeDetected();
      }
    }
  }

  void _handleShakeDetected() async {
    final now = DateTime.now();
    
    // Evitar múltiples detecciones muy seguidas
    if (_lastShakeTime != null && 
        now.difference(_lastShakeTime!).inMilliseconds < _shakeDuration) {
      return;
    }
    
    _lastShakeTime = now;
    print('¡Sacudida detectada! Activando protocolo de emergencia...');
    
    // Ejecutar callback original si existe
    _onShakeDetected?.call();

    // NUEVO: Activar protocolo de emergencia automáticamente
    try {
      // Verificar que no haya un protocolo ya activo
      if (!_emergencyService.isProtocolActive) {
        await _emergencyService.startEmergencyProtocol(fromShake: true);
        print('Protocolo de emergencia activado exitosamente por sacudida');
      } else {
        print('Protocolo de emergencia ya está activo, ignorando sacudida');
      }
    } catch (e) {
      print('Error al activar protocolo de emergencia por sacudida: $e');
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (_isEnabled) {
      startListening();
    } else {
      stopListening();
    }
    saveSettings();
  }

  void setThreshold(double threshold) {
    _shakeThreshold = threshold;
    saveSettings();
  }

  void setDuration(int duration) {
    _shakeDuration = duration;
    saveSettings();
  }

  void dispose() {
    stopListening();
  }
}
