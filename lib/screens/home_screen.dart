import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:app_bullying/widgets/button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_bullying/services/emergency_protocol_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentJoke = 'Cargando frase...';
  bool _isLoading = true;

  // Emergency Protocol Service
  final EmergencyProtocolService _emergencyProtocol = EmergencyProtocolService();
  bool _isProtocolActive = false;
  String? _lastRecordingPath;
  int _recordingDuration = 0;
  int _maxDuration = 30;

  @override
  void initState() {
    super.initState();
    _fetchChuckNorrisJoke();
    
    // Registrar listener para cambios de estado del protocolo
    _emergencyProtocol.addStateChangeListener(_onProtocolStateChanged);
    
    // Sincronizar estado inicial
    _syncProtocolState();
  }

  @override
  void dispose() {
    // Remover listener
    _emergencyProtocol.removeStateChangeListener(_onProtocolStateChanged);
    super.dispose();
  }

  void _onProtocolStateChanged() {
    if (mounted) {
      _syncProtocolState();
    }
  }

  void _syncProtocolState() {
    final serviceActive = _emergencyProtocol.isProtocolActive;
    final serviceDuration = _emergencyProtocol.recordingDuration;
    final serviceMaxDuration = _emergencyProtocol.currentMaxDuration;

    if (_isProtocolActive != serviceActive || 
        _recordingDuration != serviceDuration || 
        _maxDuration != serviceMaxDuration) {
      setState(() {
        _isProtocolActive = serviceActive;
        _recordingDuration = serviceDuration;
        _maxDuration = serviceMaxDuration;
      });
    }
  }

  Future<void> _fetchChuckNorrisJoke() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('https://api.chucknorris.io/jokes/random'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentJoke = data['value'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentJoke = 'Error al cargar la frase. Inténtalo de nuevo.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentJoke = 'Error de conexión. Verifica tu internet.';
        _isLoading = false;
      });
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('login');
    }
  }

  Future<void> _activateEmergencyProtocol() async {
    print('HomeScreen: _activateEmergencyProtocol called, current UI state: $_isProtocolActive');
    
    if (_isProtocolActive) {
      print('HomeScreen: Protocolo ya está activo en UI, ignorando nueva activación');
      return;
    }

    print('HomeScreen: Iniciando protocolo de emergencia...');

    try {
      // Registrar el contexto actual antes de iniciar
      _emergencyProtocol.setGlobalContext(context);
      
      // Iniciar protocolo
      final result = await _emergencyProtocol.startEmergencyProtocol();
      
      print('HomeScreen: Protocolo iniciado exitosamente');

    } catch (e) {
      print('HomeScreen: Error al activar protocolo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al activar protocolo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen: Build called - _isProtocolActive = $_isProtocolActive');
    
    // Actualizar contexto global cada vez que se construye
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emergencyProtocol.setGlobalContext(context);
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chuck Norris 🙏',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF5A623),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: CardContainer(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFA03E99),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Frase de Chuck Norris',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA03E99),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _currentJoke,
                                style: const TextStyle(fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                            CustomButton(
                              text: 'Nueva frase',
                              icon: Icons.refresh,
                              onPressed: _fetchChuckNorrisJoke,
                            ),
                          ],
                        ),
                ),
              ),
              if (_isProtocolActive)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emergency,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '🚨 Protocolo: ${_formatDuration(_recordingDuration)} / ${_formatDuration(_maxDuration)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón de protocolo - SOLO ACTIVAR (sin detener)
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: FloatingActionButton(
                      heroTag: "emergency_button", // Tag único
                      onPressed: _isProtocolActive ? null : _activateEmergencyProtocol,
                      backgroundColor: _isProtocolActive ? Colors.grey : const Color(0xFFA03E99),
                      child: const Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Botón de configuración - SOLO ÍCONO DE TUERCA
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: FloatingActionButton(
                      heroTag: "settings_button", // Tag único
                      onPressed: () => Navigator.pushNamed(context, 'settings'),
                      backgroundColor: const Color(0xFFF5A623),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              if (_lastRecordingPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Última grabación: ${_lastRecordingPath!.split('/').last}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
