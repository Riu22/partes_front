/// Etiqueta pequeña que indica la especialidad: "ELECT." para electricidad
/// o "FONT." para fontanería. Cambia de color según el tipo.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';

class ChipEspecialidad extends StatelessWidget {
  final String especialidad;
  final bool esElec;

  const ChipEspecialidad({
    super.key,
    required this.especialidad,
    required this.esElec,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: esElec ? chipElec : chipFont,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        esElec ? 'ELECT.' : 'FONT.',
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
