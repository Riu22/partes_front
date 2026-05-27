class Obra {
  final int id;
  final String nombre;
  final String ubicacion;
  final String municipio;
  final String poblacion;
  final String codigo;
  final bool activa;

  Obra({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.poblacion,
    required this.municipio,
    required this.codigo,
    required this.activa,
  });

  factory Obra.fromJson(Map<String, dynamic> json) => Obra(
  id: json['id'] as int,
  nombre: json['nombre'] as String? ?? '',
  ubicacion: json['ubicacion'] as String? ?? '',
  municipio: json['municipio'] as String? ?? '',
  poblacion: json['poblacion'] as String? ?? '',
  codigo: json['codigo'] as String? ?? '',
  activa: json['activa'] as bool? ?? true,
);
}
