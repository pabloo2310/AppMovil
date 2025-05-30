import 'package:app_bullying/widgets/widgets.dart';
import 'package:flutter/material.dart';

class LoginAreaForm extends StatelessWidget {
  final String textTitle;
  final String textFinalButton;
  final String path;
  final String textButton;
  final String pathButton;
  
  const LoginAreaForm({
    super.key,
    required this.textTitle,
    required this.textFinalButton,
    required this.path,
    required this.textButton,
    required this.pathButton,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 150),
          CardContainer(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  textTitle, 
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFFA03E99),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                LoginForm(textButton: textButton, pathButton: pathButton),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, path),
                  child: Text(
                    textFinalButton,
                    style: const TextStyle(
                      color: Color(0xFFF5A623),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
