import 'dart:io';
import 'package:dio/dio.dart';

class FreeFileUploadService {
  static final Dio _dio = Dio();

  // Configuración de servicios
  static final List<UploadServiceConfig> _services = [
    UploadServiceConfig(
      name: 'File.io',
      url: 'https://file.io',
      formDataBuilder: (file) => FormData.fromMap({
        'file': file,
      }),
      responseValidator: (response) {
        return response.statusCode == 200 && 
               response.data['success'] == true;
      },
      urlExtractor: (response) => response.data['link'],
      description: 'Temporal (1 descarga o 14 días)',
    ),
    UploadServiceConfig(
      name: '0x0.st',
      url: 'https://0x0.st',
      formDataBuilder: (file) => FormData.fromMap({
        'file': file,
      }),
      responseValidator: (response) {
        return response.statusCode == 200 && 
               response.data.toString().trim().startsWith('https://0x0.st/');
      },
      urlExtractor: (response) => response.data.toString().trim(),
      description: 'Temporal (365 días)',
    ),
    UploadServiceConfig(
      name: 'Catbox.moe',
      url: 'https://catbox.moe/user/api.php',
      formDataBuilder: (file) => FormData.fromMap({
        'reqtype': 'fileupload',
        'fileToUpload': file,
      }),
      responseValidator: (response) {
        return response.statusCode == 200 && 
               response.data.toString().trim().startsWith('https://files.catbox.moe/');
      },
      urlExtractor: (response) => response.data.toString().trim(),
      description: 'Permanente',
    ),
  ];

  /// Método principal que intenta subir a múltiples servicios gratuitos
  static Future<String> uploadAudioFile(String filePath) async {
    print('🚀 Iniciando subida de audio con servicios gratuitos...');

    for (int i = 0; i < _services.length; i++) {
      final service = _services[i];
      try {
        print('🔄 Intentando subir con ${service.name} (${service.description})...');
        final url = await _uploadToService(filePath, service);
        print('✅ Subida exitosa con ${service.name}: $url');
        return url;
      } catch (e) {
        print('❌ Falló ${service.name}: $e');
        if (i == _services.length - 1) {
          // Si es el último servicio, lanzar la excepción
          throw Exception('Todos los servicios de subida fallaron. Último error: $e');
        }
        // Continuar con el siguiente servicio
        continue;
      }
    }

    throw Exception('No se pudo subir el archivo a ningún servicio');
  }

  /// Método genérico para subir a cualquier servicio
  static Future<String> _uploadToService(String filePath, UploadServiceConfig config) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('El archivo no existe: $filePath');
      }

      print('📤 Subiendo archivo a ${config.name}: ${file.path}');

      // Crear el archivo multipart
      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: 'emergency_audio_${DateTime.now().millisecondsSinceEpoch}.aac',
      );

      // Crear FormData usando el builder específico del servicio
      final formData = config.formDataBuilder(multipartFile);

      // Realizar petición POST
      final response = await _dio.post(
        config.url,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      // Validar respuesta usando el validador específico del servicio
      if (config.responseValidator(response)) {
        final downloadUrl = config.urlExtractor(response);
        print('✅ Archivo subido exitosamente a ${config.name}: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Respuesta inválida de ${config.name}: ${response.data}');
      }
    } catch (e) {
      print('❌ Error subiendo a ${config.name}: $e');
      throw Exception('Error subiendo archivo a ${config.name}: $e');
    }
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

  /// Método para obtener información de todos los servicios disponibles
  static List<Map<String, String>> getAvailableServices() {
    return _services.map((service) => {
      'name': service.name,
      'description': service.description,
      'url': service.url,
    }).toList();
  }
}

/// Clase de configuración para cada servicio de subida
class UploadServiceConfig {
  final String name;
  final String url;
  final String description;
  final FormData Function(MultipartFile file) formDataBuilder;
  final bool Function(Response response) responseValidator;
  final String Function(Response response) urlExtractor;

  const UploadServiceConfig({
    required this.name,
    required this.url,
    required this.description,
    required this.formDataBuilder,
    required this.responseValidator,
    required this.urlExtractor,
  });
}
