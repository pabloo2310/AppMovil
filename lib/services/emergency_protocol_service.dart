import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_bullying/services/audio_recorder_service.dart';
import 'package:app_bullying/services/audit_logger.dart';
import 'package:app_bullying/services/free_file_upload_service.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyProtocolService {
  static final EmergencyProtocolService _instance =
      EmergencyProtocolService._internal();
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

  // Variables para la ventana emergente global
  OverlayEntry? _cancelOverlay;
  BuildContext? _globalContext;

  // Callbacks para notificar cambios de estado
  final List<VoidCallback> _stateChangeListeners = [];

  bool get isProtocolActive => _isProtocolActive;

  // Método para registrar listeners de cambio de estado
  void addStateChangeListener(VoidCallback listener) {
    _stateChangeListeners.add(listener);
  }

  void removeStateChangeListener(VoidCallback listener) {
    _stateChangeListeners.remove(listener);
  }

  void _notifyStateChange() {
    for (final listener in _stateChangeListeners) {
      try {
        listener();
      } catch (e) {
        print('Error notifying state change listener: $e');
      }
    }
  }

  // Método para registrar el contexto global
  void setGlobalContext(BuildContext? context) {
    print(
      'EmergencyProtocolService: Setting global context: ${context != null}',
    );
    _globalContext = context;
  }

  Future<Map<String, dynamic>> startEmergencyProtocol({
    bool fromShake = false,
    bool fromDecibel = false,
  }) async {
    print(
      'EmergencyProtocolService: startEmergencyProtocol called, current state: $_isProtocolActive, fromShake: $fromShake, fromDecibel: $fromDecibel',
    );

    if (_isProtocolActive) {
      throw Exception('El protocolo de emergencia ya está activo');
    }

    _isProtocolActive = true;
    _protocolStartTime = DateTime.now();
    _currentRecordingDuration = 0;
    _notifyStateChange();

    print(
      'EmergencyProtocolService: Protocol started, state set to: $_isProtocolActive',
    );

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

      // Determinar el origen de la activación
      String activationSource;
      if (fromShake) {
        activationSource = 'shake_detection';
      } else if (fromDecibel) {
        activationSource = 'decibel_detection';
      } else {
        activationSource = 'manual_activation';
      }

      // 5. Preparar datos para enviar DESPUÉS de la grabación
      _protocolData = {
        'audio': 'grabando...', // Se actualizará cuando termine la grabación
        'latitud': location['latitude'],
        'longitud': location['longitude'],
        'numero': userConfig['phoneNumber'],
        'hora': _protocolStartTime,
        'nombre': userConfig['userName'],
        'userId': user.uid,
        'activatedBy': activationSource,
      };

      // 6. Mostrar ventana emergente INMEDIATAMENTE (siempre que haya contexto)
      if (_globalContext != null) {
        try {
          _showGlobalCancelOverlay();
        } catch (e) {
          print('Error showing cancel overlay: $e');
          // Continuar sin la ventana emergente si hay error
        }
      }

      // 7. Iniciar grabación inmediatamente
      await _startRecordingWithTimer(userConfig['audioDuration']);

      // 8. Mostrar notificación en la app actual SOLO si es activación manual
      if (_globalContext != null && !fromShake && !fromDecibel) {
        try {
          ScaffoldMessenger.of(_globalContext!).showSnackBar(
            const SnackBar(
              content: Text('🚨 Protocolo de emergencia iniciado'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          print('Error showing snackbar: $e');
        }
      }

      String logMessage;
      if (fromShake) {
        logMessage = "por sacudida";
      } else if (fromDecibel) {
        logMessage = "por nivel de ruido alto";
      } else {
        logMessage = "manualmente";
      }

      AuditLogger.log('Protocolo de emergencia iniciado $logMessage');

      return {
        'success': true,
        'message':
            fromShake
                ? 'Protocolo activado por sacudida detectada'
                : (fromDecibel
                    ? 'Protocolo activado por nivel de ruido alto'
                    : 'Protocolo de emergencia iniciado'),
        'audioDuration': userConfig['audioDuration'],
      };
    } catch (e) {
      print('EmergencyProtocolService: Error in startEmergencyProtocol: $e');
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      _stopTimer();
      _removeCancelOverlay();
      _notifyStateChange();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> stopEmergencyProtocol() async {
    print(
      'EmergencyProtocolService: stopEmergencyProtocol called, current state: $_isProtocolActive',
    );

    if (!_isProtocolActive) {
      print('EmergencyProtocolService: Protocol not active, returning false');
      return {'success': false, 'message': 'El protocolo no está activo'};
    }

    try {
      // 1. Detener timer y grabación
      _stopTimer();
      _removeCancelOverlay();
      final recordingPath = await _audioRecorder.stopRecording();

      // 2. Subir audio usando servicios gratuitos
      String? audioUrl;
      if (recordingPath != null && FreeFileUploadService.isValidAudioFile(recordingPath)) {
        try {
          // Mostrar progreso de subida SOLO si la app está activa
          if (_globalContext != null) {
            ScaffoldMessenger.of(_globalContext!).showSnackBar(
              const SnackBar(
                content: Text('📤 Subiendo audio...'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }

          audioUrl = await FreeFileUploadService.uploadAudioFile(recordingPath);
          print('✅ Audio subido exitosamente: $audioUrl');
          
        } catch (e) {
          print('❌ Error subiendo audio: $e');
          audioUrl = 'Error al subir audio: $e';
        }
      } else {
        audioUrl = 'No se pudo grabar el audio o archivo inválido';
        print('⚠️ Archivo de audio no válido: $recordingPath');
      }

      // 3. Actualizar datos del protocolo con la URL del audio
      if (_protocolData != null) {
        _protocolData!['audio'] = audioUrl ?? 'No disponible';
        _protocolData!['audioPath'] = recordingPath ?? 'No disponible';
      }

      // 4. Enviar todos los datos a Firebase
      if (_protocolData != null) {
        await _saveEmergencyData(_protocolData!);
      }

      // 5. Enviar mensajes de WhatsApp con toda la información incluyendo el audio
      await _sendWhatsAppMessages(_protocolData!, audioUrl);

      // 6. Limpiar estado DESPUÉS de enviar datos
      _isProtocolActive = false;
      final protocolData = _protocolData;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      _notifyStateChange();

      print(
        'EmergencyProtocolService: Protocol stopped successfully, state set to: $_isProtocolActive',
      );

      // 7. Mostrar diálogo de completado si hay contexto
      if (_globalContext != null && protocolData != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _showProtocolCompleteDialog(recordingPath, protocolData, audioUrl);
        });
      }

      return {
        'success': true,
        'message': 'Protocolo completado, audio enviado y WhatsApp activado',
        'recordingPath': recordingPath,
        'audioUrl': audioUrl,
        'data': protocolData,
      };
    } catch (e) {
      print('EmergencyProtocolService: Error in stopEmergencyProtocol: $e');
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      _stopTimer();
      _removeCancelOverlay();
      _notifyStateChange();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelEmergencyProtocol() async {
    print(
      'EmergencyProtocolService: cancelEmergencyProtocol called, current state: $_isProtocolActive',
    );

    if (!_isProtocolActive) {
      return {'success': false, 'message': 'El protocolo no está activo'};
    }

    try {
      // 1. Detener timer y grabación sin enviar datos
      _stopTimer();
      _removeCancelOverlay();
      await _audioRecorder.stopRecording();

      // 2. Limpiar estado sin enviar a Firebase
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      _notifyStateChange();

      // 3. Mostrar notificación de cancelación SOLO si la app está activa
      if (_globalContext != null) {
        try {
          ScaffoldMessenger.of(_globalContext!).showSnackBar(
            const SnackBar(
              content: Text('❌ Protocolo de emergencia cancelado'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          print('Error showing cancel snackbar: $e');
        }
      }

      print(
        'EmergencyProtocolService: Protocol cancelled, state set to: $_isProtocolActive',
      );

      return {'success': true, 'message': 'Protocolo de emergencia cancelado'};
    } catch (e) {
      print('EmergencyProtocolService: Error in cancelEmergencyProtocol: $e');
      _isProtocolActive = false;
      _protocolData = null;
      _protocolStartTime = null;
      _currentRecordingDuration = 0;
      _stopTimer();
      _removeCancelOverlay();
      _notifyStateChange();
      rethrow;
    }
  }

  void _showGlobalCancelOverlay() {
    if (_globalContext == null) {
      print(
        'EmergencyProtocolService: No global context available for overlay',
      );
      return;
    }

    // Remover overlay anterior si existe
    _removeCancelOverlay();

    try {
      String activationSource =
          _protocolData?['activatedBy'] ?? 'manual_activation';
      bool fromShake = activationSource == 'shake_detection';
      bool fromDecibel = activationSource == 'decibel_detection';

      _cancelOverlay = OverlayEntry(
        builder:
            (context) => _CancelProtocolOverlay(
              onCancel: () async {
                await cancelEmergencyProtocol();
              },
              onDismiss: _removeCancelOverlay,
              recordingDuration: _currentRecordingDuration,
              maxDuration: _maxRecordingDuration,
              activatedByShake: fromShake,
              activatedByDecibel: fromDecibel,
            ),
      );

      Overlay.of(_globalContext!).insert(_cancelOverlay!);
      print('EmergencyProtocolService: Cancel overlay inserted successfully');
    } catch (e) {
      print('EmergencyProtocolService: Error inserting overlay: $e');
      _cancelOverlay = null;
    }
  }

  void _removeCancelOverlay() {
    if (_cancelOverlay != null) {
      try {
        _cancelOverlay!.remove();
        print('EmergencyProtocolService: Cancel overlay removed');
      } catch (e) {
        print('EmergencyProtocolService: Error removing overlay: $e');
      }
      _cancelOverlay = null;
    }
  }

  void _showProtocolCompleteDialog(String? path, Map<String, dynamic> data, String? audioUrl) {
    if (_globalContext == null) return;

    try {
      String activationSource = data['activatedBy'] ?? 'manual_activation';
      String activationText;

      switch (activationSource) {
        case 'shake_detection':
          activationText = 'Sacudida';
          break;
        case 'decibel_detection':
          activationText = 'Nivel de ruido alto';
          break;
        default:
          activationText = 'Manual';
      }

      showDialog(
        context: _globalContext!,
        builder:
            (context) => AlertDialog(
              title: const Text('🚨 Protocolo Completado'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Protocolo ejecutado exitosamente:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text('✅ Grabación de audio completada'),
                  Text(audioUrl != null && !audioUrl.contains('Error') ? '✅ Audio subido (gratuito)' : '⚠️ Audio no disponible'),
                  const Text('✅ Ubicación GPS obtenida'),
                  const Text('✅ Datos enviados a Firebase'),
                  const Text('✅ WhatsApp activado'),
                  const SizedBox(height: 15),
                  Text(
                    '📍 Ubicación: ${data['latitud']?.toStringAsFixed(6)}, ${data['longitud']?.toStringAsFixed(6)}',
                  ),
                  Text('👤 Usuario: ${data['nombre']}'),
                  Text('📱 Teléfono: ${data['numero']}'),
                  Text('🔧 Activado por: $activationText'),
                  const SizedBox(height: 10),
                  if (audioUrl != null && !audioUrl.contains('Error'))
                    Text(
                      '🎵 Audio: ${audioUrl.length > 50 ? '${audioUrl.substring(0, 50)}...' : audioUrl}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
      );
    } catch (e) {
      print('Error showing protocol complete dialog: $e');
    }
  }

  // Método para obtener configuración actualizada en tiempo real
  Future<int> getCurrentAudioDuration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 30;

    try {
      final doc =
          await FirebaseFirestore.instance
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
        // Reducir la frecuencia de notificaciones de duración
        if (_currentRecordingDuration % 5 == 0) {
          _notifyStateChange();
        }

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
    print(
      'EmergencyProtocolService: _autoStopRecording called, protocol active: $_isProtocolActive',
    );
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

  // MODIFICADO: Buscar en colección "users" el campo "phone"
  Future<Map<String, dynamic>> _getUserConfiguration(String userId) async {
    try {
      // Buscar en la colección "users" en lugar de "info_usuario"
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      // También buscar configuración de audio en "info_usuario"
      final configDoc = await FirebaseFirestore.instance
          .collection('info_usuario')
          .doc(userId)
          .get();

      int audioDuration = 30; // Duración predeterminada
      String phoneNumber = 'no registrado';
      String userName = 'Usuario';
      List<String> emergencyContacts = [];

      // Obtener número de teléfono desde "users"
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        phoneNumber = userData['phone'] ?? 'no registrado';
        userName = userData['name'] ?? userData['displayName'] ?? 'Usuario';
        print('📱 Número encontrado en users: $phoneNumber');
      }

      // Obtener configuración de audio y contactos desde "info_usuario"
      if (configDoc.exists) {
        final configData = configDoc.data()!;
        audioDuration =
            (configData['AudioDuracion'] as num?)?.toInt() ??
            (configData['recordingDuration'] as num?)?.toInt() ??
            30;
        print('🎵 Duración de audio: $audioDuration segundos');

        // Obtener contactos de emergencia
        for (int i = 1; i <= 10; i++) {
          final contactPhone = configData['EmergencyContact${i}Phone'];
          if (contactPhone != null && contactPhone.toString().isNotEmpty && contactPhone != 'No configurado') {
            emergencyContacts.add(contactPhone.toString());
          }
        }
      }

      // Si no se encontró nombre en users, usar el de Firebase Auth
      if (userName == 'Usuario') {
        userName = FirebaseAuth.instance.currentUser?.displayName ??
            FirebaseAuth.instance.currentUser?.email ??
            'Usuario';
      }

      return {
        'audioDuration': audioDuration,
        'phoneNumber': phoneNumber,
        'userName': userName,
        'emergencyContacts': emergencyContacts,
      };
    } catch (e) {
      print('Error obteniendo configuración del usuario: $e');
      return {
        'audioDuration': 30,
        'phoneNumber': 'no registrado',
        'userName': FirebaseAuth.instance.currentUser?.email ?? 'Usuario',
        'emergencyContacts': <String>[],
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

      return {'latitude': position.latitude, 'longitude': position.longitude};
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

  // Método simplificado que intenta abrir WhatsApp directamente
  Future<bool> _tryOpenWhatsApp(String phoneNumber, String message) async {
    // Lista de URLs a probar en orden de preferencia
    List<String> urlsToTry = [
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
      'https://api.whatsapp.com/send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}',
      'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}',
    ];

    for (String url in urlsToTry) {
      try {
        print('🔄 Intentando abrir: $url');
        
        // Intentar abrir directamente sin verificar canLaunchUrlString
        await launchUrlString(
          url,
          mode: LaunchMode.externalApplication,
        );
        
        print('✅ WhatsApp abierto exitosamente con: $url');
        return true;
      } catch (e) {
        print('❌ Error con URL $url: $e');
        continue;
      }
    }
    
    print('❌ No se pudo abrir WhatsApp con ninguna URL');
    return false;
  }

  // Método para limpiar y validar número de teléfono
  String _cleanPhoneNumber(String phoneNumber) {
    // Remover espacios, guiones, paréntesis, etc.
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Si no tiene código de país, agregar +56 (Chile) como ejemplo
    // Puedes cambiar esto según tu país
    if (!cleaned.startsWith('+') && cleaned.length >= 8) {
      // Cambiar +56 por tu código de país
      cleaned = '+56$cleaned';
    }
    
    return cleaned;
  }

  // MODIFICADO: Método para enviar mensajes de WhatsApp con audio incluido (GRATUITO)
  Future<void> _sendWhatsAppMessages(Map<String, dynamic> protocolData, String? audioUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Obtener contactos de emergencia de Firebase
      final doc = await FirebaseFirestore.instance
          .collection('info_usuario')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        print('No se encontró información del usuario para enviar WhatsApp');
        return;
      }

      final data = doc.data()!;
      List<String> emergencyContacts = [];

      // Recopilar todos los contactos de emergencia
      for (int i = 1; i <= 10; i++) {
        final contactPhone = data['EmergencyContact${i}Phone'];
        if (contactPhone != null && contactPhone.toString().isNotEmpty && contactPhone != 'No configurado') {
          emergencyContacts.add(contactPhone.toString());
        }
      }

      if (emergencyContacts.isEmpty) {
        print('No hay contactos de emergencia configurados para WhatsApp');
        return;
      }

      // Crear mensaje detallado con audio incluido
      String activationSource = protocolData['activatedBy'] ?? 'manual_activation';
      String activationText;

      switch (activationSource) {
        case 'shake_detection':
          activationText = 'sacudida';
          break;
        case 'decibel_detection':
          activationText = 'ruido alto';
          break;
        default:
          activationText = 'manual';
      }

      // NUEVO: Mensaje con audio incluido (usando servicios gratuitos)
      String emergencyMessage;
      
      if (audioUrl != null && !audioUrl.contains('Error')) {
        emergencyMessage = '''🚨 EMERGENCIA 🚨
${protocolData['nombre']} necesita ayuda.

📍 Ubicación: https://maps.google.com/?q=${protocolData['latitud']},${protocolData['longitud']}

📱 ${protocolData['numero']}
⏰ ${DateTime.now().toString().substring(0, 16)}
🔧 Activado por: $activationText

🎵 Audio de emergencia: $audioUrl

¡Contacta inmediatamente!''';
      } else {
        emergencyMessage = '''🚨 EMERGENCIA 🚨
${protocolData['nombre']} necesita ayuda.

📍 Ubicación: https://maps.google.com/?q=${protocolData['latitud']},${protocolData['longitud']}

📱 ${protocolData['numero']}
⏰ ${DateTime.now().toString().substring(0, 16)}
🔧 Activado por: $activationText

❌ Audio no disponible

¡Contacta inmediatamente!''';
      }

      int successCount = 0;
      int failCount = 0;

      print('📱 Iniciando envío de WhatsApp a ${emergencyContacts.length} contactos...');
      if (audioUrl != null && !audioUrl.contains('Error')) {
        print('🎵 Audio incluido: $audioUrl');
      }

      // Enviar a todos los contactos
      for (final phoneNumber in emergencyContacts) {
        try {
          String cleanPhone = _cleanPhoneNumber(phoneNumber);
          print('📞 Procesando contacto: $phoneNumber -> $cleanPhone');

          bool sent = await _tryOpenWhatsApp(cleanPhone, emergencyMessage);
          
          if (sent) {
            successCount++;
          } else {
            failCount++;
          }

          // Pausa entre mensajes para evitar problemas
          await Future.delayed(const Duration(milliseconds: 2000));
        } catch (e) {
          failCount++;
          print('❌ Error general enviando a $phoneNumber: $e');
        }
      }

      print('📊 Resultado WhatsApp: $successCount exitosos, $failCount fallidos de ${emergencyContacts.length} contactos');
      if (audioUrl != null && !audioUrl.contains('Error')) {
        print('🎵 Audio incluido en mensajes: $audioUrl');
      }
    } catch (e) {
      print('❌ Error enviando mensajes de WhatsApp: $e');
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
    _removeCancelOverlay();
    await _audioRecorder.dispose();
    _isProtocolActive = false;
    _protocolData = null;
    _protocolStartTime = null;
    _currentRecordingDuration = 0;
    _globalContext = null;
    _stateChangeListeners.clear();
    print('EmergencyProtocolService: dispose completed');
  }
}

class _CancelProtocolOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onDismiss;
  final int recordingDuration;
  final int maxDuration;
  final bool activatedByShake;
  final bool activatedByDecibel;

  const _CancelProtocolOverlay({
    required this.onCancel,
    required this.onDismiss,
    required this.recordingDuration,
    required this.maxDuration,
    this.activatedByShake = false,
    this.activatedByDecibel = false,
  });

  @override
  State<_CancelProtocolOverlay> createState() => _CancelProtocolOverlayState();
}

class _CancelProtocolOverlayState extends State<_CancelProtocolOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  int _countdown = 10;
  Timer? _countdownTimer;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isActive || !mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdown--;
      });

      // Solo cerrar cuando llegue exactamente a 0
      if (_countdown <= 0) {
        timer.cancel();
        _isActive = false;
        widget.onDismiss();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _isActive = false;
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determinar el título y el ícono según el origen de la activación
    String title;
    IconData iconData;
    Color iconColor;

    if (widget.activatedByShake) {
      title = '🚨 Protocolo Activado por Sacudida';
      iconData = Icons.vibration;
      iconColor = Colors.deepOrange;
    } else if (widget.activatedByDecibel) {
      title = '🚨 Protocolo Activado por Ruido Alto';
      iconData = Icons.volume_up;
      iconColor = Colors.purple;
    } else {
      title = '🚨 Protocolo de Emergencia Activado';
      iconData = Icons.emergency;
      iconColor = Colors.orange;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ícono y título
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(iconData, size: 40, color: iconColor),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA03E99),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Información de grabación
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Text(
                            '🎙️ Grabando: ${_formatDuration(widget.recordingDuration)} / ${_formatDuration(widget.maxDuration)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'Se cerrará automáticamente en $_countdown segundos',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Contador visual
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: iconColor, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              '$_countdown',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Botón de cancelar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _isActive = false;
                              widget.onCancel();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'CANCELAR PROTOCOLO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Si no cancelas, el protocolo continuará automáticamente',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
