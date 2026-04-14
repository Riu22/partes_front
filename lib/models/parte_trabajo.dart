class ParteTrabajo {
  final int id;
  final int? obraId;
  final String obraNombre;
  final String operarioNombre;
  final DateTime fecha;
  final double horasNormales;
  final String descripcion;
  final String? especialidad;

  ParteTrabajo({
    required this.id,
    this.obraId,
    required this.obraNombre,
    required this.operarioNombre,
    required this.fecha,
    required this.horasNormales,
    required this.descripcion,
    this.especialidad,
  });

  factory ParteTrabajo.fromJson(Map<String, dynamic> json) => ParteTrabajo(
    id: json['id'],
    obraId: json['obra']?['id'],
    obraNombre: json['obra']?['nombre'] ?? 'Sin obra',
    operarioNombre: json['perfil']?['name'] ?? 'Sin nombre',
    fecha: DateTime.parse(json['fecha']),
    horasNormales: (json['horas_normales'] ?? 8.0).toDouble(),
    descripcion: json['descripcion'] ?? '',
    especialidad: json['especialidad'],
  );

  bool get puedeEditarse => DateTime.now().difference(fecha).inDays <= 14;
}
