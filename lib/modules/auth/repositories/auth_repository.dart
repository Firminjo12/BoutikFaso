import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository({Dio? dio, FlutterSecureStorage? storage})
    : _dio = dio ?? _createDio(),
      _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'boutik_faso_access_token';
  static const _refreshTokenKey = 'boutik_faso_refresh_token';
  static const _merchantIdKey = 'boutik_faso_active_merchant_id';

  static Dio _createDio() => Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000/api/v1',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  Future<void> login({required String phone, required String pin}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': phone.trim(), 'password': pin},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    await _saveTokens(response.data!);
  }

  Future<void> register({
    required String merchantName,
    required String fullName,
    required String address,
    required String phone,
    required String pin,
    String? email,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'merchant_name': merchantName.trim(),
        'merchant_phone': phone.trim(),
        'merchant_address': address.trim(),
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'password': pin,
      },
    );
    await _saveTokens(response.data!);
  }

  Future<bool> restoreSession() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      await _saveTokens(response.data!);
      return true;
    } on DioException {
      await clearSession();
      return false;
    }
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _merchantIdKey),
    ]);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw const FormatException('Réponse de connexion incomplète.');
    }
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(
        key: _merchantIdKey,
        value: data['active_merchant_id']?.toString(),
      ),
    ]);
  }

  static String messageFor(Object error) {
    if (error is DioException) {
      final detail = error.response?.data;
      if (detail is Map<String, dynamic> && detail['detail'] is String) {
        return detail['detail'] as String;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
      }
      if (error.response?.statusCode == 429) {
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      }
    }
    if (error is FormatException) return error.message;
    return 'Une erreur est survenue. Réessayez.';
  }
}
