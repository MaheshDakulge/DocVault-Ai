import 'package:dio/dio.dart';
import 'dio_interceptors.dart';

/// Singleton Dio client for all FastAPI communication.
/// Configure [baseUrl] via environment or build flavors.
class ApiClient {
  ApiClient._();

  // 🛑 Testing over public internet tunnel:
  // I started `npx localtunnel` in the background which exposes your local port 8000
  // to this public URL! This literally bypasses EVERY firewall/wifi issue.
  static const String _defaultDevBaseUrl = 'http://127.0.0.1:8000';
  static const String _devBaseUrl = String.fromEnvironment(
    'DOCSVAULT_API_BASE_URL',
    defaultValue: _defaultDevBaseUrl,
  );

  static final Dio _dio = _buildDio();

  /// The shared Dio instance — use this everywhere.
  static Dio get instance => _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _devBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120), // Gemini Vision needs time
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(),
      LoggingInterceptor(),
      RetryInterceptor(dio: dio),
    ]);

    return dio;
  }

  /// Convenience wrapper — parses the standard API envelope:
  /// `{ "status": "ok", "data": { ... } }`
  static Map<String, dynamic>? unwrap(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>?;
    }
    return null;
  }
}
