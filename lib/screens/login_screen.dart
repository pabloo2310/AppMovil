import 'package:app_bullying/widgets/widgets.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: LoginContainer1(
        child: LoginAreaForm(
          textTitle: 'Login',
          textFinalButton: 'No tienes una cuenta?, registrate',
          path: 'register',
          textButton: 'acceder',
          pathButton: 'home',
        ),
      ),
    );
  }
}
