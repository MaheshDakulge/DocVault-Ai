import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/colors.dart';
import '../../domain/providers/document_provider.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/field_model.dart';
import '../common_widgets/expiry_alert_badge.dart';
import 'widgets/field_copy_tile.dart';
import 'widgets/tamper_status_badge.dart';
import '../../data/remote/api_service.dart';

class DocumentViewerScreen extends ConsumerWidget {
  final String docId;
  const DocumentViewerScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync    = ref.watch(documentByIdProvider(docId));
    final fieldsAsync = ref.watch(documentFieldsProvider(docId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: docAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (doc) {
          if (doc == null) {
            return const Center(child: Text('Document not found.'));
          }
          return _DocumentBody(doc: doc, fieldsAsync: fieldsAsync);
        },
      ),
    );
  }
}

class _DocumentBody extends ConsumerStatefulWidget {
  final DocumentModel doc;
  final AsyncValue<List<FieldModel>> fieldsAsync;

  const _DocumentBody({required this.doc, required this.fieldsAsync});

  @override
  ConsumerState<_DocumentBody> createState() => _DocumentBodyState();
}

class _DocumentBodyState extends ConsumerState<_DocumentBody> {
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    _fetchSignedUrl();
  }

  Future<void> _fetchSignedUrl() async {
    // Only fetch if local file doesn't exist AND we are synced
    if (!File(widget.doc.localPath).existsSync() && widget.doc.isSynced) {
      final url = await ApiService().getSignedUrl(widget.doc.id);
      if (mounted) {
        setState(() => _signedUrl = url);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('This will permanently remove the document from your vault. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(documentDeleteProvider.notifier).delete(widget.doc.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onSurface, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.doc.filename, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppColors.primary, size: 22),
              onPressed: () {
                // Implement link sharing dialog
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
              onPressed: _confirmDelete,
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Physical'),
              Tab(text: 'Digital'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Physical Tab: Image Viewer
            _buildPhysicalTab(),
            // Digital Tab: Fields & Data
            _buildDigitalTab(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalTab() {
    final localFile = File(widget.doc.localPath);
    final hasLocalImage = localFile.existsSync();

    if (!hasLocalImage && _signedUrl == null && widget.doc.isSynced) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (!hasLocalImage && _signedUrl == null && !widget.doc.isSynced) {
      return const Center(child: Text("Image not available laterally or remotely"));
    }

    return InteractiveViewer(
      panEnabled: true,
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: hasLocalImage
            ? Image.file(localFile, fit: BoxFit.contain)
            : CachedNetworkImage(
                imageUrl: _signedUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error_outline),
              ),
      ),
    );
  }

  Widget _buildDigitalTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Meta Tags
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip(widget.doc.category),
            if (widget.doc.subcategory != null) _Chip(widget.doc.subcategory!),
            ExpiryAlertBadge(expiryDate: widget.doc.expiryDate),
            TamperStatusBadge(isTampered: widget.doc.isTampered),
          ],
        ),
        const SizedBox(height: 24),
        _ConfidenceBar(confidence: widget.doc.confidence),
        const SizedBox(height: 28),
        Text('Extracted Fields', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Tap any field to copy it to your clipboard', style: theme.textTheme.bodySmall),
        const SizedBox(height: 14),
        
        // Fields List
        widget.fieldsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load fields: $e')),
          data: (fields) => Column(
            children: fields.asMap().entries.map((entry) {
              final i = entry.key;
              final field = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FieldCopyTile(field: field)
                    .animate(delay: Duration(milliseconds: i * 40))
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: 0.05, end: 0, duration: 250.ms),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
      );
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  const _ConfidenceBar({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct   = (confidence * 100).toStringAsFixed(0);
    final color = confidence >= 0.85 ? AppColors.success : confidence >= 0.6 ? AppColors.tertiary : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('AI Confidence', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$pct%', style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
