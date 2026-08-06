import 'package:flutter/foundation.dart';
import '../../domain/repositories/tanda_detalle_repository.dart';
import '../../domain/models/tanda_detalle.dart';

class TandaDetalleProvider with ChangeNotifier {
  final TandaDetalleRepository _repository;
  
  TandaDetalle? _detalle;
  bool _isLoading = false;
  String? _errorMessage;
  // Guardamos el userId para poder refrescar el detalle desde cualquier método
  String? _currentUserId;

  // Estado separado para el historial de ciclos: no debe pisar el loading/error
  // de la pantalla principal de detalle.
  List<Ciclo> _historialCiclos = [];
  bool _isLoadingHistorial = false;
  String? _historialErrorMessage;

  TandaDetalleProvider(this._repository);

  TandaDetalle? get detalle => _detalle;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Ciclo> get historialCiclos => _historialCiclos;
  bool get isLoadingHistorial => _isLoadingHistorial;
  String? get historialErrorMessage => _historialErrorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> fetchHistorialCiclos(String tandaId) async {
    _isLoadingHistorial = true;
    _historialErrorMessage = null;
    notifyListeners();
    try {
      _historialCiclos = await _repository.getHistorialCiclos(tandaId);
    } catch (e) {
      _historialErrorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingHistorial = false;
      notifyListeners();
    }
  }

  // Necesitamos el currentUserId para saber si somos admin o miembro y mapearlo
  Future<void> fetchDetalle(String id, String currentUserId) async {
    _currentUserId = currentUserId;
    _setLoading(true);
    _setError(null);
    try {
      _detalle = await _repository.getTandaDetalle(id, currentUserId);
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> invitarMiembro(
    String tandaId,
    String email, {
    List<int>? turnos,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.invitarMiembro(
        tandaId,
        email,
        turnos: turnos,
      );
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> editarTanda(
    String tandaId,
    String currentUserId, {
    String? nombre,
    String? descripcion,
    double? montoAportacion,
    String? frecuencia,
    int? numParticipantes,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.editarTanda(
        tandaId,
        nombre: nombre,
        descripcion: descripcion,
        montoAportacion: montoAportacion,
        frecuencia: frecuencia,
        numParticipantes: numParticipantes,
      );
      if (success) {
        // Refrescar el detalle para reflejar los cambios
        await fetchDetalle(tandaId, currentUserId);
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> quitarMiembro(String tandaId, String miembroTandaId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.quitarMiembro(tandaId, miembroTandaId);
      if (success && _detalle != null) {
        // Refrescar desde la API para garantizar que la lista refleje el estado real
        if (_currentUserId != null) {
          await fetchDetalle(tandaId, _currentUserId!);
        } else {
          // Fallback: eliminación local si no hay userId cacheado
          _detalle!.miembros.removeWhere((m) => m.id == miembroTandaId);
          notifyListeners();
        }
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> cancelarTanda(String tandaId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.cancelarTanda(tandaId);
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> salirDeTanda(String tandaId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.salirDeTanda(tandaId);
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> asignarTurno(
    String tandaId,
    String miembroTandaId,
    int turnoOrden,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.asignarTurno(
        tandaId,
        miembroTandaId,
        turnoOrden,
      );
      if (success && _currentUserId != null) {
        await fetchDetalle(tandaId, _currentUserId!);
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> quitarTurno(String tandaId, String turnoTandaId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.quitarTurno(tandaId, turnoTandaId);
      if (success && _currentUserId != null) {
        await fetchDetalle(tandaId, _currentUserId!);
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> marcarPagoComoPagado(String tandaId, String pagoId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.marcarPagoComoPagado(pagoId);
      if (success && _currentUserId != null) {
        await fetchDetalle(tandaId, _currentUserId!);
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> activarTanda(String tandaId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.activarTanda(tandaId);
      if (success && _currentUserId != null) {
        await fetchDetalle(tandaId, _currentUserId!);
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> reportarPagoPropio(String tandaId, String pagoId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.reportarPagoPropio(pagoId);
      if (success && _currentUserId != null) {
        await fetchDetalle(tandaId, _currentUserId!);
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> avanzarCiclo(String tandaId) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await _repository.avanzarCiclo(tandaId);
      if (success && _currentUserId != null) {
        await fetchDetalle(tandaId, _currentUserId!);
      }
      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }
}
