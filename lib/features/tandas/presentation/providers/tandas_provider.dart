import 'package:flutter/foundation.dart';
import '../../domain/repositories/tandas_repository.dart';
import '../../domain/models/tanda.dart';

class TandasProvider with ChangeNotifier {
  final TandasRepository _repository;
  
  List<Tanda> _tandas = [];
  bool _isLoading = false;
  String? _errorMessage;

  TandasProvider(this._repository);

  List<Tanda> get tandas => _tandas;
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

  Future<void> fetchMisTandas() async {
    _setLoading(true);
    _setError(null);
    try {
      _tandas = await _repository.getMisTandas();
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> crearTanda({
    required String nombre,
    String? descripcion,
    required double montoAportacion,
    required String frecuencia,
    required int numParticipantes,
    bool unirseComoMiembro = false,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final nuevaTanda = await _repository.crearTanda(
        nombre: nombre,
        descripcion: descripcion,
        montoAportacion: montoAportacion,
        frecuencia: frecuencia,
        numParticipantes: numParticipantes,
        unirseComoMiembro: unirseComoMiembro,
      );
      
      // La insertamos al inicio de la lista
      _tandas.insert(0, nuevaTanda);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  void eliminarTandaLocal(String tandaId) {
    _tandas.removeWhere((t) => t.id == tandaId);
    notifyListeners();
  }
}
