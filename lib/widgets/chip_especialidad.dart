// =============================================================================
// chip_especialidad.dart  -  Etiqueta de especialidad (ELECT. / FONT.)
// =============================================================================
// ASPECTO EN PANTALLA:
//   Pequeno rectangulo con fondo de color y texto en blanco.
//   "ELECT." sobre fondo azul, "FONT." sobre fondo naranja/marron.
//   Texto en negrita mayuscula, tamano 9, interletrado ligero.
//
// USO:
//   Indicar rapidamente si un parte es de electricidad o fontaneria.
//   Se coloca junto a las horas en la tarjeta de parte.
//
// DATOS QUE NECESITA:
//   - especialidad: String (ej: "ELECTRICIDAD" o "FONTANERIA")
//   - esElec: bool que determina color y texto
//
// INTERACCION DEL USUARIO:
//   Solo informativo, no es interactivo.
// =============================================================================

/// Etiqueta pequeña que indica la especialidad: "ELECT." para electricidad
/// o "FONT." para fontanería. Cambia de color según el tipo.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';

/// Chip visual de especialidad. Muestra "ELECT." en azul o "FONT." en
/// naranja. Widget ligero sin estado ([StatelessWidget]).
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
        // Color de fondo segun especialidad.
        color: esElec ? chipElec : chipFont,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        // Texto abreviado: "ELECT." o "FONT.".
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
