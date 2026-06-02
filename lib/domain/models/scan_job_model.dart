import 'dart:io';

enum ScanJobStatus {
  pending,          // Waiting to be picked up by the background worker
  scanning,         // Uploading to Gemini /scan endpoint
  readyForReview,   // Scan finished, waiting for user to confirm fields
  saving,           // Calling /scan/confirm and inserting into local DB
  saved,            // Fully processed and synced
  error,            // Failed at some point
}

class ScanJobModel {
  final String id;
  final File file;
  final ScanJobStatus status;
  final String? errorMessage;
  // This stores the response from /scan (the job_id and extracted fields)
  final Map<String, dynamic>? scanResult;

  const ScanJobModel({
    required this.id,
    required this.file,
    this.status = ScanJobStatus.pending,
    this.errorMessage,
    this.scanResult,
  });

  ScanJobModel copyWith({
    String? id,
    File? file,
    ScanJobStatus? status,
    String? errorMessage,
    Map<String, dynamic>? scanResult,
  }) {
    return ScanJobModel(
      id: id ?? this.id,
      file: file ?? this.file,
      status: status ?? this.status,
      errorMessage: errorMessage,
      scanResult: scanResult ?? this.scanResult,
    );
  }
}
