import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/tanda_detalle.dart';

class TandaDetalleRepository {
  final DioClient _dioClient;

  TandaDetalleRepository(this._dioClient);

  Future<TandaDetalle> getTandaDetalle(String tandaId, String currentUserId) async {
    try {
      final response = await _dioClient.dio.get('/tandas/$tandaId');
      if (response.statusCode == 200) {
        return TandaDetalle.fromJson(response.data, currentUserId);
      }
      throw Exception('Tanda no encontrada');
    } catch (e) {
      throw Exception('Error al obtener detalle de la tanda: ${e.toString()}');
    }
  }

  Future<bool> invitarMiembro(
    String tandaId,
    String email, {
    List<int>? turnos,
  }) async {
    try {
      final data = <String, dynamic>{'email': email};
      if (turnos != null && turnos.isNotEmpty) data['turnos'] = turnos;
      final response = await _dioClient.dio.post(
        '/tandas/$tandaId/miembros',
        data: data,
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Este correo no está registrado en Tandas. La persona debe crear una cuenta primero.');
      }
      throw Exception(e.response?.data['message'] ?? 'Error al invitar miembro');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<bool> editarTanda(
    String tandaId, {
    String? nombre,
    String? descripcion,
    double? montoAportacion,
    String? frecuencia,
    int? numParticipantes,
  }) async {
    // Solo enviamos los campos que no son nulos (actualización parcial)
    final data = <String, dynamic>{};
    if (nombre != null) data['nombre'] = nombre;
    if (descripcion != null) data['descripcion'] = descripcion;
    if (montoAportacion != null) data['montoAportacion'] = montoAportacion;
    if (frecuencia != null) data['frecuencia'] = frecuencia;
    if (numParticipantes != null) data['numParticipantes'] = numParticipantes;

    try {
      final response = await _dioClient.dio.patch('/tandas/$tandaId', data: data);
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al editar la tanda');
    } catch (e) {
      throw Exception('Error al editar la tanda: ${e.toString()}');
    }
  }

  Future<bool> quitarMiembro(String tandaId, String miembroTandaId) async {
    try {
      final response = await _dioClient.dio.delete('/tandas/$tandaId/miembros/$miembroTandaId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Error al quitar miembro: ${e.toString()}');
    }
  }

  Future<bool> salirDeTanda(String tandaId) async {
    try {
      final response = await _dioClient.dio.delete('/tandas/$tandaId/miembros/salir');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al salir de la tanda');
    } catch (e) {
      throw Exception('Error al salir de la tanda: ${e.toString()}');
    }
  }

  Future<bool> cancelarTanda(String tandaId) async {
    try {
      final response = await _dioClient.dio.delete('/tandas/$tandaId');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al cancelar la tanda');
    } catch (e) {
      throw Exception('Error al cancelar la tanda: ${e.toString()}');
    }
  }

  Future<bool> asignarTurno(
    String tandaId,
    String miembroTandaId,
    int turnoOrden,
  ) async {
    try {
      final response = await _dioClient.dio.patch(
        '/tandas/$tandaId/asignar-turno',
        data: {
          'miembroTandaId': miembroTandaId,
          'turnoOrden': turnoOrden,
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al asignar el turno');
    } catch (e) {
      throw Exception('Error al asignar el turno: ${e.toString()}');
    }
  }

  Future<bool> quitarTurno(String tandaId, String turnoTandaId) async {
    try {
      final response = await _dioClient.dio.delete(
        '/tandas/$tandaId/turnos/$turnoTandaId',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al quitar el turno');
    } catch (e) {
      throw Exception('Error al quitar el turno: ${e.toString()}');
    }
  }

  Future<bool> marcarPagoComoPagado(String pagoId) async {
    try {
      final response = await _dioClient.dio.patch(
        '/pagos/$pagoId',
        data: {
          'estado': 'PAGADO',
          'fechaPago': DateTime.now().toIso8601String(),
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al marcar el pago como realizado');
    } catch (e) {
      throw Exception('Error al marcar el pago como realizado: ${e.toString()}');
    }
  }

  Future<bool> activarTanda(String tandaId) async {
    try {
      final response = await _dioClient.dio.patch('/tandas/$tandaId/activar');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al iniciar la tanda');
    } catch (e) {
      throw Exception('Error al iniciar la tanda: ${e.toString()}');
    }
  }

  Future<bool> reportarPagoPropio(String pagoId) async {
    try {
      final response = await _dioClient.dio.patch(
        '/pagos/$pagoId',
        data: {'estado': 'REPORTADO'},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al reportar el pago');
    } catch (e) {
      throw Exception('Error al reportar el pago: ${e.toString()}');
    }
  }

  Future<List<Ciclo>> getHistorialCiclos(String tandaId) async {
    try {
      final response = await _dioClient.dio.get('/ciclos-pago/tanda/$tandaId');
      final data = response.data as List;
      return data.map((j) => Ciclo.fromJson(j)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al obtener el historial de ciclos');
    } catch (e) {
      throw Exception('Error al obtener el historial de ciclos: ${e.toString()}');
    }
  }

  Future<bool> avanzarCiclo(String tandaId) async {
    try {
      final response = await _dioClient.dio.patch('/tandas/$tandaId/avanzar-ciclo');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      throw Exception(msg ?? 'Error al avanzar de ciclo');
    } catch (e) {
      throw Exception('Error al avanzar de ciclo: ${e.toString()}');
    }
  }
}
