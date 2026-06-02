import 'package:flutter/foundation.dart';

/// A government welfare scheme that DigiSafe can match users against.
@immutable
class SchemeModel {
  final String id;
  final String name;
  final String level;          // "Central" | "State"
  final String? state;         // Null for central schemes
  final Map<String, dynamic> criteria;
  final String benefit;
  final String? applyUrl;
  final bool isEligible;       // Set by AI eligibility engine
  final String? eligibilityReason;

  const SchemeModel({
    required this.id,
    required this.name,
    required this.level,
    this.state,
    required this.criteria,
    required this.benefit,
    this.applyUrl,
    this.isEligible = false,
    this.eligibilityReason,
  });

  factory SchemeModel.fromMap(Map<String, dynamic> map) => SchemeModel(
        id: map['id'] as String,
        name: map['name'] as String,
        level: map['level'] as String,
        state: map['state'] as String?,
        criteria: (map['criteria'] as Map<String, dynamic>?) ?? {},
        benefit: map['benefit'] as String,
        applyUrl: map['apply_url'] as String?,
        isEligible: (map['is_eligible'] as bool?) ?? false,
        eligibilityReason: map['eligibility_reason'] as String?,
      );

  SchemeModel copyWith({
    bool? isEligible,
    String? eligibilityReason,
  }) =>
      SchemeModel(
        id: id,
        name: name,
        level: level,
        state: state,
        criteria: criteria,
        benefit: benefit,
        applyUrl: applyUrl,
        isEligible: isEligible ?? this.isEligible,
        eligibilityReason: eligibilityReason ?? this.eligibilityReason,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SchemeModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
