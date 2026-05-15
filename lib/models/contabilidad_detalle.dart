class ContabilidadDetalle {
  final String codigo;
  final String operario;
  final String grupoProfesional;
  final String obra;
  final Map<DateTime, double> horasPorDia;
  final double totalHoras;

  ContabilidadDetalle({
    required this.codigo,
    required this.operario,
    required this.grupoProfesional,
    required this.obra,
    required this.horasPorDia,
    required this.totalHoras,
  });

  factory ContabilidadDetalle.fromJson(Map<String, dynamic> json) {
    // Convierte el mapa { "2024-01-15": 8.0, ... } del JSON
    // a un Map<DateTime, double> para manejo tipado en Dart
    var horasRaw = json['horas_por_dia'] as Map<String, dynamic>;
    Map<DateTime, double> horasMap = {};
    horasRaw.forEach((key, value) {
      horasMap[DateTime.parse(key)] = (value as num).toDouble();
    });

    return ContabilidadDetalle(
      codigo: json['codigo'] ?? '',
      operario: json['operario'] ?? '',
      grupoProfesional: json['grupo_profesional'] ?? '',
      obra: json['obra'] ?? '',
      horasPorDia: horasMap,
      totalHoras: (json['total_horas'] as num).toDouble(),
    );
  }
}
