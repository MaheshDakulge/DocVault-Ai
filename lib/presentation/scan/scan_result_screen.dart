import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';
import '../../core/security/sha256_hasher.dart';
import '../../domain/models/scan_job_model.dart';
import '../../domain/providers/scan_queue_provider.dart';
import '../../domain/providers/database_providers.dart';
import '../../data/local/database.dart';
import '../common_widgets/vault_app_bar.dart';
import 'widgets/scan_loading_overlay.dart';
import 'widgets/field_review_card.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? scanData; // Optional, kept for legacy router compatibility
  const ScanResultScreen({super.key, this.scanData});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  // Mutable field values for the CURRENT job being reviewed
  Map<String, dynamic> _editedFields = {};
  String? _currentJobId;
  bool _isSaving = false;

  void _initFields(ScanJobModel job) {
    if (_currentJobId == job.id) return; // already init
    _currentJobId = job.id;
    
    final rawFields = (job.scanResult?['fields'] as List<dynamic>?) ?? [];
    
    // Convert array of {"label": "...", "value": "..."} to a map for easy editing
    final map = <String, dynamic>{};
    for (var f in rawFields) {
      if (f is Map) {
        map[f['label'].toString()] = f['value'];
      }
    }
    _editedFields = map;
  }

  Future<void> _saveToVault(ScanJobModel job) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Cache context-dependent refs BEFORE any await
    final messenger = ScaffoldMessenger.of(context);
    final queueNotifier = ref.read(scanQueueProvider.notifier);

    try {
      final category = job.scanResult?['category'] as String? ?? 'Other';
      
      // Convert edited map back to array of fields for backend
      final fieldsList = _editedFields.entries
          .map((e) => {'label': e.key, 'value': e.value})
          .toList();

      // 1. Confirm with backend (creates remote record)
      final confirmedDocument = await queueNotifier
          .confirmJob(job.id, category, fieldsList);

      // 2. Save locally for instant access (offline-first architecture)
      final imageBytes = await job.file.readAsBytes();
      final hash = Sha256Hasher.hashBytes(imageBytes);
      final docId = (confirmedDocument['id'] ??
                  confirmedDocument['document_id'] ??
                  job.scanResult?['document_id'])
              ?.toString() ??
          const Uuid().v4();

      final docDao = ref.read(documentDaoProvider);
      final fieldDao = ref.read(fieldDaoProvider);

      await docDao.insertDocument(
        DocumentsCompanion(
          id: drift.Value(docId),
          filename: drift.Value('scan_${docId.substring(0, 8)}.jpg'),
          localPath: drift.Value(job.file.path),
          category: drift.Value(category),
          subcategory: drift.Value(job.scanResult?['subcategory'] as String?),
          documentDate: drift.Value(job.scanResult?['document_date'] as String?),
          expiryDate: drift.Value(job.scanResult?['expiry_date'] as String?),
          confidence: drift.Value((job.scanResult?['confidence'] as num?)?.toDouble() ?? 0.0),
          fileHash: drift.Value(hash),
        ),
      );

      await fieldDao.insertAllFields(
        _editedFields.entries.map((e) => DocumentFieldsCompanion(
              documentId: drift.Value(docId),
              label: drift.Value(e.key),
              value: drift.Value(e.value.toString()),
            )).toList(),
      );

      // Remove from queue
      queueNotifier.removeJob(job.id);
      
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the entire queue
    final queue = ref.watch(scanQueueProvider);

    if (queue.isEmpty) {
      // Nothing to review, go home. Use Future.microtask to avoid build-phase navigation locks
      Future.microtask(() {
        if (mounted) {
          if (GoRouter.of(context).canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.home);
          }
        }
      });
      return const Scaffold(backgroundColor: AppColors.surface);
    }

    // Is there a job with an error?
    final errorJob = queue.where((j) => j.status == ScanJobStatus.error).firstOrNull;
    if (errorJob != null) {
      return _buildErrorScreen(errorJob);
    }

    // Try to find the first job ready for review
    final readyJob = queue.where((j) => j.status == ScanJobStatus.readyForReview).firstOrNull;
    
    if (readyJob == null) {
      // Must be scanning...
      final scanningCount = queue.where((j) => j.status == ScanJobStatus.scanning || j.status == ScanJobStatus.pending).length;
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: ScanLoadingOverlay(
          message: scanningCount > 1 ? 'Processing $scanningCount items...' : null,
        ),
      );
    }

    // Initialize fields for editing ONLY if it's a newly presented job
    _initFields(readyJob);

    final category = readyJob.scanResult?['category'] as String? ?? 'Other';
    final confidence = (readyJob.scanResult?['confidence'] as num?)?.toDouble() ?? 0.0;
    
    // Remaining jobs count for UI header
    final remainingCount = queue.where((j) => 
      j.status == ScanJobStatus.readyForReview || 
      j.status == ScanJobStatus.pending || 
      j.status == ScanJobStatus.scanning
    ).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: VaultAppBar(
        title: remainingCount > 1 ? 'Review ($remainingCount left)' : 'Review Scan',
        subtitle: 'Correct any errors before saving',
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // ── Scanned image ──────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    readyJob.file,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported_rounded, size: 48, color: AppColors.onSurfaceVariant),
                          SizedBox(height: 8),
                          Text('Preview unavailable', style: TextStyle(color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04, end: 0, duration: 300.ms),

                const SizedBox(height: 20),

                // ── Category + confidence ──────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text('AI extracted ${_editedFields.length} fields', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    _ConfidencePill(confidence: confidence),
                  ],
                ),

                const SizedBox(height: 20),

                Text('Extracted Fields', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tap any field to edit it before saving', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 14),

                // ── Editable field review ──────────────────────────────
                ..._editedFields.entries.map((entry) => FieldReviewCard(
                      label: entry.key,
                      value: entry.value.toString(),
                      confidence: confidence, // Backend field confidence could be passed if needed
                      onChanged: (v) {
                        // We must update the state locally
                        setState(() => _editedFields[entry.key] = v);
                      },
                    )),
              ],
            ),
          ),

          // ── Save bar ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
            color: AppColors.glass,
            child: Row(
              children: [
                if (remainingCount > 1) 
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: () {
                        // Skip this one (delete it)
                        ref.read(scanQueueProvider.notifier).removeJob(readyJob.id);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Icon(Icons.delete_outline, color: AppColors.error),
                    ),
                  ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _saveToVault(readyJob),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving…' : 'Save to Vault'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(ScanJobModel errorJob) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: VaultAppBar(
        title: 'Scan Failed',
        onBackPressed: () {
          ref.read(scanQueueProvider.notifier).removeJob(errorJob.id);
          // Dismissing the job triggers the queue.isEmpty state which safely pops the screen
        },
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Could not process document', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(errorJob.errorMessage ?? 'Unknown error', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(scanQueueProvider.notifier).removeJob(errorJob.id);
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  final double confidence;
  const _ConfidencePill({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toStringAsFixed(0);
    final color = confidence >= 0.85 ? AppColors.success : confidence >= 0.6 ? AppColors.tertiary : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 14),
          const SizedBox(width: 4),
          Text('$pct%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
