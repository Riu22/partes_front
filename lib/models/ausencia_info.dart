import 'package:intl/intl.dart';

enum AusenciaTipo { BAJA, VACACIONES, PATERNIDAD }

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

class AusenciaInfo {
  final String perfilId;
  final String nombre;
  final List<String> diasSin;
  final List<DiaIncompleto> diasIncompletos;
  final List<AusenciaLaboral> ausenciasActivas;
  final int totalLaborables;

  const AusenciaInfo({
    required this.perfilId,
    required this.nombre,
    required this.diasSin,
    required this.diasIncompletos,
    required this.ausenciasActivas,
    required this.totalLaborables,
  });

  int get totalIncidencias => diasSin.length + diasIncompletos.length;

  bool get soloAusencias =>
      diasSin.isEmpty && diasIncompletos.isEmpty && ausenciasActivas.isNotEmpty;

  factory AusenciaInfo.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
