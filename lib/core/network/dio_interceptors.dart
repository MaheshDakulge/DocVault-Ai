import 'package:dio/dio.dart';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

/// JWT Auth Interceptor — injects Bearer token on every request.
/// Uses the LIVE Supabase session (auto-refreshed) so the token is never stale.
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Always use the live session token — Supabase auto-refreshes it
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token truly expired — clear stored credentials
      Supabase.instance.client.auth.signOut();
    }
    handler.next(err);
  }
}

/// Pretty-print logger — only active in debug mode.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    dev.log(
      '→ ${options.method} ${options.path}',
      name: 'DocsVault/HTTP',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    dev.log(
      '← ${response.statusCode} ${response.requestOptions.path}',
      name: 'DocsVault/HTTP',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    dev.log(
      '✗ ${err.response?.statusCode} ${err.requestOptions.path}: ${err.message}',
      name: 'DocsVault/HTTP',
      error: err,
    );
    handler.next(err);
  }
}

/// Retry interceptor — retries idempotent requests up to [maxRetries] times
/// on network errors (connection timeout, no internet).
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({required this.dio, this.maxRetries = 2});

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extra = err.requestOptions.extra;
    final retryCount = (extra['retry_count'] as int?) ?? 0;

    final isNetworkError = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    final isIdempotent =
        err.requestOptions.method == 'GET' ||
        err.requestOptions.method == 'PUT';

    if (isNetworkError && isIdempotent && retryCount < maxRetries) {
      err.requestOptions.extra['retry_count'] = retryCount + 1;
      await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        // Fall through to original error
      }
    }
    handler.next(err);
  }
}
