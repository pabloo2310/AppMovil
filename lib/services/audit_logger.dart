import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AuditLogger {
  static Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/audit_logs.txt');
  }

  static Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[AUDIT] $timestamp: $message\n';

    // Imprimir en la consola
    print(logMessage);

    try {
      // Guardar en el archivo
      final logFile = await _getLogFile();
      await logFile.writeAsString(logMessage, mode: FileMode.append);
      print('Log guardado en: ${logFile.path}');
    } catch (e) {
      print('Error al guardar el log en el archivo: $e');
    }
  }
}
