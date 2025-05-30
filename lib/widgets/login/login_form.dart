import 'package:flutter/material.dart';
import '../../ui/input_decorations.dart';
import '../../app/mobile/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginForm extends StatefulWidget {
  final String textButton;
  final String pathButton;
  
  const LoginForm({
    super.key, 
    required this.textButton, 
    required this.pathButton,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (widget.pathButton == 'home') {
        // Login utilizando el AuthService
        await authService.value.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Register utilizando el AuthService
        await authService.value.createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, widget.pathButton);
      }
    } on FirebaseAuthException catch (e) {
      
      // Mensajes de error más específicos
      String errorMsg;
      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'No existe una cuenta con este email';
          break;
        case 'wrong-password':
          errorMsg = 'Contraseña incorrecta';
          break;
        case 'invalid-email':
          errorMsg = 'El formato del email no es válido';
          break;
        case 'user-disabled':
          errorMsg = 'Esta cuenta ha sido deshabilitada';
          break;
        case 'email-already-in-use':
          errorMsg = 'Este email ya está registrado';
          break;
        case 'operation-not-allowed':
          errorMsg = 'Operación no permitida';
          break;
        case 'weak-password':
          errorMsg = 'La contraseña es demasiado débil';
          break;
        case 'network-request-failed':
          errorMsg = 'Error de conexión. Verifica tu internet';
          break;
        default:
          errorMsg = 'Error: ${e.message}';
      }
      
      setState(() {
        _errorMessage = errorMsg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecorations.authInputDecoration(
              hinText: 'Ingrese su correo',
              labelText: 'Email',
              prefixIcon: Icons.email,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingrese su email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Por favor ingrese un email válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),
          TextFormField(
            controller: _passwordController,
            autocorrect: false,
            obscureText: true,
            keyboardType: TextInputType.text,
            decoration: InputDecorations.authInputDecoration(
              hinText: '**********',
              labelText: 'Password',
              prefixIcon: Icons.lock_outlined,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingrese su contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
          
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
            
          const SizedBox(height: 30),
          
          MaterialButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            disabledColor: Colors.grey,
            color: const Color(0xFFA03E99),
            elevation: 0,
            onPressed: _isLoading ? null : _submitForm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 10),
              child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.textButton,
                    style: const TextStyle(color: Colors.white),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
