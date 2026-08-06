import 'tanda.dart';

enum MiembroEstado {
  activo,
  inactivo,
  expulsado;

  static MiembroEstado fromString(String str) {
    switch (str.toUpperCase()) {
      case 'ACTIVO': return MiembroEstado.activo;
      case 'INACTIVO': return MiembroEstado.inactivo;
      case 'EXPULSADO': return MiembroEstado.expulsado;
      default: return MiembroEstado.activo;
    }
  }
}

// Un turno individual que tiene un miembro dentro de la tanda. Se guarda su
// propio id (el de la fila TurnoTanda) porque un miembro puede tener varios
// y cada uno se puede quitar por separado.
class TurnoAsignado {
  final String id;
  final int turnoOrden;

  TurnoAsignado({required this.id, required this.turnoOrden});

  factory TurnoAsignado.fromJson(Map<String, dynamic> json) {
    return TurnoAsignado(
      id: json['id'] ?? '',
      turnoOrden: json['turnoOrden'] ?? 0,
    );
  }
}

class Miembro {
  final String id;
  final String? usuarioId;
  final String nombre;
  final String? fotoUrl;
  final TandaRol rol;
  final List<TurnoAsignado> turnos;
  final MiembroEstado estado;

  Miembro({
    required this.id,
    this.usuarioId,
    required this.nombre,
    this.fotoUrl,
    required this.rol,
    this.turnos = const [],
    required this.estado,
  });

  factory Miembro.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] ?? {};
    final turnosList = json['turnos'] as List? ?? [];
    final turnos = turnosList.map((t) => TurnoAsignado.fromJson(t)).toList()
      ..sort((a, b) => a.turnoOrden.compareTo(b.turnoOrden));
    return Miembro(
      id: json['id'] ?? '',
      usuarioId: usuario['id'] as String?,
      nombre: usuario['nombre'] ?? 'Desconocido',
      fotoUrl: usuario['fotoPerfil'],
      rol: TandaRol.fromString(json['rol'] ?? ''),
      turnos: turnos,
      estado: MiembroEstado.fromString(json['estado'] ?? ''),
    );
  }
}

enum PagoEstado {
  pendiente,
  reportado,
  pagado,
  atrasado;

  static PagoEstado fromString(String str) {
    switch (str.toUpperCase()) {
      case 'PENDIENTE': return PagoEstado.pendiente;
      case 'REPORTADO': return PagoEstado.reportado;
      case 'PAGADO': return PagoEstado.pagado;
      case 'ATRASADO': return PagoEstado.atrasado;
      default: return PagoEstado.pendiente;
    }
  }
}

class Pago {
  final String id;
  final String nombreMiembro;
  final String? usuarioId;
  final PagoEstado estado;
  final double monto;

  Pago({
    required this.id,
    required this.nombreMiembro,
    this.usuarioId,
    required this.estado,
    this.monto = 0,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    // El backend anida miembroTanda.usuario.{nombre,id}; mantenemos un
    // fallback al campo plano 'nombreMiembro' por si alguna vista lo manda distinto.
    final miembroTanda = json['miembroTanda'];
    final usuario = miembroTanda != null ? miembroTanda['usuario'] : null;
    final nombreMiembro = usuario != null
        ? (usuario['nombre'] ?? 'Desconocido')
        : (json['nombreMiembro'] ?? 'Desconocido');

    return Pago(
      id: json['id'] ?? '',
      nombreMiembro: nombreMiembro,
      usuarioId: usuario != null ? usuario['id'] as String? : null,
      estado: PagoEstado.fromString(json['estado'] ?? ''),
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class Ciclo {
  final int numeroCiclo;
  final DateTime fechaLimite;
  final String nombreBeneficiario;
  final double montoTotalCiclo;
  final bool cerrado;
  final List<Pago> pagos;

  Ciclo({
    required this.numeroCiclo,
    required this.fechaLimite,
    required this.nombreBeneficiario,
    required this.montoTotalCiclo,
    this.cerrado = false,
    required this.pagos,
  });

  factory Ciclo.fromJson(Map<String, dynamic> json) {
    var list = json['pagos'] as List? ?? [];
    List<Pago> pagosList = list.map((i) => Pago.fromJson(i)).toList();

    // El backend no manda un total precalculado: lo sumamos a partir de los pagos.
    final montoTotal = pagosList.isNotEmpty
        ? pagosList.fold<double>(0, (sum, p) => sum + p.monto)
        : (double.tryParse(json['montoTotalCiclo']?.toString() ?? '0') ?? 0.0);

    final turnoBeneficiario = json['turnoBeneficiario'];
    final nombreBeneficiario = turnoBeneficiario != null && turnoBeneficiario['usuario'] != null
        ? (turnoBeneficiario['usuario']['nombre'] ?? 'Sin asignar')
        : (json['nombreBeneficiario'] ?? 'Sin asignar');

    return Ciclo(
      numeroCiclo: json['numeroCiclo'] ?? 1,
      fechaLimite: json['fechaLimite'] != null
          ? DateTime.tryParse(json['fechaLimite']) ?? DateTime.now()
          : DateTime.now(),
      nombreBeneficiario: nombreBeneficiario,
      montoTotalCiclo: montoTotal,
      cerrado: json['cerrado'] ?? false,
      pagos: pagosList,
    );
  }
}

class TandaDetalle {
  final Tanda tandaBase;
  final List<Miembro> miembros;
  final Ciclo? cicloActual;

  TandaDetalle({
    required this.tandaBase,
    required this.miembros,
    this.cicloActual,
  });

  factory TandaDetalle.fromJson(Map<String, dynamic> json, String currentUserId) {
    var list = json['miembros'] as List? ?? [];
    List<Miembro> miembrosList = list.map((i) => Miembro.fromJson(i)).toList();

    // El admin de la tanda siempre se muestra como ADMIN, incluso si además
    // tiene una fila de membresía (p.ej. se unió después como participante
    // con rol MIEMBRO) o si no tiene fila de membresía en absoluto.
    final esAdmin = json['adminId'] == currentUserId;
    final miMiembro = list.firstWhere(
      (m) => m['usuario'] != null && m['usuario']['id'] == currentUserId,
      orElse: () => null
    );
    final miRol = esAdmin ? 'ADMIN' : (miMiembro != null ? miMiembro['rol'] : 'MIEMBRO');

    // Mapear Tanda base
    final tandaBase = Tanda(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      montoAportacion: double.tryParse(json['montoAportacion']?.toString() ?? '0') ?? 0.0,
      frecuencia: TandaFrecuencia.fromString(json['frecuencia'] ?? ''),
      numParticipantes: json['numParticipantes'] ?? 0,
      numMiembrosActuales: miembrosList.length,
      estado: TandaEstado.fromString(json['estado'] ?? ''),
      rolDelUsuario: TandaRol.fromString(miRol ?? ''),
    );

    // Mapear ciclo actual (si lo manda el backend, aquí lo adaptamos simple por ahora)
    Ciclo? cicloActual;
    if (json['cicloActual'] != null) {
      cicloActual = Ciclo.fromJson(json['cicloActual']);
    } else if (json['ciclos'] != null && (json['ciclos'] as List).isNotEmpty) {
      final ultimo = (json['ciclos'] as List).last;
      cicloActual = Ciclo.fromJson(ultimo);
    }

    // El beneficiario de cada ciclo no aporta su propia parte (por eso los
    // pagos que manda el backend son N-1), pero el bote que recibe sigue
    // siendo el total completo: numParticipantes * montoAportacion.
    if (cicloActual != null) {
      cicloActual = Ciclo(
        numeroCiclo: cicloActual.numeroCiclo,
        fechaLimite: cicloActual.fechaLimite,
        nombreBeneficiario: cicloActual.nombreBeneficiario,
        montoTotalCiclo: tandaBase.numParticipantes * tandaBase.montoAportacion,
        cerrado: cicloActual.cerrado,
        pagos: cicloActual.pagos,
      );
    }

    return TandaDetalle(
      tandaBase: tandaBase,
      miembros: miembrosList,
      cicloActual: cicloActual,
    );
  }
}
