// =============================================================================
// boton_especialidad.dart  -  Boton de filtro por especialidad
// =============================================================================
// ASPECTO EN PANTALLA:
//   Rectangulo con icono arriba y texto abajo. Cuando NO esta seleccionado
//   se ve semitransparente con borde fino. Cuando esta SELECCIONADO se
//   vuelve totalmente opaco, el texto e icono se ponen blancos y el borde
//   se hace mas grueso.
//
// USO:
//   Filtro visual para alternar entre "Electricidad" y "Fontaneria" en
//   pantallas de listado de partes. Normalmente se colocan dos botones
//   lado a lado.
//
// DATOS QUE NECESITA:
//   - label: texto a mostrar (ej: "ELECTRICIDAD")
//   - icono: IconData de Flutter (ej: Icons.bolt)
//   - color: color base de la especialidad
//   - seleccionado: bool que indica si este filtro esta activo
//   - onTap: callback cuando el usuario toca el boton
//
// INTERACCION DEL USUARIO:
//   Tocar el boton alterna el filtro. El widget padre debe gestionar
//   que solo uno (o varios) esten seleccionados.
// =============================================================================

/// Botón para filtrar por especialidad (Electricidad / Fontanería).
/// Cambia de color y estilo cuando está seleccionado.
import 'package:flutter/material.dart';

/// Boton cuadrado con icono + label que representa una especialidad.
///
/// [StatelessWidget] porque no tiene estado mutable; toda la informacion
/// visual viene de los parametros y del padre.
class BotonEspecialidad extends StatelessWidget {
  final String label;
  final IconData icono;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const BotonEspecialidad({
    super.key,
    required this.label,
    required this.icono,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // [GestureDetector] envuelve al container para detectar taps.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Padding vertical para dar altura al boton.
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          // Color solido si seleccionado, muy transparente si no.
          color: seleccionado ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          // Borde mas grueso si esta seleccionado para destacarlo.
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        // Columna vertical: icono arriba, texto abajo.
        child: Column(
          children: [
            Icon(icono, color: seleccionado ? Colors.white : color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
