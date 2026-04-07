import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? profilePicUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.profilePicUrl,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as String,
        email: map['email'] as String,
        name: map['name'] as String?,
        profilePicUrl: map['profile_pic'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'profile_pic': profilePicUrl,
        'created_at': createdAt.toIso8601String(),
      };

  String get displayName => name ?? email.split('@').first;
}
