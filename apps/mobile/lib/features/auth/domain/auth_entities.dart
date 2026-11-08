import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({required this.id, this.email, this.name});

  /// Also the RevenueCat app user id.
  final String id;
  final String? email;
  final String? name;

  /// First name for greetings; falls back to the e-mail local part.
  String? get firstName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n.split(' ').first;
    final mail = email;
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return null;
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String?,
    name: json['name'] as String?,
  );

  @override
  List<Object?> get props => [id, email, name];
}

/// Credential obtained from Apple on the device.
class AppleCredential extends Equatable {
  const AppleCredential({required this.identityToken, this.fullName});

  final String identityToken;

  /// Only provided by Apple on the first authorization.
  final String? fullName;

  @override
  List<Object?> get props => [identityToken, fullName];
}

/// The user dismissed the native sign-in sheet. Not an error to display.
class SignInCancelled implements Exception {
  const SignInCancelled();
}
