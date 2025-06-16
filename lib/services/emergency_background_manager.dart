import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_bullying/services/background_emergency_service.dart';
import 'package:app_bullying/services/emergency_protocol_service.dart';

class EmergencyBackgroundManager {
  static final EmergencyBackgroundManager _instance = EmergencyBackgroundManager._internal();
  factory EmergencyBackgroundManager() => _instance;
  EmergencyBackgroundManager._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final EmergencyProtocolService _emergencyProtocol = EmergencyProtocolService();
  
  bool _isServiceRunning = false;
  bool _isInitialized = false;

  // Configuración por defecto
  bool _decibelEnabled = true;
  bool _shakeEnabled = true;
  bool _serviceEnabled = false; // Por defecto desactivado
  double _decibelThreshold = 80.0;
  double _shakeThreshold = 15.0;

  // Getters
  bool get isServiceRunning => _isServiceRunning;
  bool get isInitialized => _isInitialized;
  bool get decibelEnabled => _decibelEnabled;
  bool get shakeEnabled => _shakeEnabled;
  bool get serviceEnabled => _serviceEnabled;
  double get decibelThreshold => _decibelThreshold;
  double get shakeThreshold => _shakeThreshold;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar el servicio de fondo
      await BackgroundEmergencyService.initializeService();
      
      // Cargar configuración guardada
      await _loadSettings();
      
      // Configurar listener para emergencias detectadas en segundo plano
      _service.on('emergency_detected').listen((event) {
        _handleBackgroundEmergency(event);
      });
      
      // Verificar estado del servicio
      _isServiceRunning = await _service.isRunning();
      
      _isInitialized = true;
      print('✅ EmergencyBackgroundManager inicializado');
    } catch (e) {
      print('❌ Error inicializando EmergencyBackgroundManager: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _decibelEnabled = prefs.getBool('decibel_enabled') ?? true;
      _shakeEnabled = prefs.getBool('shake_enabled') ?? true;
      _serviceEnabled = prefs.getBool('emergency_service_enabled') ?? false;
      _decibelThreshold = prefs.getDouble('decibel_threshold') ?? 80.0;
      _shakeThreshold = prefs.getDouble('shake_threshold') ?? 15.0;
    } catch (e) {
      print('Error cargando configuración: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('decibel_enabled', _decibelEnabled);
      await prefs.setBool('shake_enabled', _shakeEnabled);
      await prefs.setBool('emergency_service_enabled', _serviceEnabled);
      await prefs.setDouble('decibel_threshold', _decibelThreshold);
      await prefs.setDouble('shake_threshold', _shakeThreshold);
    } catch (e) {
      print('Error guardando configuración: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      // Solicitar permisos necesarios
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.notification,
        Permission.location,
        Permission.ignoreBatteryOptimizations,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      if (!allGranted) {
        print('⚠️ Algunos permisos no fueron concedidos');
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
      return false;
    }
  }

  Future<bool> startBackgroundMonitoring() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Verificar permisos
      bool hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('Permisos insuficientes para el monitoreo en segundo plano');
      }

      // Iniciar servicio
      await _service.startService();
      
      // Enviar configuración al servicio
      _service.invoke('updateSettings', {
        'decibelThreshold': _decibelThreshold,
        'decibelEnabled': _decibelEnabled,
        'shakeThreshold': _shakeThreshold,
        'shakeEnabled': _shakeEnabled,
        'serviceEnabled': true,
      });

      _serviceEnabled = true;
      _isServiceRunning = true;
      await _saveSettings();

      print('🚀 Monitoreo en segundo plano iniciado');
      return true;
    } catch (e) {
      print('❌ Error iniciando monitoreo en segundo plano: $e');
      return false;
    }
  }

  Future<bool> stopBackgroundMonitoring() async {
    try {
      _service.invoke('stopService');
      
      _serviceEnabled = false;
      _isServiceRunning = false;
      await _saveSettings();

      print('🛑 Monitoreo en segundo plano detenido');
      return true;
    } catch (e) {
      print('❌ Error deteniendo monitoreo en segundo plano: $e');
      return false;
    }
  }

  Future<void> updateDecibelSettings(bool enabled, double threshold) async {
    _decibelEnabled = enabled;
    _decibelThreshold = threshold;
    await _saveSettings();

    if (_isServiceRunning) {
      _service.invoke('updateSettings', {
        'decibelThreshold': _decibelThreshold,
        'decibelEnabled': _decibelEnabled,
        'shakeThreshold': _shakeThreshold,
        'shakeEnabled': _shakeEnabled,
        'serviceEnabled': _serviceEnabled,
      });
    }

    print('⚙️ Configuración de decibelios actualizada: $enabled, $threshold');
  }

  Future<void> updateShakeSettings(bool enabled, double threshold) async {
    _shakeEnabled = enabled;
    _shakeThreshold = threshold;
    await _saveSettings();

    if (_isServiceRunning) {
      _service.invoke('updateSettings', {
        'decibelThreshold': _decibelThreshold,
        'decibelEnabled': _decibelEnabled,
        'shakeThreshold': _shakeThreshold,
        'shakeEnabled': _shakeEnabled,
        'serviceEnabled': _serviceEnabled,
      });
    }

    print('⚙️ Configuración de sacudidas actualizada: $enabled, $threshold');
  }

  void _handleBackgroundEmergency(Map<String, dynamic>? event) async {
    if (event == null) return;

    final String reason = event['reason'] ?? 'DESCONOCIDO';
    final String details = event['details'] ?? '';
    final String timestamp = event['timestamp'] ?? '';

    print('🚨 Emergencia detectada en segundo plano: $reason - $details');

    try {
      // Activar el protocolo de emergencia completo
      bool fromShake = reason.contains('SACUDIDA');
      bool fromDecibel = reason.contains('RUIDO');

      await _emergencyProtocol.startEmergencyProtocol(
        fromShake: fromShake,
        fromDecibel: fromDecibel,
      );

      print('✅ Protocolo de emergencia activado desde segundo plano');
    } catch (e) {
      print('❌ Error activando protocolo desde segundo plano: $e');
    }
  }

  Future<Map<String, dynamic>> getServiceStatus() async {
    _isServiceRunning = await _service.isRunning();
    
    return {
      'isRunning': _isServiceRunning,
      'isInitialized': _isInitialized,
      'decibelEnabled': _decibelEnabled,
      'shakeEnabled': _shakeEnabled,
      'serviceEnabled': _serviceEnabled,
      'decibelThreshold': _decibelThreshold,
      'shakeThreshold': _shakeThreshold,
    };
  }

  Future<void> dispose() async {
    if (_isServiceRunning) {
      await stopBackgroundMonitoring();
    }
    print('🧹 EmergencyBackgroundManager disposed');
  }
}
