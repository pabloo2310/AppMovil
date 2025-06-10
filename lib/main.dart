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

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({required this.initialRoute, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'B-Resol',
      initialRoute: initialRoute,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      theme: MyTheme.myTheme,
      builder: (context, child) {
        // Registrar el contexto global para el servicio de emergencia
        // Usar el contexto del navigatorKey que siempre está disponible
        if (navigatorKey.currentContext != null) {
          EmergencyProtocolService().setGlobalContext(navigatorKey.currentContext);
        }
        return child!;
      },
    );
  }
}
