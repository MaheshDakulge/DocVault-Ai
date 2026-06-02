import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';
import '../../domain/providers/scan_queue_provider.dart';
import '../common_widgets/vault_app_bar.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _isPicking = false;

  Future<void> _scanWithCamera() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final pictures = await CunningDocumentScanner.getPictures() ?? [];
      
      if (mounted) setState(() => _isPicking = false);

      if (pictures.isNotEmpty) {
        final files = pictures.map((p) => File(p)).toList();
        ref.read(scanQueueProvider.notifier).addFiles(files);
        // After queueing, redirect to the new queue screen (scan result review screen)
        if (mounted) context.push(RouteNames.scanResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPicking = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanner error: $e')));
      }
    }
  }

  Future<void> _pickFiles() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final result = await fp.FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: fp.FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (mounted) setState(() => _isPicking = false);

      if (result != null && result.paths.isNotEmpty) {
        final files = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
        ref.read(scanQueueProvider.notifier).addFiles(files);
        if (mounted) context.push(RouteNames.scanResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPicking = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File picker error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VaultAppBar(title: 'Add Documents'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            _ActionCard(
              icon: Icons.document_scanner_rounded,
              title: 'Scan Pages',
              subtitle: 'Use camera to auto-crop physical documents',
              onTap: _scanWithCamera,
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.file_upload_outlined,
              title: 'Import Files',
              subtitle: 'Select PDFs or images from your device',
              onTap: _pickFiles,
            ),
            const SizedBox(height: 32),
            Text(
              'Documents are processed in the background and will appear in your review queue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
