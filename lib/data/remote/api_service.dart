import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../core/network/api_client.dart';

/// Handles communication with the FastAPI backend.
class ApiService {
  final Dio _dio;

  ApiService({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  static String get baseUrl => ApiClient.instance.options.baseUrl;

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Unexpected server response.');
  }

  String _readError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return e.message ?? fallback;
  }

  Future<Map<String, dynamic>> scanDocument(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: path.basename(imageFile.path),
      ),
    });

    try {
      final response = await _dio.post(
        '/scan',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Scan failed: ${_readError(e, 'Unable to reach backend.')}',
      );
    }
  }

  Future<Map<String, dynamic>> confirmScan({
    required String jobId,
    required String category,
    required List<Map<String, dynamic>> fields,
  }) async {
    try {
      final response = await _dio.post('/scan/confirm', data: {
        'job_id': jobId,
        'category': category,
        'fields': fields,
      });
      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Confirm scan failed: ${_readError(e, 'Unable to save document.')}',
      );
    }
  }

  Future<String?> getSignedUrl(String docId) async {
    try {
      final response = await _dio.get('/documents/$docId/signed-url');
      final data = _asMap(response.data);
      if (data['url'] != null) {
        return data['url'] as String;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Signed URL failed: ${e.message}');
      return null;
    }
  }

  Future<Map<String, dynamic>> searchDocuments(String query) async {
    try {
      final response = await _dio.get('/search', queryParameters: {'q': query});
      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Search failed: ${_readError(e, 'Unable to search documents.')}',
      );
    }
  }

  Future<Map<String, dynamic>> chatAssistant(
    String question,
    List<Map<String, dynamic>> contextFields,
  ) async {
    try {
      final response = await _dio.post('/assistant/chat', data: {
        'message': question,
        'conversation_history': const [],
      });
      return _asMap(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Chat failed: ${_readError(e, 'Unable to contact assistant.')}',
      );
    }
  }

  Future<Map<String, dynamic>> checkEligibility(List<Map<String, dynamic>> contextFields) async {
    try {
      final response = await _dio.get('/assistant/eligibility');
      final data = _asMap(response.data);
      final rawSchemes = (data['eligible_schemes'] as List?) ?? const [];
      final mappedSchemes = rawSchemes
          .whereType<Map>()
          .map((scheme) {
            final item = Map<String, dynamic>.from(scheme);
            return <String, dynamic>{
              'name': item['scheme_name'] ?? 'Scheme',
              'benefit': item['benefit'] ?? item['description'] ?? '',
              'level': item['level'] ?? 'Central',
              'is_eligible': true,
              'eligibility_reason':
                  item['why_eligible'] ?? item['description'] ?? '',
              'apply_url': item['apply_url'],
              'description': item['description'],
              'state': item['state'],
            };
          })
          .toList();

      return {
        ...data,
        'schemes': mappedSchemes,
      };
    } on DioException catch (e) {
      throw Exception(
        'Eligibility check failed: ${_readError(e, 'Unable to check eligibility.')}',
      );
    }
  }
}
