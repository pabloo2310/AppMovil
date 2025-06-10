import 'package:flutter/material.dart';
import 'package:app_bullying/screens/screens.dart';

class AppRoutes {
  static const initialRoute = 'login';
  
  static Map<String, Widget Function(BuildContext)> routes = {
    'login': (BuildContext context) => const LoginScreen(),
    'register': (BuildContext context) => const RegisterScreen(),
    'home': (BuildContext context) => const HomeScreen(),
    'settings': (BuildContext context) => const SettingsScreen(),
    'voice_commands': (BuildContext context) => const VoiceCommandsScreen(title: 'Voice Commands'),
    'emergency_contacts': (BuildContext context) => const EmergencyContactsScreen(),
    'decibel_settings': (BuildContext context) => const DecibelSettingsScreen(),
    'audio_settings': (BuildContext context) => const AudioSettingsScreen(),
    'shake_settings': (BuildContext context) => const ShakeSettingsScreen(),
    'error': (BuildContext context) => const ErrorScreen(),
    'edit_profile': (BuildContext context) => const EditProfileScreen(),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => const ErrorScreen(),
    );
  }
}
