import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._dio,
    required this._tokens,
    required this._prefs,
    required this._google,
    required this._apple,
  });

  static const _userKey = 'current_user';
  final Dio _dio;
  final TokenStorage _tokens;
  final SharedPreferencesAsync _prefs;
  final GoogleIdentityProvider _google;
  final AppleIdentityProvider _apple;

  @override
  Future<AppUser> signInWithGoogle() async {
    final idToken = await _google.fetchIdToken();
    return _exchange('/auth/google', {'idToken': idToken});
  }

  @override
  Future<AppUser> signInWithApple() async {
    final credential = await _apple.fetchCredential();
    final name = credential.fullName?.trim();
    return _exchange('/auth/apple', {
      'identityToken': credential.identityToken,
      if (name != null && name.isNotEmpty) 'fullName': name,
    });
  }

  Future<AppUser> _exchange(String path, Map<String, dynamic> body) =>
      guardApi(() async {
        final res = await _dio.post<Map<String, dynamic>>(path, data: body);
        final data = res.data!;
        await _tokens.save(
          AuthTokens(
            accessToken: data['accessToken'] as String,
            refreshToken: data['refreshToken'] as String,
          ),
        );
        final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
        await _storeUser(user);
        return user;
      });

  @override
  Future<AppUser?> cachedUser() async {
    final raw = await _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<AppUser?> loadUser() async {
    try {
      final user = await guardApi(() async {
        final res = await _dio.get<Map<String, dynamic>>('/me');
        return AppUser.fromJson(res.data!);
      });
      await _storeUser(user);
      return user;
    } on AppException catch (e) {
      if (e.kind == AppErrorKind.unauthorized) rethrow;
      return cachedUser();
    }
  }

  @override
  Future<void> signOut() async {
    final stored = await _tokens.read();
    if (stored != null) {
      try {
        await _dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': stored.refreshToken},
        );
      } on DioException {
        // Best effort: local tokens are removed regardless.
      }
    }
    await _tokens.clear();
    await _prefs.remove(_userKey);
  }

  Future<void> _storeUser(AppUser user) =>
      _prefs.setString(_userKey, jsonEncode(user.toJson()));
}
