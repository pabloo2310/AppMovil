import 'package:flutter/material.dart';
import 'package:app_bullying/routes/app_routes.dart';
import 'package:app_bullying/themes/my_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:app_bullying/services/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    name: 'AppBullying',
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize background decibel service
  await BackgroundDecibelService.initializeService();

  // Initialize emergency background manager
  await EmergencyBackgroundManager().initialize();

  ShakeDetectorService().init(
    onShakeDetected: () {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('¡Sacudida detectada!'),
          backgroundColor: Colors.deepOrange,
          duration: Duration(seconds: 2),
        ),
      );
    },
  );

  final user = FirebaseAuth.instance.currentUser;

  runApp(MyApp(initialRoute: user != null ? 'home' : 'login'));
}

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({required this.initialRoute, super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final DecibelDetectorService _decibelService = DecibelDetectorService();
  final EmergencyProtocolService _emergencyService = EmergencyProtocolService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGlobalServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _decibelService.dispose();
    super.dispose();
  }

  Future<void> _initializeGlobalServices() async {
    try {
      // Inicializar servicio de decibelios globalmente
      await _decibelService.init(
        onDecibelUpdate: (decibel) {
          // Opcional: podrías mostrar un indicador global aquí
        },
        onHighDecibelDetected: () {
          // Solo mostrar notificación si no hay protocolo activo
          if (!_emergencyService.isProtocolActive) {
            rootScaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  '🚨 Nivel alto detectado: ${_decibelService.currentDecibel.toStringAsFixed(1)} dB',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      );

      // Cargar configuración y iniciar si está habilitado
      await _loadAndStartDecibelService();
      
      print('✅ Servicios globales inicializados');
    } catch (e) {
      print('❌ Error inicializando servicios globales: $e');
    }
  }

  Future<void> _loadAndStartDecibelService() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Verificar si el servicio debe estar activo
        final shouldStart = await _decibelService.shouldAutoStart();
        if (shouldStart) {
          await _decibelService.startRecording();
          print('🔊 Servicio de decibelios iniciado automáticamente');
        }
      } catch (e) {
        print('Error iniciando servicio de decibelios: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App volvió al primer plano
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        // App fue a segundo plano
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        // App se está cerrando
        _decibelService.dispose();
        break;
      default:
        break;
    }
  }

  Future<void> _handleAppResumed() async {
    try {
      // Verificar si debe reanudar el servicio de decibelios
      final shouldStart = await _decibelService.shouldAutoStart();
      if (shouldStart && !_decibelService.isRecording) {
        await _decibelService.startRecording();
        print('🔊 Servicio de decibelios reanudado');
      }
    } catch (e) {
      print('Error reanudando servicios: $e');
    }
  }

  Future<void> _handleAppPaused() async {
    // Verificar si hay servicio de segundo plano activo
    final backgroundManager = EmergencyBackgroundManager();
    final status = await backgroundManager.getServiceStatus();
    
    if (status['isRunning'] == true) {
      // Si hay servicio de segundo plano, detener el de primer plano
      if (_decibelService.isRecording) {
        await _decibelService.stopRecording();
        print('🔊 Servicio de primer plano pausado (segundo plano activo)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'B-Resol',
      initialRoute: widget.initialRoute,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      theme: MyTheme.myTheme,
      builder: (context, child) {
        // Registrar el contexto global para el servicio de emergencia
        if (navigatorKey.currentContext != null) {
          _emergencyService.setGlobalContext(navigatorKey.currentContext);
        }
        return child!;
      },
    );
  }
}
