import 'package:flutter/material.dart';
import '../widgets.dart';

class LoginContainer1 extends StatelessWidget {
  final Widget child;
  const LoginContainer1({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          const LoginContainer2(),
          SafeArea(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              child: const Icon(
                Icons.person_pin_rounded,
                color: Colors.white,
                size: 100,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
