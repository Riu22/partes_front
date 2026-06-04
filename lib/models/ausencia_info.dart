/// Tipos de ausencia laboral que puede tener un operario.
enum AusenciaTipo { BAJA, VACACIONES, PATERNIDAD }

/// Representa un período de ausencia laboral (baja, vacaciones, paternidad).
/// Tiene fecha de inicio y fin, y opcionalmente observaciones.
class AusenciaLaboral {
  final int? id;
  final String tipo;
  final String fechaInicio;
  final String fechaFin;
  final String? observaciones;

  const AusenciaLaboral({
    this.id,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaFin,
    this.observaciones,
  });

  factory AusenciaLaboral.fromJson(Map<String, dynamic> json) {
    return AusenciaLaboral(
      id: json['id'] as int?,
      tipo: json['tipo'] as String,
      fechaInicio: json['fechaInicio'] as String,
      fechaFin: json['fechaFin'] as String,
      observaciones: json['observaciones'] as String?,
    );
  }
}

/// Un día en que el operario trabajó menos horas de las esperadas.
class DiaIncompleto {
  final String fecha;
  final String horas;

  const DiaIncompleto({required this.fecha, required this.horas});

  factory DiaIncompleto.fromJson(Map<String, dynamic> json) {
    return DiaIncompleto(
      fecha: json['fecha'] as String,
      horas: json['horas'].toString(),
    );
  }
}

/// Resumen de incidencias de un operario: días sin parte, días incompletos,
/// ausencias activas, y fechas habilitadas por el gestor.
class AusenciaInfo {
  final String perfilId;
  final String nombre;
  final List<String> diasSin;
  final List<DiaIncompleto> diasIncompletos;
  final List<AusenciaLaboral> ausenciasActivas;
  final int totalLaborables;
  final Set<String> fechasHabilitadas;

  const AusenciaInfo({
    required this.perfilId,
    required this.nombre,
    required this.diasSin,
    required this.diasIncompletos,
    required this.ausenciasActivas,
    required this.totalLaborables,
    this.fechasHabilitadas = const {},
  });

  /// Total de días con incidencias (días sin parte + días incompletos)
  int get totalIncidencias => diasSin.length + diasIncompletos.length;

  /// True si solo tiene ausencias laborales (sin días sin parte ni incompletos)
  bool get soloAusencias =>
      diasSin.isEmpty && diasIncompletos.isEmpty && ausenciasActivas.isNotEmpty;

  factory AusenciaInfo.fromJson(
    Map<String, dynamic> json, [
    Set<String> habilitadas = const {},
  ]) {
    return AusenciaInfo(
      perfilId: json['perfilId'] as String,
      nombre: json['nombre'] as String,
      diasSin: List<String>.from(json['diasSin'] ?? []),
      diasIncompletos: (json['diasIncompletos'] as List<dynamic>? ?? [])
          .map((e) => DiaIncompleto.fromJson(e as Map<String, dynamic>))
          .toList(),
      ausenciasActivas: (json['ausenciasActivas'] as List<dynamic>? ?? [])
          .map((e) => AusenciaLaboral.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalLaborables: json['totalLaborables'] as int? ?? 0,
      fechasHabilitadas: habilitadas,
    );
  }
}
