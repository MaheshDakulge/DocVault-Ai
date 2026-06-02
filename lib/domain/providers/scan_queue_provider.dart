import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/remote/api_service.dart';
import '../models/scan_job_model.dart';

class ScanQueueNotifier extends StateNotifier<List<ScanJobModel>> {
  final ApiService _apiService;
  bool _isProcessing = false;

  ScanQueueNotifier(this._apiService) : super([]);

  /// Add new files (images/PDFs) to the processing queue
  void addFiles(List<File> files) {
    final newJobs = files.map((f) => ScanJobModel(
      id: const Uuid().v4(),
      file: f,
      status: ScanJobStatus.pending,
    )).toList();
    
    state = [...state, ...newJobs];
    _processNext();
  }

  void _updateJob(String id, ScanJobModel Function(ScanJobModel) updateCb) {
    state = [
      for (final job in state)
        if (job.id == id) updateCb(job) else job
    ];
  }

  /// Sequential background processor
  Future<void> _processNext() async {
    if (_isProcessing) return;

    final pendingIndex = state.indexWhere((j) => j.status == ScanJobStatus.pending);
    if (pendingIndex == -1) return; // Queue empty

    _isProcessing = true;
    final job = state[pendingIndex];

    try {
      _updateJob(job.id, (j) => j.copyWith(status: ScanJobStatus.scanning));

      // Call Gemini backend
      final apiResponseData = await _apiService.scanDocument(job.file);

      _updateJob(job.id, (j) => j.copyWith(
        status: ScanJobStatus.readyForReview,
        scanResult: apiResponseData,
      ));
    } catch (e) {
      _updateJob(job.id, (j) => j.copyWith(
        status: ScanJobStatus.error,
        errorMessage: e.toString(),
      ));
    } finally {
      _isProcessing = false;
      // Loop again if more jobs are pending
      _processNext();
    }
  }

  /// User confirms the fields. Save to backend and local.
  Future<Map<String, dynamic>> confirmJob(
    String id,
    String category,
    List<Map<String, dynamic>> editedFields,
  ) async {
    final job = state.firstWhere((j) => j.id == id);
    if (job.status != ScanJobStatus.readyForReview) {
      throw StateError('Scan job is not ready for confirmation.');
    }

    _updateJob(job.id, (j) => j.copyWith(status: ScanJobStatus.saving));

    try {
      final backendJobId = job.scanResult!['job_id'] as String;

      // 1. Confirm to backend (Creates row in remote Supabase)
      final confirmedDocument = await _apiService.confirmScan(
        jobId: backendJobId,
        category: category,
        fields: editedFields,
      );
      _updateJob(job.id, (j) => j.copyWith(status: ScanJobStatus.saved));
      return confirmedDocument;
    } catch (e) {
      _updateJob(job.id, (j) => j.copyWith(
        status: ScanJobStatus.error,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  /// Clear finished/errored jobs from the list
  void removeJob(String id) {
    state = state.where((job) => job.id != id).toList();
  }
}

final scanQueueProvider = StateNotifierProvider<ScanQueueNotifier, List<ScanJobModel>>((ref) {
  return ScanQueueNotifier(ApiService());
});
