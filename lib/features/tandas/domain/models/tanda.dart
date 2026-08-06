enum TandaFrecuencia {
  semanal,
  quincenal,
  mensual;

  String get displayName {
    switch (this) {
      case TandaFrecuencia.semanal:
        return 'semanal';
      case TandaFrecuencia.quincenal:
        return 'quincenal';
      case TandaFrecuencia.mensual:
        return 'mensual';
    }
  }

  static TandaFrecuencia fromString(String str) {
    switch (str.toUpperCase()) {
      case 'SEMANAL':
        return TandaFrecuencia.semanal;
      case 'QUINCENAL':
        return TandaFrecuencia.quincenal;
      case 'MENSUAL':
        return TandaFrecuencia.mensual;
      default:
        return TandaFrecuencia.semanal;
    }
  }

  String toBackendString() => displayName.toUpperCase();
}

enum TandaEstado {
  armando,
  activa,
  finalizada,
  cancelada;

  static TandaEstado fromString(String str) {
    switch (str.toUpperCase()) {
      case 'ARMANDO':
        return TandaEstado.armando;
      case 'ACTIVA':
        return TandaEstado.activa;
      case 'FINALIZADA':
        return TandaEstado.finalizada;
      case 'CANCELADA':
        return TandaEstado.cancelada;
      default:
        return TandaEstado.armando;
    }
  }
}

enum TandaRol {
  admin,
  miembro;

  static TandaRol fromString(String str) {
    switch (str.toUpperCase()) {
      case 'ADMIN':
        return TandaRol.admin;
      case 'MIEMBRO':
        return TandaRol.miembro;
      default:
        return TandaRol.miembro;
    }
  }
}

class Tanda {
  final String id;
  final String nombre;
  final String? descripcion;
  final double montoAportacion;
  final TandaFrecuencia frecuencia;
  final int numParticipantes;
  final int numMiembrosActuales;
  final TandaEstado estado;
  final TandaRol rolDelUsuario;

  Tanda({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.montoAportacion,
    required this.frecuencia,
    required this.numParticipantes,
    required this.numMiembrosActuales,
    required this.estado,
    required this.rolDelUsuario,
  });

  factory Tanda.fromJson(Map<String, dynamic> json) {
    return Tanda(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? 'Sin nombre',
      descripcion: json['descripcion'],
      montoAportacion: double.tryParse(json['montoAportacion']?.toString() ?? '0') ?? 0.0,
      frecuencia: TandaFrecuencia.fromString(json['frecuencia'] ?? ''),
      numParticipantes: json['numParticipantes'] ?? 0,
      numMiembrosActuales: json['numMiembrosActuales'] ?? 0,
      estado: TandaEstado.fromString(json['estado'] ?? ''),
      rolDelUsuario: TandaRol.fromString(json['miRol'] ?? ''),
    );
  }
}
