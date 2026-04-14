class Perfil {
  final String id;
  final String email;
  final String nombreCompleto;
  final String rol;
  final bool activo;
  final bool postventa;

  Perfil({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    required this.rol,
    required this.activo,
    this.postventa = false,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nombreCompleto: json['name'] ?? '',
      rol: json['rol'] ?? 'OPERARIO',
      activo: json['activo'] ?? true,
      postventa: json['postventa'] ?? false,
    );
  }

  bool get esAdmin => rol == 'ADMINISTRACION';
  bool get esGestion => rol == 'GESTION';
  bool get esJefeObra => rol == 'JEFE_DE_OBRA';
  bool get esEncargado => rol == 'ENCARGADO';
  bool get esOperario => rol == 'OPERARIO';

  bool get puedeVerEquipos => esAdmin || esGestion || esJefeObra || esEncargado;
  bool get puedeValidar => esAdmin || esGestion || esJefeObra || esEncargado;
  bool get puedeCrearParte => esOperario || esEncargado;
  bool get puedeEliminar => esAdmin;

  String get nivelAcceso {
    if (esAdmin || esGestion) return 'TOTAL';
    if (esJefeObra) return 'ZONA';
    if (esEncargado) return 'OBRA';
    return 'INDIVIDUAL';
  }
}
