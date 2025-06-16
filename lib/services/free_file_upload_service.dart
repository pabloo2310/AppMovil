import 'dart:io';
import 'package:dio/dio.dart';

class FreeFileUploadService {
  static final Dio _dio = Dio();

  /// Sube un archivo a File.io (gratuito, temporal)
  /// Los archivos se eliminan después de 1 descarga o 14 días
  static Future<String> uploadToFileIO(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('El archivo no existe: $filePath');
      }

      print('📤 Subiendo archivo a File.io: ${file.path}');

      // Crear FormData para la subida
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'emergency_audio_${DateTime.now().millisecondsSinceEpoch}.aac',
        ),
      });

      // Subir a File.io
      final response = await _dio.post(
        'https://file.io',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final downloadUrl = response.data['link'];
        print('✅ Archivo subido exitosamente a File.io: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Error en la respuesta de File.io: ${response.data}');
      }
    } catch (e) {
      print('❌ Error subiendo a File.io: $e');
      throw Exception('Error subiendo archivo a File.io: $e');
    }
  }

  /// Sube un archivo a 0x0.st (gratuito, temporal, respaldo)
  /// Los archivos se eliminan después de 365 días
  static Future<String> uploadTo0x0st(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('El archivo no existe: $filePath');
      }

      print('📤 Subiendo archivo a 0x0.st: ${file.path}');

      // Crear FormData para la subida
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'emergency_audio_${DateTime.now().millisecondsSinceEpoch}.aac',
        ),
      });

      // Subir a 0x0.st
      final response = await _dio.post(
        'https://0x0.st',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final downloadUrl = response.data.toString().trim();
        if (downloadUrl.startsWith('https://0x0.st/')) {
          print('✅ Archivo subido exitosamente a 0x0.st: $downloadUrl');
          return downloadUrl;
        } else {
          throw Exception('Respuesta inválida de 0x0.st: $downloadUrl');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      print('❌ Error subiendo a 0x0.st: $e');
      throw Exception('Error subiendo archivo a 0x0.st: $e');
    }
  }

  /// Sube un archivo a Catbox.moe (gratuito, permanente)
  static Future<String> uploadToCatbox(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('El archivo no existe: $filePath');
      }

      print('📤 Subiendo archivo a Catbox.moe: ${file.path}');

      // Crear FormData para la subida
      final formData = FormData.fromMap({
        'reqtype': 'fileupload',
        'fileToUpload': await MultipartFile.fromFile(
          file.path,
          filename: 'emergency_audio_${DateTime.now().millisecondsSinceEpoch}.aac',
        ),
      });

      // Subir a Catbox.moe
      final response = await _dio.post(
        'https://catbox.moe/user/api.php',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final downloadUrl = response.data.toString().trim();
        if (downloadUrl.startsWith('https://files.catbox.moe/')) {
          print('✅ Archivo subido exitosamente a Catbox.moe: $downloadUrl');
          return downloadUrl;
        } else {
          throw Exception('Respuesta inválida de Catbox.moe: $downloadUrl');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      print('❌ Error subiendo a Catbox.moe: $e');
      throw Exception('Error subiendo archivo a Catbox.moe: $e');
    }
  }

  /// Método principal que intenta subir a múltiples servicios gratuitos
  static Future<String> uploadAudioFile(String filePath) async {
    print('🚀 Iniciando subida de audio con servicios gratuitos...');

    // Lista de servicios a intentar en orden de preferencia
    final List<Future<String> Function()> uploadMethods = [
      () => uploadToFileIO(filePath),
      () => uploadTo0x0st(filePath),
      () => uploadToCatbox(filePath),
    ];

    final List<String> serviceNames = ['File.io', '0x0.st', 'Catbox.moe'];

    for (int i = 0; i < uploadMethods.length; i++) {
      try {
        print('🔄 Intentando subir con ${serviceNames[i]}...');
        final url = await uploadMethods[i]();
        print('✅ Subida exitosa con ${serviceNames[i]}: $url');
        return url;
      } catch (e) {
        print('❌ Falló ${serviceNames[i]}: $e');
        if (i == uploadMethods.length - 1) {
          // Si es el último servicio, lanzar la excepción
          throw Exception('Todos los servicios de subida fallaron. Último error: $e');
        }
        // Continuar con el siguiente servicio
        continue;
      }
    }

    throw Exception('No se pudo subir el archivo a ningún servicio');
  }

  /// Método para verificar si un archivo es válido para subir
  static bool isValidAudioFile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      final sizeInBytes = file.lengthSync();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      
      // Verificar que el archivo no sea demasiado grande (máximo 100MB)
      if (sizeInMB > 100) {
        print('⚠️ Archivo demasiado grande: ${sizeInMB.toStringAsFixed(2)} MB');
        return false;
      }
      
      // Verificar que el archivo no esté vacío
      if (sizeInBytes == 0) {
        print('⚠️ Archivo vacío');
        return false;
      }
      
      print('✅ Archivo válido: ${sizeInMB.toStringAsFixed(2)} MB');
      return true;
    } catch (e) {
      print('❌ Error validando archivo: $e');
      return false;
    }
  }
}
