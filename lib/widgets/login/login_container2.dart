import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/widgets.dart';

class LoginContainer2 extends StatelessWidget {
  const LoginContainer2({super.key});

  @override
  Widget build(BuildContext context) {
    final sizeScreen = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      height: sizeScreen.height * 0.4,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF5A623), // Naranja
            Color(0xFFA03E99), // Morado
          ],
        ),
      ),
      child: const Stack(
        children: [
          Positioned(top: 90, left: 30, child: Buble()),
          Positioned(top: -40, left: -30, child: Buble()),
          Positioned(top: -50, left: -20, child: Buble()),
          Positioned(top: 120, right: 20, child: Buble()),
          Positioned(top: 20, right: 80, child: Buble()),
          Positioned(top: -50, right: -20, child: Buble()),
        ],
      ),
    );
  }
}
