import 'package:flutter/foundation.dart';

/// A single key-value field extracted by Gemini from a scanned document.
/// Example: label="Aadhaar Number", value="1234 5678 9012", isCopyable=true
@immutable
class FieldModel {
  final int? id;
  final String documentId;
  final String label;
  final String value;
  final double confidence;
  final bool isCopyable;

  const FieldModel({
    this.id,
    required this.documentId,
    required this.label,
    required this.value,
    this.confidence = 0.0,
    this.isCopyable = true,
  });

  FieldModel copyWith({
    int? id,
    String? documentId,
    String? label,
    String? value,
    double? confidence,
    bool? isCopyable,
  }) =>
      FieldModel(
        id: id ?? this.id,
        documentId: documentId ?? this.documentId,
        label: label ?? this.label,
        value: value ?? this.value,
        confidence: confidence ?? this.confidence,
        isCopyable: isCopyable ?? this.isCopyable,
      );
}
