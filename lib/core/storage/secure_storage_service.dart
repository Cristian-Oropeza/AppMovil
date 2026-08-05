import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();
  
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';

  Future<void> saveTokens({required String token, required String refreshToken, required String userId}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getToken() async => await _storage.read(key: _tokenKey);
  
  Future<String?> getRefreshToken() async => await _storage.read(key: _refreshTokenKey);

  Future<String?> getUserId() async => await _storage.read(key: _userIdKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
