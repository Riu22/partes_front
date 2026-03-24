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
    id: json['id'],
    email: json['email'],
    nombreCompleto: json['name'] ?? '',
    rol: json['rol'],
    activo: json['activo'] ?? true,
  );

  bool get esAdmin => rol == 'ADMINISTRACION';
  bool get esGestion => rol == 'GESTION' || esAdmin;
  bool get esJefeObra => rol == 'JEFE_DE_OBRA';
  bool get esEncargado => rol == 'ENCARGADO';
  bool get esOperario => rol == 'OPERARIO';
}
