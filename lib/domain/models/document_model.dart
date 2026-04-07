import 'package:flutter/foundation.dart';

/// Domain model for a scanned document.
/// Mirrors both the local SQLite schema and the cloud Supabase schema.
@immutable
class DocumentModel {
  final String id;
  final String filename;
  final String localPath;
  final String? thumbPath;
  final String category;
  final String? subcategory;
  final DateTime? documentDate;
  final DateTime? expiryDate;
  final double confidence;
  final String? fileHash;
  final bool isTampered;
  final String? rawText;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentModel({
    required this.id,
    required this.filename,
    required this.localPath,
    this.thumbPath,
    required this.category,
    this.subcategory,
    this.documentDate,
    this.expiryDate,
    this.confidence = 0.0,
    this.fileHash,
    this.isTampered = false,
    this.rawText,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns true if the document expires within [days] days
  bool isExpiringSoon({int days = 30}) {
    if (expiryDate == null) return false;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= days;
  }

  /// Returns true if the document has already expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  DocumentModel copyWith({
    String? id,
    String? filename,
    String? localPath,
    String? thumbPath,
    String? category,
    String? subcategory,
    DateTime? documentDate,
    DateTime? expiryDate,
    double? confidence,
    String? fileHash,
    bool? isTampered,
    String? rawText,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      DocumentModel(
        id: id ?? this.id,
        filename: filename ?? this.filename,
        localPath: localPath ?? this.localPath,
        thumbPath: thumbPath ?? this.thumbPath,
        category: category ?? this.category,
        subcategory: subcategory ?? this.subcategory,
        documentDate: documentDate ?? this.documentDate,
        expiryDate: expiryDate ?? this.expiryDate,
        confidence: confidence ?? this.confidence,
        fileHash: fileHash ?? this.fileHash,
        isTampered: isTampered ?? this.isTampered,
        rawText: rawText ?? this.rawText,
        isSynced: isSynced ?? this.isSynced,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DocumentModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Known document categories in DigiSafe
class DocumentCategory {
  static const String identity    = 'Identity';
  static const String education   = 'Education';
  static const String financial   = 'Financial';
  static const String medical     = 'Medical';
  static const String property    = 'Property';
  static const String vehicle     = 'Vehicle';
  static const String employment  = 'Employment';
  static const String travel      = 'Travel';
  static const String other       = 'Other';

  static const List<String> all = [
    identity, education, financial, medical,
    property, vehicle, employment, travel, other,
  ];
}
