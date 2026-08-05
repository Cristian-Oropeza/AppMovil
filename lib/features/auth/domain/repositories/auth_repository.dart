import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorageService _storageService;

  AuthRepository(this._dioClient, this._storageService);

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        await _storageService.saveTokens(
          token: data['accessToken'],
          refreshToken: data['refreshToken'],
          userId: data['usuario']['id'],
        );
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
         throw Exception('Credenciales incorrectas');
      }
      throw Exception('Error al iniciar sesión: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: ${e.toString()}');
    }
  }

  Future<bool> registro(String email, String password, String nombre, String? telefono) async {
    try {
      final response = await _dioClient.dio.post('/auth/registro', data: {
        'email': email,
        'password': password,
        'nombre': nombre,
        'telefono': telefono,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        await _storageService.saveTokens(
          token: data['accessToken'],
          refreshToken: data['refreshToken'],
          userId: data['usuario']['id'],
        );
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw Exception('Error en el registro: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Error inesperado: ${e.toString()}');
    }
  }

  /// Confirma, desde el celular ya logueado, un código de 6 dígitos que el
  /// usuario ve en el reloj — así el reloj recibe su propia sesión.
  Future<void> confirmarCodigoDispositivo(String codigo) async {
    try {
      await _dioClient.dio.post('/auth/dispositivo/confirmar', data: {
        'codigo': codigo,
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg is String ? msg : 'Código inválido o expirado');
    } catch (e) {
      throw Exception('Error al vincular el reloj: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null) {
        await _dioClient.dio.post('/auth/logout', data: {
          'refreshToken': refreshToken,
        });
      }
    } catch (_) {
      // Ignorar fallos de red al cerrar sesión, se limpiará el token localmente
    } finally {
      await _storageService.clearTokens();
    }
  }
}
