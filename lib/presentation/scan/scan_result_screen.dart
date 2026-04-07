import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../data/remote/api_service.dart';
import 'package:go_router/go_router.dart';
import '../../domain/providers/database_providers.dart';
import '../../data/local/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> scanData;
  const ScanResultScreen({super.key, required this.scanData});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  bool _isProcessing = true;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    final imagePath = widget.scanData['imagePath'] as String?;
    if (imagePath == null) {
      setState(() {
        _error = "No image found.";
        _isProcessing = false;
      });
      return;
    }

    try {
      final apiService = ApiService();
      final result = await apiService.scanDocument(File(imagePath));
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Review Analysis'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text("Gemini is analyzing document..."),
                ],
              ),
            )
          : _error != null
              ? Center(child: Text("Error: $_error", style: const TextStyle(color: AppColors.error)))
              : _buildResults(),
    );
  }

  Widget _buildResults() {
    if (_result == null || _result!['data'] == null) {
      return const Center(child: Text("No data extracted."));
    }

    final data = _result!['data'] as Map<String, dynamic>;
    final fields = data['fields'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.scanData['imagePath'] != null)
          Container(
            height: 200,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: FileImage(File(widget.scanData['imagePath'])),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Text(
          data['category'] ?? 'Uncategorized',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ...fields.entries.map((e) => ListTile(
              title: Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              subtitle: Text(e.value.toString()),
            )),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () async {
            final docDao = ref.read(documentDaoProvider);
            final fieldDao = ref.read(fieldDaoProvider);
            
            final docId = const Uuid().v4();
            await docDao.insertDocument(
              DocumentsCompanion(
                id: drift.Value(docId),
                filename: drift.Value('scan_$docId.jpg'),
                category: drift.Value(data['category'] ?? 'Uncategorized'),
                localPath: drift.Value(widget.scanData['imagePath']),
              ),
            );
            
            final fieldEntries = fields.entries.map((entry) {
              return DocumentFieldsCompanion(
                documentId: drift.Value(docId),
                label: drift.Value(entry.key),
                value: drift.Value(entry.value.toString()),
              );
            }).toList();
            
            await fieldDao.insertAllFields(fieldEntries);

            if (mounted) {
              context.go('/home');
            }
          },
          child: const Text('Save to Vault'),
        )
      ],
    );
  }
}
