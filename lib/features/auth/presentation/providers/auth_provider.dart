import 'package:flutter/foundation.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authRepository);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _authRepository.login(email, password);
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> registro(String email, String password, String nombre, String? telefono) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _authRepository.registro(email, password, nombre, telefono);
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    notifyListeners();
  }

  Future<bool> confirmarCodigoDispositivo(String codigo) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authRepository.confirmarCodigoDispositivo(codigo);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }
}
