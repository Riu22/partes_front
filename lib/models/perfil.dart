class Perfil {
  final String id;
  final String email;
  final String nombre;
  final String apellidos;
  final String rol;
  final bool activo;
  final bool postventa;
  final String especialidad;
  final String codigo;
  final String grupoProfesional;

  Perfil({
    required this.id,
    required this.email,
    required this.nombre,
    required this.apellidos,
    required this.rol,
    required this.activo,
    this.postventa = false,
    this.especialidad = 'ELECTRICIDAD',
    this.codigo = '',
    this.grupoProfesional = '',
  });

  // ── Nombres ──────────────────────────────────────────────────────────────
  /// Nombre completo: "Juan Pérez"
  String get nombreCompleto => '$nombre $apellidos'.trim();
  /// Nombre con apellido primero: "Pérez, Juan"
  String get nombreApellidoCompleto => '$apellidos, $nombre'.trim();

  // ── Deserialización ──────────────────────────────────────────────────────
  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nombre: json['name'] ?? '',
      apellidos: json['apellidos'] ?? '',
      rol: json['rol'] ?? 'OPERARIO',
      activo: json['activo'] ?? true,
      postventa: json['postventa'] ?? false,
      especialidad: json['especialidad'] ?? 'ELECTRICIDAD',
      codigo: json['codigo'] ?? '',
      grupoProfesional: json['grupo_profesional'] ?? '',
    );
  }

  /// Convierte el perfil a Map para pasarlo a EditarUsuarioScreen
  /// (mismo formato que espera el widget.usuario)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': nombre,
      'apellidos': apellidos,
      'rol': rol,
      'activo': activo,
      'postventa': postventa,
      'especialidad': especialidad,
      'codigo': codigo,
      'grupo_profesional': grupoProfesional,
    };
  }

  // ── Roles ─────────────────────────────────────────────────────────────────
  // Jerarquía: ADMINISTRACION > GESTION > JEFE_DE_OBRA > ENCARGADO > OPERARIO
  bool get esAdmin => rol == 'ADMINISTRACION';
  bool get esGestion => rol == 'GESTION';
  bool get esJefeObra => rol == 'JEFE_DE_OBRA';
  bool get esEncargado => rol == 'ENCARGADO';
  bool get esOperario => rol == 'OPERARIO';

  // ── Permisos ──────────────────────────────────────────────────────────────
  bool get puedeVerEquipos => esAdmin || esGestion || esJefeObra || esEncargado;
  bool get puedeValidar => esAdmin || esGestion || esJefeObra || esEncargado;
  bool get puedeCrearParte => esOperario || esEncargado;
  bool get puedeEliminar => esAdmin;
  bool get puedeGestionarUsuarios => esAdmin;

  // ── Nivel de acceso ───────────────────────────────────────────────────────
  /// Determina qué datos puede ver cada rol
  String get nivelAcceso {
    if (esAdmin || esGestion) return 'TOTAL';     // Ven todo
    if (esJefeObra) return 'ZONA';                // Su zona/asignaciones
    if (esEncargado) return 'OBRA';               // Sus obras
    return 'INDIVIDUAL';                          // Solo sus partes
  }
}