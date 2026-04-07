import 'package:flutter/material.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String docId;
  const DocumentViewerScreen({super.key, required this.docId});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: Center(child: Text('Viewer for $docId — Day 2')),
      );
}
