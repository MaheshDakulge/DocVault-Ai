import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../domain/providers/database_providers.dart';
import '../../data/local/database.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';
  List<Document> _results = [];

  void _onSearchChanged(String query) async {
    setState(() => _query = query);
    if (query.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }

    // Hit the FTS5 virtual table
    final ftsDao = ref.read(ftsDaoProvider);
    final docDao = ref.read(documentDaoProvider);
    
    final docIds = await ftsDao.search(query);
    
    final List<Document> actualDocs = [];
    for (final id in docIds) {
      final doc = await docDao.getById(id);
      if (doc != null) {
        actualDocs.add(doc);
      }
    }
    
    if (mounted) {
      setState(() => _results = actualDocs);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search documents...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _onSearchChanged,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _query.isEmpty
          ? const Center(child: Text("Type to search offline instantly...", style: TextStyle(color: AppColors.onSurfaceVariant)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final doc = _results[index];
                return ListTile(
                  title: Text(doc.filename),
                  subtitle: Text(doc.category),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    context.push('/document/${doc.id}');
                  },
                );
              },
            ),
    );
  }
}
