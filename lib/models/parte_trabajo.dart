class ParteTrabajo {
  final int id;
  final String obraNombre;
  final String operarioNombre;
  final DateTime fecha;
  final double horasNormales;
  final String descripcion;
  final bool firmado;

  ParteTrabajo({
    required this.id,
    required this.obraNombre,
    required this.operarioNombre,
    required this.fecha,
    required this.horasNormales,
    required this.descripcion,
    required this.firmado,
  });

  factory ParteTrabajo.fromJson(Map<String, dynamic> json) => ParteTrabajo(
    id: json['id'],
    obraNombre: json['obra']?['nombre'] ?? 'Sin obra',
    operarioNombre: json['perfil']?['name'] ?? 'Sin nombre',
    fecha: DateTime.parse(json['fecha']),
    horasNormales: (json['horas_normales'] ?? 8.0).toDouble(),
    descripcion: json['descripcion'] ?? '',
    firmado: json['firmado'] ?? false,
  );
}
