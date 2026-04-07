import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/security/secure_storage.dart';

/// Handles communication with the FastAPI backend.
/// In development, using local IP. In production, points to Cloud Run.
class ApiService {
  // Use your local IP for physical device testing, or 10.0.2.2 for emulator
  static const String baseUrl = 'http://192.168.1.100:8000'; 
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 40), // Gemini Vision can take time
        )) {
    // Inject JWT automatically if present
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.getJwt();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  /// Send image to FastAPI /scan endpoint (Gemini Flash Vision)
  Future<Map<String, dynamic>> scanDocument(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'scan.jpg',
      ),
    });

    try {
      final response = await _dio.post('/scan', data: formData);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Scan failed: ${e.message}');
    }
  }

  /// Query the generative AI assistant over existing context fields
  Future<Map<String, dynamic>> chatAssistant(String question, List<Map<String, dynamic>> contextFields) async {
    try {
      final response = await _dio.post('/assistant/chat', data: {
        'question': question,
        'context_fields': contextFields,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Chat failed: ${e.message}');
    }
  }

  /// Run eligibility engine mapping over documents
  Future<Map<String, dynamic>> checkEligibility(List<Map<String, dynamic>> contextFields) async {
    try {
      final response = await _dio.post('/assistant/eligibility', data: {
        'question': 'Check my eligibility', 
        'context_fields': contextFields,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Eligibility check failed: ${e.message}');
    }
  }
}
