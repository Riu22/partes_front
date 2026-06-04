// =============================================================================
// stat_box.dart  -  Caja de estadistica simple
// =============================================================================
// ASPECTO EN PANTALLA:
//   Rectangulo pequeno con fondo gris claro, borde redondeado.
//   Arriba: label en gris tamano 10. Abajo: valor grande en negrita
//   (20px). El color del valor se puede personalizar (por defecto
//   textPrimary).
//
// USO:
//   Mostrar metricas simples como total de horas, cantidad de partes,
//   horas de hoy, etc. Se usa dentro de [ResumenSemanal].
//
// DATOS QUE NECESITA:
//   - label: texto explicativo (ej: "Total", "Partes", "Hoy")
//   - value: string con el valor (ej: "40h", "5")
//   - valueColor: color opcional del valor (ej: azul para total)
//
// INTERACCION DEL USUARIO:
//   Solo informativo, no interactivo.
// =============================================================================

/// Caja de estadística simple con una etiqueta y un valor grande.
/// Se usa en el resumen semanal y otras pantallas para mostrar
/// totales como horas, cantidad de partes, etc.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';

/// Caja con label y valor numerico grande. Ligero y reutilizable.
///
/// [StatelessWidget] porque solo muestra datos, no tiene estado.
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgStat,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: valueColor ?? textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
