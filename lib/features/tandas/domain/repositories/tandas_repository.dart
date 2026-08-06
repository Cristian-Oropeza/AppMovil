import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/tanda.dart';

class TandasRepository {
  final DioClient _dioClient;

  TandasRepository(this._dioClient);

  Future<List<Tanda>> getMisTandas() async {
    try {
      final response = await _dioClient.dio.get('/tandas/mis-tandas');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Tanda.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error al obtener tandas: ${e.toString()}');
    }
  }

  Future<Tanda> crearTanda({
    required String nombre,
    String? descripcion,
    required double montoAportacion,
    required String frecuencia, // SEMANAL, QUINCENAL, MENSUAL
    required int numParticipantes,
    bool unirseComoMiembro = false,
  }) async {
    try {
      final response = await _dioClient.dio.post('/tandas', data: {
        'nombre': nombre,
        'descripcion': descripcion,
        'montoAportacion': montoAportacion,
        'frecuencia': frecuencia,
        'numParticipantes': numParticipantes,
        'unirseComoMiembro': unirseComoMiembro,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        // La API retorna la tanda con 'miembros' incluido (puede estar vacío
        // si el admin decidió no unirse). El admin siempre se muestra como ADMIN.
        final data = response.data;
        final miembros = data['miembros'] as List? ?? [];
        data['miRol'] = 'ADMIN';
        data['numMiembrosActuales'] = miembros.length;
        return Tanda.fromJson(data);
      }
      throw Exception('Error al crear tanda');
    } catch (e) {
      throw Exception('Error al crear tanda: ${e.toString()}');
    }
  }
}
