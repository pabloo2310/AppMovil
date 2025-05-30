import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_bullying/services/audio_recorder_service.dart';

class EmergencyProtocolService {
  static final EmergencyProtocolService _instance = EmergencyProtocolService._internal();
  factory EmergencyProtocolService() => _instance;
  EmergencyProtocolService._internal();

  final AudioRecorderService _audioRecorder = AudioRecorderService();
  bool _isProtocolActive = false;
  
  // Variables para almacenar datos durante el protocolo
  Map<String, dynamic>? _protocolData;
  DateTime? _protocolStartTime;
  Timer? _recordingTimer;
  int _currentRecordingDuration = 0;
  int _maxRecordingDuration = 30;

  bool get isProtocolActive => _isProtocolActive;

  Future<Map<String, dynamic>> startEmergencyProtocol() async {
    print('EmergencyProtocolService: startEmergencyProtocol called, current state: $_isProtocolActive');
    
    if (_isProtocolActive) {
      throw Exception('El protocolo de emergencia ya está activo');
    }

    _isProtocolActive = true;
    _protocolStartTime = DateTime.now();
    _currentRecordingDuration = 0;
    
    print('EmergencyProtocolService: Protocol started, state set to: $_isProtocolActive');
    
    try {
      // 1. Obtener usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // 2. Obtener configuración de audio actualizada (en paralelo)
      final userConfigFuture = _getUserConfiguration(user.uid);
      
      // 3. Obtener ubicación (en paralelo)
      final locationFuture = _getCurrentLocation();
      
      // 4. Inicializar grabador (en paralelo)
      final audioInitFuture = _audioRecorder.init();
      
      // Ejecutar todo en paralelo para mayor velocidad
      final results = await Future.wait([
        userConfigFuture,
        locationFuture,
        audioInitFuture,
      ]);
      
      final userConfig = results[0] as Map<String, dynamic>;
      final location = results[1] as Map<String, double>;
      _maxRecordingDuration = userConfig['audioDuration'];
      
      // 5. Preparar datos para enviar DESPUÉS de la grabación
      _protocolData = {
        'audio': 'no implementado aun',
        'latitud': location['latitude'],
        'longitud': location['longitude'],
        'numero': userConfig['phoneNumber'],
        'hora': _protocolStartTime,
        'nombre': userConfig['userName'],
        'userId': user.uid, // Agregar UID del usuario
      };
      
      // 6. Iniciar grabación inmediatamente
      await _startRecordingWithTimer(userConfig['audioDuration']);
      
      return {
        'success': true,
        'message': 'Protocolo de emergencia iniciado',
        'audioDuration': userConfig['audioDuration'],
      };
      
    } catch (e) {
      print('EmergencyProtocolService: Error in startEmergencyProtocol: $e');
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _stopTimer();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> stopEmergencyProtocol() async {
    print('EmergencyProtocolService: stopEmergencyProtocol called, current state: $_isProtocolActive');
    
    if (!_isProtocolActive) {
      print('EmergencyProtocolService: Protocol not active, returning false');
      return {
        'success': false,
        'message': 'El protocolo no está activo',
      };
    }

    try {
      // 1. Detener timer y grabación
      _stopTimer();
      final recordingPath = await _audioRecorder.stopRecording();
      
      // 2. AHORA sí enviar todos los datos a Firebase
      if (_protocolData != null) {
        await _saveEmergencyData(_protocolData!);
      }
      
      // 3. Limpiar estado DESPUÉS de enviar datos
      _isProtocolActive = false;
      final protocolData = _protocolData;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      
      print('EmergencyProtocolService: Protocol stopped successfully, state set to: $_isProtocolActive');
      
      return {
        'success': true,
        'message': 'Protocolo completado y datos enviados a Firebase',
        'recordingPath': recordingPath,
        'data': protocolData,
      };
      
    } catch (e) {
      print('EmergencyProtocolService: Error in stopEmergencyProtocol: $e');
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      _stopTimer();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelEmergencyProtocol() async {
    print('EmergencyProtocolService: cancelEmergencyProtocol called, current state: $_isProtocolActive');
    
    if (!_isProtocolActive) {
      return {
        'success': false,
        'message': 'El protocolo no está activo',
      };
    }

    try {
      // 1. Detener timer y grabación sin enviar datos
      _stopTimer();
      await _audioRecorder.stopRecording();
      
      // 2. Limpiar estado sin enviar a Firebase
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      
      print('EmergencyProtocolService: Protocol cancelled, state set to: $_isProtocolActive');
      
      return {
        'success': true,
        'message': 'Protocolo de emergencia cancelado',
      };
      
    } catch (e) {
      print('EmergencyProtocolService: Error in cancelEmergencyProtocol: $e');
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      _stopTimer();
      rethrow;
    }
  }

  // Método para obtener configuración actualizada en tiempo real
  Future<int> getCurrentAudioDuration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 30;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('info_usuario')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return (data['AudioDuracion'] as num?)?.toInt() ?? 
               (data['recordingDuration'] as num?)?.toInt() ?? 
               30;
      }
      return 30;
    } catch (e) {
      return 30;
    }
  }

  Future<void> _startRecordingWithTimer(int duration) async {
    try {
      await _audioRecorder.startRecording(duration: duration);
      
      // Iniciar timer personalizado para controlar la duración
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _currentRecordingDuration++;
        
        // Si se alcanza la duración máxima, detener automáticamente
        if (_currentRecordingDuration >= duration) {
          _autoStopRecording();
        }
      });
      
    } catch (e) {
      throw Exception('Error al iniciar grabación: $e');
    }
  }

  Future<void> _autoStopRecording() async {
    print('EmergencyProtocolService: _autoStopRecording called, protocol active: $_isProtocolActive');
    if (_isProtocolActive) {
      try {
        // Detener automáticamente el protocolo cuando termine la grabación
        await stopEmergencyProtocol();
      } catch (e) {
        print('Error al detener automáticamente la grabación: $e');
      }
    }
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  Future<Map<String, dynamic>> _getUserConfiguration(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('info_usuario')
          .doc(userId)
          .get();

      int audioDuration = 30; // Duración predeterminada
      String phoneNumber = 'no registrado';
      String userName = 'Usuario';

      if (doc.exists) {
        final data = doc.data()!;
        
        // Obtener duración de audio (puede estar en diferentes campos)
        audioDuration = (data['AudioDuracion'] as num?)?.toInt() ?? 
                       (data['recordingDuration'] as num?)?.toInt() ?? 
                       30;
        
        // Obtener número de teléfono
        phoneNumber = data['phoneNumber'] ?? 
                     data['telefono'] ?? 
                     data['phone'] ?? 
                     'no registrado';
        
        // Obtener nombre del usuario
        userName = data['displayName'] ?? 
                  data['nombre'] ?? 
                  data['name'] ?? 
                  FirebaseAuth.instance.currentUser?.displayName ?? 
                  FirebaseAuth.instance.currentUser?.email ?? 
                  'Usuario';
      }

      return {
        'audioDuration': audioDuration,
        'phoneNumber': phoneNumber,
        'userName': userName,
      };
    } catch (e) {
      print('Error obteniendo configuración del usuario: $e');
      return {
        'audioDuration': 30,
        'phoneNumber': 'no registrado',
        'userName': FirebaseAuth.instance.currentUser?.email ?? 'Usuario',
      };
    }
  }

  Future<Map<String, double>> _getCurrentLocation() async {
    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('El servicio de ubicación está deshabilitado');
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente');
      }

      // Obtener la ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      throw Exception('Error al obtener ubicación: $e');
    }
  }

  Future<void> _saveEmergencyData(Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('simulacion_mensaje')
          .add(data);
      
      print('Datos de emergencia guardados exitosamente en Firebase');
    } catch (e) {
      throw Exception('Error al guardar datos de emergencia: $e');
    }
  }

  // Getters para el estado actual
  bool get isRecording => _audioRecorder.isRecording;
  int get recordingDuration => _currentRecordingDuration;
  int get currentMaxDuration => _maxRecordingDuration;

  // Método para verificar si se puede cancelar (primeros 10 segundos)
  bool get canCancel {
    if (!_isProtocolActive || _protocolStartTime == null) return false;
    final elapsed = DateTime.now().difference(_protocolStartTime!).inSeconds;
    return elapsed <= 10;
  }

  // Método para limpiar recursos
  Future<void> dispose() async {
    print('EmergencyProtocolService: dispose called, cleaning up...');
    _stopTimer();
    await _audioRecorder.dispose();
    _isProtocolActive = false;
    _protocolData = null;
    _protocolStartTime = null;
    _currentRecordingDuration = 0;
    print('EmergencyProtocolService: dispose completed');
  }
}
