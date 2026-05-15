class Perfil {
  final String id;
  final String email;
  final String nombre;
  final String apellidos;
  final String rol;
  final bool activo;
  final bool postventa;
  final String especialidad;

  Perfil({
    required this.id,
    required this.email,
    required this.nombre,
    required this.apellidos,
    required this.rol,
    required this.activo,
    this.postventa = false,
    this.especialidad = "",
  });

  String get nombreCompleto => '$nombre $apellidos'.trim();
  String get nombreApellidoCompleto => '$apellidos, $nombre'.trim();

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
    );
  }

  // Jerarquía de roles: ADMIN > GESTION > JEFE_DE_OBRA > ENCARGADO > OPERARIO
  bool get esAdmin => rol == 'ADMINISTRACION';
  bool get esGestion => rol == 'GESTION';
  bool get esJefeObra => rol == 'JEFE_DE_OBRA';
  bool get esEncargado => rol == 'ENCARGADO';
  bool get esOperario => rol == 'OPERARIO';

  // Permisos derivados del rol
  bool get puedeVerEquipos => esAdmin || esGestion || esJefeObra || esEncargado;
  bool get puedeValidar => esAdmin || esGestion || esJefeObra || esEncargado;
  bool get puedeCrearParte => esOperario || esEncargado;
  bool get puedeEliminar => esAdmin;

  // Nivel de acceso: determina qué datos puede ver cada rol
  String get nivelAcceso {
    if (esAdmin || esGestion) return 'TOTAL';      // Ven todo
    if (esJefeObra) return 'ZONA';                  // Su zona/asignaciones
    if (esEncargado) return 'OBRA';                 // Sus obras
    return 'INDIVIDUAL';                            // Solo sus partes
  }
}
