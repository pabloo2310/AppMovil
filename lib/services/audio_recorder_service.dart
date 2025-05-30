import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';


class AudioRecorderService {
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0; // en segundos
  final int _maxRecordingDuration = 30; // máximo 30 segundos
  int _currentMaxDuration = 30;

  Future<void> init() async {
    _audioRecorder = FlutterSoundRecorder();
    
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Permiso de micrófono denegado');
    }
    
    await _audioRecorder!.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<void> dispose() async {
    if (_isRecorderInitialized) {
      await _audioRecorder!.closeRecorder();
      _audioRecorder = null;
      _isRecorderInitialized = false;
    }
    _stopTimer();
  }

  Future<void> startRecording({int? duration}) async {
    if (!_isRecorderInitialized) {
      await init();
    }

    if (_isRecording) {
      return;
    }

    final int maxDuration = duration ?? _maxRecordingDuration;
    _recordingDuration = 0;

    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    _recordingPath = '${directory.path}/recording_$formattedDate.aac';

    await _audioRecorder!.startRecorder(
      toFile: _recordingPath,
      codec: Codec.aacADTS,
    );

    _isRecording = true;
    _startTimer(maxDuration);
    _currentMaxDuration = maxDuration;
  }

  Future<String?> stopRecording() async {
    if (!_isRecorderInitialized || !_isRecording) {
      return null;
    }
    
    _stopTimer();
    await _audioRecorder!.stopRecorder();
    _isRecording = false;
    
    return _recordingPath;
  }

  void _startTimer(int maxDuration) {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      if (_recordingDuration >= maxDuration) {
        stopRecording();
      }
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;
  int get maxRecordingDuration => _maxRecordingDuration;
  int get currentMaxDuration => _currentMaxDuration;

  Future<void> saveSettings(settingsRef) async {
    await settingsRef.set({
      'recordingDuration': _recordingDuration,
      'quality': 'Media', // Siempre Media
    });
  }
}
