import 'package:flutter/foundation.dart';

import '../../features/tandas/domain/models/tanda.dart';
import '../../features/tandas/domain/models/tanda_detalle.dart';
import '../../features/tandas/domain/repositories/tanda_detalle_repository.dart';
import '../../features/tandas/domain/repositories/tandas_repository.dart';
import '../storage/secure_storage_service.dart';
import 'wear_bridge.dart';
import 'wear_protocol.dart';

/// Arma y manda al reloj (vía WearBridge) la lista de pagos propios
/// pendientes/próximos/atrasados/reportados de las tandas ACTIVAS del
/// usuario, y atiende las acciones que llegan del reloj (pedir sync de
/// nuevo, reportar un pago).
class WearSyncService {
  final TandasRepository _tandasRepository;
  final TandaDetalleRepository _tandaDetalleRepository;
  final SecureStorageService _storageService;

  WearSyncService(
    this._tandasRepository,
    this._tandaDetalleRepository,
    this._storageService,
  );

  /// Empieza a escuchar al reloj. Se llama una sola vez, al arrancar la app.
  void iniciarEscucha() {
    debugPrint('[WearSyncService] escuchando mensajes del reloj');
    WearBridge.mensajes.listen((mensaje) async {
      debugPrint('[WearSyncService] mensaje del reloj: ${mensaje.ruta}');
      switch (mensaje.ruta) {
        case rutaSyncSolicitar:
          await sincronizar();
          break;
        case rutaPagoReportar:
          final payload = PagoReportarPayload.fromJson(mensaje.datos);
          if (payload.pagoId.isEmpty) return;
          try {
            await _tandaDetalleRepository.reportarPagoPropio(payload.pagoId);
          } catch (_) {
            // Si falla, el reloj simplemente no verá el cambio reflejado
            // en el próximo sync; no hay nada más que hacer desde aquí.
          }
          await sincronizar();
          break;
      }
    });
  }

  /// Recalcula la lista de pagos propios pendientes y la manda al reloj.
  /// No lanza excepciones: si no hay sesión, red, o el reloj no está
  /// conectado, simplemente no hace nada.
  Future<void> sincronizar() async {
    try {
      final userId = await _storageService.getUserId();
      debugPrint('[WearSyncService] sincronizar() userId=$userId');
      if (userId == null) return;

      final tandas = await _tandasRepository.getMisTandas();
      final activas = tandas.where((t) => t.estado == TandaEstado.activa);
      debugPrint('[WearSyncService] ${tandas.length} tanda(s) en total, ${activas.length} activa(s)');

      final items = <TandaWearItem>[];
      for (final tanda in activas) {
        try {
          final detalle = await _tandaDetalleRepository.getTandaDetalle(tanda.id, userId);
          final ciclo = detalle.cicloActual;
          if (ciclo == null) {
            debugPrint('[WearSyncService] ${tanda.nombre}: sin ciclo actual');
            continue;
          }

          for (final pago in ciclo.pagos) {
            if (pago.usuarioId != userId) continue;
            if (pago.estado == PagoEstado.pagado) continue;

            items.add(TandaWearItem(
              id: pago.id,
              tipo: _tipoParaPago(pago.estado, ciclo.fechaLimite),
              tandaId: tanda.id,
              nombreTanda: tanda.nombre,
              monto: pago.monto,
              fechaLimite: ciclo.fechaLimite,
              pagoId: pago.id,
            ));
          }
        } catch (e) {
          // Si una tanda falla al cargar su detalle, seguimos con las demás.
          debugPrint('[WearSyncService] error cargando detalle de ${tanda.nombre}: $e');
          continue;
        }
      }

      debugPrint('[WearSyncService] mandando ${items.length} item(s) al reloj');
      await WearBridge.enviar(
        rutaTandaSync,
        TandaSyncPayload(items: items, generadoEn: DateTime.now()).toJson(),
      );
    } catch (e) {
      // Sin sesión activa, sin red, etc.: no es un error fatal para la app.
      debugPrint('[WearSyncService] sincronizar() falló: $e');
    }
  }

  TandaWearTipo _tipoParaPago(PagoEstado estado, DateTime fechaLimite) {
    if (estado == PagoEstado.atrasado) return TandaWearTipo.pagoAtrasado;
    if (estado == PagoEstado.reportado) return TandaWearTipo.pagoReportado;
    final diasRestantes = fechaLimite.difference(DateTime.now()).inDays;
    return diasRestantes <= 2 ? TandaWearTipo.pagoProximo : TandaWearTipo.pagoPendiente;
  }
}
