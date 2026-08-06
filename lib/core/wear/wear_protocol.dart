// Protocolo de mensajes entre AppMovil (celular) y TandasWear (reloj),
// enviados a través de WearBridge (ver wear_bridge.dart). Este archivo debe
// mantenerse IDÉNTICO en ambos proyectos — no hay un paquete Dart compartido
// entre ellos, así que un cambio aquí siempre debe replicarse en el otro.

// ─── Rutas ──────────────────────────────────────────────────────────────────

/// Celular -> Reloj.
/// El celular manda la lista completa de "items" relevantes: los pagos
/// propios pendientes/próximos/atrasados/reportados de todas las tandas
/// ACTIVAS del usuario. Reemplaza por completo lo que el reloj tenía antes
/// (no son deltas).
const rutaTandaSync = 'tanda/sync';

/// Reloj -> Celular.
/// El reloj pide que le reenvíen el último 'tanda/sync' — por ejemplo al
/// abrir la app o reconectar, por si se perdió el envío original. Sin
/// datos en el payload.
const rutaSyncSolicitar = 'sync/solicitar';

/// Reloj -> Celular.
/// El usuario reportó desde el reloj que ya pagó. El celular debe llamar al
/// backend real (mismo flujo que "Ya pagué" en la app) y, si tiene éxito,
/// volver a mandar 'tanda/sync' con el estado actualizado (el item debería
/// pasar de pagoPendiente/pagoAtrasado a pagoReportado, o desaparecer si ya
/// no aplica).
const rutaPagoReportar = 'pago/reportar';

// ─── Tipos de item ──────────────────────────────────────────────────────────

enum TandaWearTipo {
  /// Pago propio en estado ATRASADO.
  pagoAtrasado,

  /// Pago propio PENDIENTE cuya fecha límite está cerca (regla sugerida:
  /// dentro de los próximos 2 días). Es una distinción visual, no un estado
  /// que exista como tal en el backend.
  pagoProximo,

  /// Pago propio PENDIENTE sin urgencia inmediata.
  pagoPendiente,

  /// Pago propio ya REPORTADO por el usuario, esperando que el admin lo
  /// confirme. Se muestra pero ya no se puede volver a reportar.
  pagoReportado;

  static TandaWearTipo fromString(String s) {
    return TandaWearTipo.values.firstWhere(
      (t) => t.name == s,
      orElse: () => TandaWearTipo.pagoPendiente,
    );
  }
}

/// Un pago propio pendiente/próximo/atrasado/reportado, para mostrar como
/// notificación en el reloj.
class TandaWearItem {
  final String id;
  final TandaWearTipo tipo;
  final String tandaId;
  final String nombreTanda;
  final double monto;
  final DateTime? fechaLimite;

  /// El Pago real al que corresponde este item — es lo que permite que el
  /// reloj pida reportarlo específicamente vía [rutaPagoReportar].
  final String pagoId;

  TandaWearItem({
    required this.id,
    required this.tipo,
    required this.tandaId,
    required this.nombreTanda,
    required this.monto,
    this.fechaLimite,
    required this.pagoId,
  });

  factory TandaWearItem.fromJson(Map<String, dynamic> json) {
    return TandaWearItem(
      id: json['id'] ?? '',
      tipo: TandaWearTipo.fromString(json['tipo'] ?? ''),
      tandaId: json['tandaId'] ?? '',
      nombreTanda: json['nombreTanda'] ?? '',
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
      fechaLimite: json['fechaLimite'] != null
          ? DateTime.tryParse(json['fechaLimite'] as String)
          : null,
      pagoId: json['pagoId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'tandaId': tandaId,
        'nombreTanda': nombreTanda,
        'monto': monto,
        'fechaLimite': fechaLimite?.toIso8601String(),
        'pagoId': pagoId,
      };
}

/// Payload completo de [rutaTandaSync].
class TandaSyncPayload {
  final List<TandaWearItem> items;
  final DateTime generadoEn;

  TandaSyncPayload({required this.items, required this.generadoEn});

  factory TandaSyncPayload.fromJson(Map<String, dynamic> json) {
    final lista = (json['items'] as List? ?? [])
        .map((i) => TandaWearItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();
    return TandaSyncPayload(
      items: lista,
      generadoEn: json['generadoEn'] != null
          ? DateTime.tryParse(json['generadoEn'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'generadoEn': generadoEn.toIso8601String(),
      };
}

/// Payload de [rutaPagoReportar] (Reloj -> Celular).
class PagoReportarPayload {
  final String pagoId;

  PagoReportarPayload({required this.pagoId});

  factory PagoReportarPayload.fromJson(Map<String, dynamic> json) =>
      PagoReportarPayload(pagoId: json['pagoId'] as String? ?? '');

  Map<String, dynamic> toJson() => {'pagoId': pagoId};
}
