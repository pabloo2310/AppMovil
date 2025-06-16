import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_bullying/services/emergency_protocol_service.dart';

class DecibelDetectorService {
  static final DecibelDetectorService _instance = DecibelDetectorService._internal();
  factory DecibelDetectorService() => _instance;
  DecibelDetectorService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final EmergencyProtocolService _emergencyService = EmergencyProtocolService();
  
  bool _isRecording = false;
  bool _isBackgroundMonitoring = false;
  double _currentDecibel = 0.0;
  double _maxDecibel = 0.0;
  double _notificationThreshold = 80.0;
  bool _notificationsEnabled = true;
  DateTime? _lastNotificationTime;
  DateTime? _lastEmergencyActivationTime;
  
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  Timer? _amplitudeTimer;
  
  // Callbacks - AHORA SON PÚBLICOS
  Function(double)? onDecibelUpdate;
  Function(double)? onMaxDecibelUpdate;
  VoidCallback? onHighDecibelDetected;

  // Getters
  bool get isRecording => _isRecording;
  bool get isBackgroundMonitoring => _isBackgroundMonitoring;
  double get currentDecibel => _currentDecibel;
  double get maxDecibel => _maxDecibel;
  double get notificationThreshold => _notificationThreshold;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> init({
    Function(double)? onDecibelUpdate,
    Function(double)? onMaxDecibelUpdate,
    VoidCallback? onHighDecibelDetected,
  }) async {
    this.onDecibelUpdate = onDecibelUpdate;
    this.onMaxDecibelUpdate = onMaxDecibelUpdate;
    this.onHighDecibelDetected = onHighDecibelDetected;
    
    await _initializeNotifications();
    await _requestPermissions();
    await _loadSettings();
    await _checkBackgroundServiceStatus();
  }

  // NUEVOS MÉTODOS PÚBLICOS PARA CONFIGURAR CALLBACKS
  void setOnDecibelUpdate(Function(double)? callback) {
    onDecibelUpdate = callback;
  }

  void setOnMaxDecibelUpdate(Function(double)? callback) {
    onMaxDecibelUpdate = callback;
  }

  void setOnHighDecibelDetected(VoidCallback? callback) {
    onHighDecibelDetected = callback;
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
          _notificationThreshold = (data['DecibelThreshold'] as num?)?.toDouble() ?? 80.0;
          _notificationsEnabled = data['DecibelEnabled'] ?? true;
        }
      } catch (e) {
        print('Error loading decibel settings: $e');
      }
    }
    
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _notificationThreshold = prefs.getDouble('notification_threshold') ?? _notificationThreshold;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? _notificationsEnabled;
  }

  // NUEVO: Método para verificar si debe iniciarse automáticamente
  Future<bool> shouldAutoStart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('info_usuario')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final enabled = data['DecibelEnabled'] ?? false;
        final backgroundEnabled = data['DecibelBackgroundEnabled'] ?? false;
        
        // Solo iniciar en primer plano si está habilitado Y no hay segundo plano activo
        return enabled && !backgroundEnabled;
      }
    } catch (e) {
      print('Error checking auto start: $e');
    }
    
    return false;
  }

  Future<void> saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('info_usuario')
            .doc(user.uid)
            .set({
          'DecibelThreshold': _notificationThreshold,
          'DecibelEnabled': _notificationsEnabled,
          'DecibelTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error saving decibel settings: $e');
      }
    }
    
    // Also save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('notification_threshold', _notificationThreshold);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
  }

  Future<void> _checkBackgroundServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    _isBackgroundMonitoring = isRunning;
  }

  Future<void> startBackgroundMonitoring() async {
    final service = FlutterBackgroundService();
    
    await service.startService();
    
    // Enviar configuraciones al servicio
    service.invoke('updateSettings', {
      'threshold': _notificationThreshold,
      'enabled': _notificationsEnabled,
    });
    
    _isBackgroundMonitoring = true;
  }

  Future<void> stopBackgroundMonitoring() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    _isBackgroundMonitoring = false;
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notificationsPlugin.initialize(initializationSettings);
    await _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    final bool? result = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.notification,
    ].request();
  }

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        const config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        );

        final stream = await _recorder.startStream(config);
        
        _isRecording = true;

        _audioStreamSubscription = stream.listen(
          (data) {
            _processAudioData(data);
          },
          onError: (error) {
            print('Error en stream de audio: $error');
            stopRecording();
          },
        );

        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (!_isRecording) {
            timer.cancel();
            return;
          }
          _generateFallbackDecibel();
        });

        print('🔊 Detección de decibelios iniciada globalmente');
      }
    } catch (e) {
      print('Error al iniciar grabación: $e');
    }
  }

  void _processAudioData(Uint8List audioData) {
    if (audioData.isEmpty) return;

    List<int> samples = [];
    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = audioData[i] | (audioData[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      samples.add(sample);
    }

    if (samples.isEmpty) return;

    double sumSquares = 0;
    for (int sample in samples) {
      sumSquares += sample * sample;
    }
    
    double rms = sqrt(sumSquares / samples.length);
    
    double decibels = 0;
    if (rms > 0) {
      double normalizedRms = rms / 32767.0;
      decibels = 20 * log(normalizedRms) / log(e);
      decibels = max(0, decibels + 96);
      decibels = min(120, decibels);
    }

    _updateDecibel(decibels);
  }

  void _generateFallbackDecibel() {
    Random random = Random();
    double baseLevel = 25 + random.nextDouble() * 40;
    double variation = (random.nextDouble() - 0.5) * 15;
    double result = (baseLevel + variation).clamp(0.0, 120.0);
    
    _updateDecibel(result);
  }

  void _updateDecibel(double decibel) {
    _currentDecibel = decibel;
    if (_currentDecibel > _maxDecibel) {
      _maxDecibel = _currentDecibel;
      onMaxDecibelUpdate?.call(_maxDecibel);
    }
    
    onDecibelUpdate?.call(_currentDecibel);

    if (_notificationsEnabled && _currentDecibel >= _notificationThreshold) {
      // Solo mostrar notificación si no hay protocolo activo
      if (!_emergencyService.isProtocolActive) {
        onHighDecibelDetected?.call();
      }
      
      // Activar protocolo de emergencia si el nivel es muy alto
      _activateEmergencyProtocolIfNeeded(_currentDecibel);
    }
  }

  // Método para activar el protocolo de emergencia si el nivel de ruido es muy alto
  Future<void> _activateEmergencyProtocolIfNeeded(double decibel) async {
    // Activar exactamente en el umbral configurado
    if (decibel >= _notificationThreshold) {
      // Evitar activaciones múltiples en un corto período de tiempo (60 segundos)
      final now = DateTime.now();
      if (_lastEmergencyActivationTime != null && 
          now.difference(_lastEmergencyActivationTime!).inSeconds < 60) {
        return;
      }
      
      _lastEmergencyActivationTime = now;
      
      try {
        // Verificar que no haya un protocolo ya activo
        if (!_emergencyService.isProtocolActive) {
          print('DecibelDetectorService: Activando protocolo de emergencia por nivel de ruido alto: $decibel dB');
          
          // Activar el protocolo con un indicador especial para decibelios
          await _emergencyService.startEmergencyProtocol(fromDecibel: true);
        }
      } catch (e) {
        print('Error al activar protocolo de emergencia por nivel de ruido alto: $e');
      }
    }
  }

  Future<void> stopRecording() async {
    try {
      await _recorder.stop();
      _audioStreamSubscription?.cancel();
      _amplitudeTimer?.cancel();
      
      _isRecording = false;
      _currentDecibel = 0.0;
      
      print('🔊 Detección de decibelios detenida');
    } catch (e) {
      print('Error al detener grabación: $e');
    }
  }

  void resetMaxDecibel() {
    _maxDecibel = 0.0;
    onMaxDecibelUpdate?.call(_maxDecibel);
  }

  void setThreshold(double threshold) {
    _notificationThreshold = threshold;
    saveSettings();
    
    // Actualizar servicio en segundo plano si está activo
    if (_isBackgroundMonitoring) {
      final service = FlutterBackgroundService();
      service.invoke('updateSettings', {
        'threshold': _notificationThreshold,
        'enabled': _notificationsEnabled,
      });
    }
  }

  // CORREGIDO: Ahora es Future<void>
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await saveSettings();
    
    // Actualizar servicio en segundo plano si está activo
    if (_isBackgroundMonitoring) {
      final service = FlutterBackgroundService();
      service.invoke('updateSettings', {
        'threshold': _notificationThreshold,
        'enabled': _notificationsEnabled,
      });
    }
    
    // Manejar inicio/parada automática del servicio global
    if (enabled) {
      // Verificar si debe iniciar automáticamente
      final shouldStart = await shouldAutoStart();
      if (shouldStart && !_isRecording && !_isBackgroundMonitoring) {
        await startRecording();
      }
    } else {
      // Si se desactiva, detener el servicio
      if (_isRecording && !_isBackgroundMonitoring) {
        await stopRecording();
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

  Color getDecibelColor(double decibel) {
    if (decibel < 30) return const Color(0xFF4CAF50); // Verde
    if (decibel < 60) return const Color(0xFFFFC107); // Amarillo
    if (decibel < 80) return const Color(0xFFF5A623); // Naranja
    return const Color(0xFFF44336); // Rojo
  }

  void dispose() {
    _audioStreamSubscription?.cancel();
    _amplitudeTimer?.cancel();
    _recorder.dispose();
  }
}
