class Obra {
  final int id;
  final String nombre;
  final String ubicacion;
  final String municipio;
  final bool activa;

  Obra({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.municipio,
    required this.activa,
  });

  factory Obra.fromJson(Map<String, dynamic> json) => Obra(
    id: json['id'],
    nombre: json['nombre'],
    ubicacion: json['ubicacion'] ?? '',
    municipio: json['municipio'] ?? '',
    activa: json['activa'] ?? true,
  );
}
