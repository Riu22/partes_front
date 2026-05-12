class DiaIncompleto {
  final String fecha;
  final String horas;

  const DiaIncompleto({required this.fecha, required this.horas});
}

class AusenciaInfo {
  final String perfilId;
  final String nombre;
  final List<String> diasSin;
  final List<DiaIncompleto> diasIncompletos;
  final int totalLaborables;

  const AusenciaInfo({
    required this.perfilId,
    required this.nombre,
    required this.diasSin,
    required this.diasIncompletos,
    required this.totalLaborables,
  });

  int get totalIncidencias => diasSin.length + diasIncompletos.length;
}
