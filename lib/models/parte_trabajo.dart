class ParteTrabajo {
  final int id;
  final int? obraId;
  final String obraNombre;
  final String operarioNombre;
  final String operarioApellidos;
  final DateTime fecha;
  final double horasNormales;
  final String descripcion;
  final String? especialidad;
  final String? operarioId;
  final bool creadoPorGestor;
  final String? firmaUrl;
  final String? nombreFirma; // ← nuevo

  ParteTrabajo({
    required this.id,
    this.obraId,
    required this.obraNombre,
    required this.operarioNombre,
    this.operarioApellidos = '',
    required this.fecha,
    required this.horasNormales,
    required this.descripcion,
    this.especialidad,
    this.operarioId,
    this.creadoPorGestor = false,
    this.firmaUrl,
    this.nombreFirma,
  });

  String get operarioNombreCompleto {
    final ap = operarioApellidos.trim();
    final nm = operarioNombre.trim();
    if (ap.isEmpty) return nm;
    return '$ap, $nm';
  }

  factory ParteTrabajo.fromJson(Map<String, dynamic> json) => ParteTrabajo(
    id: json['id'],
    obraId: json['obra']?['id'],
    obraNombre: json['obra']?['nombre'] ?? 'Sin obra',
    operarioNombre: json['perfil']?['name'] ?? 'Sin nombre',
    operarioApellidos: json['perfil']?['apellidos'] ?? '',
    fecha: DateTime.parse(json['fecha']),
    horasNormales: (json['horas_normales'] ?? 8.0).toDouble(),
    descripcion: json['descripcion'] ?? '',
    especialidad: json['especialidad'],
    operarioId: json['perfil']?['id'],
    creadoPorGestor:
        json['creado_por_gestor'] == true || json['creado_por_gestor'] == 1,
    firmaUrl: json['firma_url'],
    nombreFirma: json['nombre_firmado'],
  );

  bool get puedeEditarse {
    final hoy = DateTime.now();
    return fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
  }

  bool puedeEditarseConFechas(List<DateTime> fechasPermitidas) {
    if (puedeEditarse) return true;
    return fechasPermitidas.any(
      (f) =>
          f.year == fecha.year && f.month == fecha.month && f.day == fecha.day,
    );
  }
}
