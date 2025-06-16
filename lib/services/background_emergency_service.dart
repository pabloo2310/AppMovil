import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class BackgroundEmergencyService {
  static const String _decibelThresholdKey = 'decibel_threshold';
  static const String _decibelEnabledKey = 'decibel_enabled';
  static const String _shakeThresholdKey = 'shake_threshold';
  static const String _shakeEnabledKey = 'shake_enabled';
  static const String _emergencyServiceEnabledKey = 'emergency_service_enabled';
  
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_background_service',
      'Monitoreo de Emergencia B-Resol',
      description: 'Servicio que monitorea decibelios y sacudidas en segundo plano',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
      'emergency_alerts',
      'Alertas de Emergencia B-Resol',
      description: 'Notificaciones de emergencia detectadas automáticamente',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // NUEVO: Canal para notificaciones de protocolo activo
    const AndroidNotificationChannel protocolChannel = AndroidNotificationChannel(
      'emergency_protocol_active',
      'Protocolo de Emergencia Activo',
      description: 'Notificaciones cuando el protocolo está activo para poder cancelar',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(emergencyChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(protocolChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'emergency_background_service',
        initialNotificationTitle: 'B-Resol Protección Activa',
        initialNotificationContent: 'Monitoreando emergencias en segundo plano...',
        foregroundServiceNotificationId: 999,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Inicializar Firebase
    try {
      await Firebase.initializeApp();
    } catch (e) {
      if (kDebugMode) {
        print('Firebase ya inicializado: $e');
      }
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Variables de estado
    final AudioRecorder recorder = AudioRecorder();
    StreamSubscription<Uint8List>? audioStreamSubscription;
    StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
    Timer? monitoringTimer;
    DateTime? lastEmergencyTime;
    DateTime? lastNotificationTime;
    
    // Variables para detección de sacudidas
    List<double> accelerationHistory = [];
    final int historySize = 10;
    DateTime? lastShakeTime;
    
    // Obtener configuraciones iniciales
    final prefs = await SharedPreferences.getInstance();
    double decibelThreshold = prefs.getDouble(_decibelThresholdKey) ?? 80.0;
    bool decibelEnabled = prefs.getBool(_decibelEnabledKey) ?? true;
    double shakeThreshold = prefs.getDouble(_shakeThresholdKey) ?? 15.0;
    bool shakeEnabled = prefs.getBool(_shakeEnabledKey) ?? true;
    bool serviceEnabled = prefs.getBool(_emergencyServiceEnabledKey) ?? true;

    if (kDebugMode) {
      print('🚀 Servicio de emergencia iniciado en segundo plano');
      print('📊 Configuración: Decibel=$decibelThreshold (${decibelEnabled ? 'ON' : 'OFF'}), Shake=$shakeThreshold (${shakeEnabled ? 'ON' : 'OFF'})');
    }

    // NUEVO: Función para mostrar notificación de protocolo activo
    Future<void> showProtocolActiveNotification(String reason, String details) async {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'emergency_protocol_active',
            'Protocolo de Emergencia Activo',
            channelDescription: 'Notificaciones cuando el protocolo está activo para poder cancelar',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFA03E99),
            enableVibration: true,
            playSound: true,
            ongoing: true, // Hace que la notificación sea persistente
            autoCancel: false,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'open_app',
                'ABRIR APP PARA CANCELAR',
                showsUserInterface: true,
              ),
            ],
          );
      
      const NotificationDetails platformChannelSpecifics = 
          NotificationDetails(android: androidPlatformChannelSpecifics);
      
      await flutterLocalNotificationsPlugin.show(
        3, // ID único para notificación de protocolo activo
        '🚨 PROTOCOLO DE EMERGENCIA ACTIVO',
        '$reason detectado - Toca para abrir la app y cancelar si es falsa alarma',
        platformChannelSpecifics,
      );
    }

    // Función para mostrar notificación de emergencia
    Future<void> showEmergencyNotification(String reason, String details) async {
      final now = DateTime.now();
      
      // Evitar spam de notificaciones (2 minutos)
      if (lastNotificationTime != null && 
          now.difference(lastNotificationTime!).inMinutes < 2) {
        return;
      }
      lastNotificationTime = now;

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'emergency_alerts',
            'Alertas de Emergencia B-Resol',
            channelDescription: 'Notificaciones de emergencia detectadas automáticamente',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFFFF0000),
            enableVibration: true,
            playSound: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
          );
      
      const NotificationDetails platformChannelSpecifics = 
          NotificationDetails(android: androidPlatformChannelSpecifics);
      
      await flutterLocalNotificationsPlugin.show(
        2,
        '🚨 EMERGENCIA DETECTADA',
        '$reason: $details - Protocolo activándose...',
        platformChannelSpecifics,
      );
    }

    // Función para guardar evento en Firebase
    Future<void> saveEmergencyEvent(String reason, String details) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('emergency_events_background')
              .add({
            'userId': user.uid,
            'reason': reason,
            'details': details,
            'timestamp': FieldValue.serverTimestamp(),
            'detectedInBackground': true,
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error guardando evento de emergencia: $e');
        }
      }
    }

    // Función para activar protocolo de emergencia
    Future<void> activateEmergencyProtocol(String reason, String details) async {
      final now = DateTime.now();
      
      // Evitar activaciones múltiples muy seguidas (5 minutos)
      if (lastEmergencyTime != null && 
          now.difference(lastEmergencyTime!).inMinutes < 5) {
        if (kDebugMode) {
          print('⏰ Protocolo de emergencia ya activado recientemente, ignorando');
        }
        return;
      }
      lastEmergencyTime = now;

      if (kDebugMode) {
        print('🚨 ACTIVANDO PROTOCOLO DE EMERGENCIA: $reason - $details');
      }

      try {
        // Mostrar notificación de emergencia inmediata
        await showEmergencyNotification(reason, details);
        
        // NUEVO: Mostrar notificación persistente para poder cancelar
        await showProtocolActiveNotification(reason, details);
        
        // Guardar evento en Firebase
        await saveEmergencyEvent(reason, details);
        
        // Enviar comando a la app principal para activar protocolo completo
        service.invoke('emergency_detected', {
          'reason': reason,
          'details': details,
          'timestamp': now.toIso8601String(),
        });

        if (kDebugMode) {
          print('✅ Protocolo de emergencia activado exitosamente');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error activando protocolo de emergencia: $e');
        }
      }
    }

    // Función para procesar datos de audio (decibelios)
    void processAudioData(Uint8List audioData) {
      if (!decibelEnabled || !serviceEnabled) return;

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

      // Actualizar notificación del servicio
      if (DateTime.now().second % 15 == 0) {
        service.invoke('setAsForeground', {
          'title': "B-Resol Protección Activa",
          'content': "🔊 ${decibels.toStringAsFixed(1)} dB | 📳 Shake: ${shakeEnabled ? 'ON' : 'OFF'}",
        });
      }

      // Verificar si se debe activar emergencia por decibelios
      if (decibels >= decibelThreshold) {
        activateEmergencyProtocol(
          'RUIDO ALTO',
          '${decibels.toStringAsFixed(1)} dB (umbral: ${decibelThreshold.toInt()} dB)'
        );
      }
    }

    // Función para procesar datos del acelerómetro (sacudidas)
    void processAccelerometerData(AccelerometerEvent event) {
      if (!shakeEnabled || !serviceEnabled) return;

      // Calcular la magnitud de la aceleración
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z
      );
      
      // Añadir a la historia
      accelerationHistory.add(acceleration);
      if (accelerationHistory.length > historySize) {
        accelerationHistory.removeAt(0);
      }

      // Verificar si hay una sacudida
      if (accelerationHistory.length >= 3) {
        double maxAcceleration = accelerationHistory.reduce(max);
        double minAcceleration = accelerationHistory.reduce(min);
        double difference = maxAcceleration - minAcceleration;

        if (difference > shakeThreshold) {
          final now = DateTime.now();
          
          // Evitar múltiples detecciones muy seguidas (2 segundos)
          if (lastShakeTime != null && 
              now.difference(lastShakeTime!).inSeconds < 2) {
            return;
          }
          lastShakeTime = now;

          activateEmergencyProtocol(
            'SACUDIDA',
            'Intensidad: ${difference.toStringAsFixed(1)} (umbral: ${shakeThreshold.toInt()})'
          );
        }
      }
    }

    // Listeners del servicio
    service.on('stopService').listen((event) async {
      if (kDebugMode) {
        print('🛑 Deteniendo servicio de emergencia...');
      }
      await audioStreamSubscription?.cancel();
      await accelerometerSubscription?.cancel();
      monitoringTimer?.cancel();
      await recorder.stop();
      
      // Cancelar notificación persistente
      await flutterLocalNotificationsPlugin.cancel(3);
      
      service.stopSelf();
    });

    service.on('updateSettings').listen((event) {
      decibelThreshold = event?['decibelThreshold'] ?? 80.0;
      decibelEnabled = event?['decibelEnabled'] ?? true;
      shakeThreshold = event?['shakeThreshold'] ?? 15.0;
      shakeEnabled = event?['shakeEnabled'] ?? true;
      serviceEnabled = event?['serviceEnabled'] ?? true;
      
      if (kDebugMode) {
        print('⚙️ Configuración actualizada: Decibel=$decibelThreshold (${decibelEnabled ? 'ON' : 'OFF'}), Shake=$shakeThreshold (${shakeEnabled ? 'ON' : 'OFF'})');
      }
    });

    // Iniciar monitoreo de audio si está habilitado
    if (decibelEnabled && serviceEnabled) {
      try {
        if (await recorder.hasPermission()) {
          const config = RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 44100,
            numChannels: 1,
          );

          final stream = await recorder.startStream(config);
          
          audioStreamSubscription = stream.listen(
            processAudioData,
            onError: (error) {
              if (kDebugMode) {
                print('Error en stream de audio: $error');
              }
            },
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error iniciando monitoreo de audio: $e');
        }
      }
    }

    // Iniciar monitoreo de acelerómetro si está habilitado
    if (shakeEnabled && serviceEnabled) {
      try {
        accelerometerSubscription = accelerometerEventStream().listen(
          processAccelerometerData,
          onError: (error) {
            if (kDebugMode) {
              print('Error en acelerómetro: $error');
            }
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error iniciando monitoreo de acelerómetro: $e');
        }
      }
    }

    // Timer de monitoreo general
    monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!serviceEnabled) {
        service.invoke('setAsForeground', {
          'title': "B-Resol Protección",
          'content': "Servicio pausado",
        });
        return;
      }

      // Actualizar estado del servicio
      String status = '';
      if (decibelEnabled) status += '🔊 Audio ';
      if (shakeEnabled) status += '📳 Shake ';
      if (status.isEmpty) status = 'Inactivo';

      // Reducir la frecuencia de las notificaciones de estado
      if (DateTime.now().minute % 5 == 0 && DateTime.now().second == 0) {
        service.invoke('setAsForeground', {
          'title': "B-Resol Protección Activa",
          'content': "$status - Monitoreando emergencias...",
        });
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }
}
