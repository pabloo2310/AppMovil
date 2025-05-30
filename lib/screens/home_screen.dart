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
  Timer? _uiUpdateTimer;
  OverlayEntry? _cancelOverlay;

  @override
  void initState() {
    super.initState();
    _fetchChuckNorrisJoke();
  }

  @override
  void dispose() {
    _cleanupProtocol();
    super.dispose();
  }

  void _cleanupProtocol() {
    print('HomeScreen: _cleanupProtocol called');
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;
    _removeCancelOverlay();
    _emergencyProtocol.dispose();
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
      // Obtener duración actualizada ANTES de iniciar
      final currentDuration = await _emergencyProtocol.getCurrentAudioDuration();
      
      setState(() {
        _isProtocolActive = true;
        _maxDuration = currentDuration;
        _recordingDuration = 0;
      });

      print('HomeScreen: UI state updated: _isProtocolActive = $_isProtocolActive');

      // Mostrar ventana de cancelación INMEDIATAMENTE
      _showCancelOverlay();

      // Iniciar protocolo en paralelo
      final result = await _emergencyProtocol.startEmergencyProtocol();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 ${result['message']}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Iniciar timer para actualizar UI
      _startUIUpdateTimer();

    } catch (e) {
      print('HomeScreen: Error al activar protocolo: $e');
      _resetProtocolState();
      _removeCancelOverlay();
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

  void _resetProtocolState() {
    print('HomeScreen: _resetProtocolState called');
    if (mounted) {
      setState(() {
        _isProtocolActive = false;
        _recordingDuration = 0;
        _maxDuration = 30;
      });
    }
    print('HomeScreen: UI state reset: _isProtocolActive = $_isProtocolActive');
  }

  Future<void> _handleProtocolCompletion() async {
    print('HomeScreen: _handleProtocolCompletion called');
    
    try {
      _removeCancelOverlay();
      _uiUpdateTimer?.cancel();
      _uiUpdateTimer = null;
      
      final result = await _emergencyProtocol.stopEmergencyProtocol();
      print('HomeScreen: stopEmergencyProtocol result: ${result['success']}');
      
      // --- CAMBIO AQUÍ ---
      // Siempre resetear el estado de la UI, aunque el protocolo ya esté inactivo
      if (mounted) {
        setState(() {
          _isProtocolActive = false;
          _recordingDuration = 0;
          _maxDuration = 30;
          if (result['recordingPath'] != null) {
            _lastRecordingPath = result['recordingPath'];
          }
        });
      }
      print('HomeScreen: Protocol completion handled, UI state: _isProtocolActive = $_isProtocolActive');

      // Mostrar feedback solo si hay mensaje
      if (mounted && result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success'] == true
                ? '✅ ${result['message']}'
                : 'ℹ️ Protocolo finalizado'),
            backgroundColor: result['success'] == true ? Colors.green : Colors.blue,
          ),
        );
      }

      if (mounted && result['recordingPath'] != null) {
        // Delay para asegurar que el estado se actualice antes del diálogo
        await Future.delayed(const Duration(milliseconds: 100));
        _showProtocolCompleteDialog(result['recordingPath'], result['data']);
      }
      // --- FIN DEL CAMBIO ---
    } catch (e) {
      print('HomeScreen: Error al completar protocolo: $e');
      _resetProtocolState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al completar protocolo: $e')),
        );
      }
    }
  }

  Future<void> _cancelProtocol() async {
    print('HomeScreen: _cancelProtocol called');
    
    try {
      _removeCancelOverlay();
      _uiUpdateTimer?.cancel();
      _uiUpdateTimer = null;
      
      final result = await _emergencyProtocol.cancelEmergencyProtocol();
      
      if (result['success']) {
        _resetProtocolState();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['message']}'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('HomeScreen: Error al cancelar protocolo: $e');
      _resetProtocolState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar protocolo: $e')),
        );
      }
    }
  }

  void _startUIUpdateTimer() {
    print('HomeScreen: _startUIUpdateTimer called');
    // Cancelar timer anterior si existe
    _uiUpdateTimer?.cancel();
    
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        print('HomeScreen: Widget not mounted, cancelling timer');
        timer.cancel();
        return;
      }

      // Verificar estado del servicio
      final serviceActive = _emergencyProtocol.isProtocolActive;
      print('HomeScreen: Timer tick - UI state: $_isProtocolActive, Service state: $serviceActive');

      if (_isProtocolActive && serviceActive) {
        setState(() {
          _recordingDuration = _emergencyProtocol.recordingDuration;
          _maxDuration = _emergencyProtocol.currentMaxDuration;
        });
      }

      // Si el protocolo se detuvo automáticamente en el servicio
      if (_isProtocolActive && !serviceActive) {
        print('HomeScreen: Service stopped but UI still active, handling completion');
        timer.cancel();
        _handleProtocolCompletion();
      }
    });
  }

  void _showCancelOverlay() {
    // Remover overlay anterior si existe
    _removeCancelOverlay();
    
    _cancelOverlay = OverlayEntry(
      builder: (context) => _CancelProtocolOverlay(
        onCancel: _cancelProtocol,
        onDismiss: _removeCancelOverlay,
      ),
    );
    
    if (mounted) {
      Overlay.of(context).insert(_cancelOverlay!);
    }
  }

  void _removeCancelOverlay() {
    if (_cancelOverlay != null) {
      _cancelOverlay!.remove();
      _cancelOverlay = null;
    }
  }

  void _showProtocolCompleteDialog(String path, Map<String, dynamic>? data) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Protocolo Completado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Protocolo ejecutado exitosamente:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('✅ Grabación de audio completada'),
            const Text('✅ Ubicación GPS obtenida'),
            const Text('✅ Datos enviados a Firebase'),
            const Text('✅ Timestamp registrado'),
            const SizedBox(height: 15),
            if (data != null) ...[
              Text('📍 Ubicación: ${data['latitud']?.toStringAsFixed(6)}, ${data['longitud']?.toStringAsFixed(6)}'),
              Text('👤 Usuario: ${data['nombre']}'),
              Text('📱 Teléfono: ${data['numero']}'),
              Text('🆔 ID: ${data['userId']}'),
              const SizedBox(height: 10),
            ],
            Text(
              'Audio: ${path.split('/').last}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen: Build called - _isProtocolActive = $_isProtocolActive');
    
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

class _CancelProtocolOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onDismiss;

  const _CancelProtocolOverlay({
    required this.onCancel,
    required this.onDismiss,
  });

  @override
  State<_CancelProtocolOverlay> createState() => _CancelProtocolOverlayState();
}

class _CancelProtocolOverlayState extends State<_CancelProtocolOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  int _countdown = 10;
  Timer? _countdownTimer;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isActive || !mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _countdown--;
      });
      
      // Solo cerrar cuando llegue exactamente a 0
      if (_countdown <= 0) {
        timer.cancel();
        _isActive = false;
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _isActive = false;
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ícono y título
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emergency,
                            size: 40,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        const Text(
                          '🚨 Protocolo de Emergencia Activado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA03E99),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        
                        Text(
                          'Se cerrará automáticamente en $_countdown segundos',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        
                        // Contador visual
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orange, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              '$_countdown',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Botón de cancelar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _isActive = false;
                              widget.onCancel();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'CANCELAR PROTOCOLO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        const Text(
                          'Si no cancelas, el protocolo continuará automáticamente',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
