class Perfil {
  final String id;
  final String email;
  final String nombreCompleto;
  final String rol;
  final bool activo;

  Perfil({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    required this.rol,
    required this.activo,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
    id: json['id'] ?? '',
    email: json['email'] ?? '',
    nombreCompleto: json['name'] ?? '',
    rol: json['rol'] ?? 'OPERARIO',
    activo: json['activo'] ?? true,
  );

  // --- Identificación de Roles ---
  bool get esAdmin => rol == 'ADMINISTRACION';
  bool get esGestion => rol == 'GESTION';
  bool get esJefeObra => rol == 'JEFE_DE_OBRA';
  bool get esEncargado => rol == 'ENCARGADO';
  bool get esOperario => rol == 'OPERARIO';

  // --- Lógica de Permisos (Jerarquía) ---

  /// ¿Puede ver partes de otros? (Admin, Gestión, Jefe y Encargado)
  bool get puedeVerEquipos => esAdmin || esGestion || esJefeObra || esEncargado;

  /// ¿Puede validar/firmar partes?
  bool get puedeValidar => esAdmin || esGestion || esJefeObra || esEncargado;

  /// ¿Puede crear nuevos partes? Solo operario y encargado
  bool get puedeCrearParte => esOperario || esEncargado;

  /// Restricción específica: Gestión hace todo MENOS eliminar
  bool get puedeEliminar => esAdmin;

  /// Nivel de acceso para filtros en la API
  /// Útil para saber si pedir "mis partes" o "todos los de mi obra"
  String get nivelAcceso {
    if (esAdmin || esGestion) return 'TOTAL';
    if (esJefeObra) return 'ZONA';
    if (esEncargado) return 'OBRA';
    return 'INDIVIDUAL';
  }
}
