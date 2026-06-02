import '../../domain/models/scheme_model.dart';
import '../remote/api_service.dart';
import '../remote/supabase_client.dart';

/// Scheme repository — fetches and caches government scheme data.
/// Source of truth: Supabase `govt_schemes` table.
/// Eligibility matching: FastAPI → Gemini.
class SchemeRepository {
  final ApiService _apiService;

  SchemeRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Fetch all available government schemes from Supabase.
  Future<List<SchemeModel>> getAllSchemes() async {
    try {
      final response = await SupabaseClientWrapper.client
          .from('govt_schemes')
          .select()
          .order('name');

      return (response as List)
          .map((e) => SchemeModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Run AI eligibility check — sends all user document fields to the
  /// FastAPI eligibility engine, which uses Gemini to match schemes.
  /// Requires internet. Returns schemes with [isEligible] set.
  Future<List<SchemeModel>> checkEligibility(
    List<Map<String, dynamic>> contextFields,
  ) async {
    final result = await _apiService.checkEligibility(contextFields);
    final schemes = (result['schemes'] as List?) ?? [];
    return schemes
        .map((e) => SchemeModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
