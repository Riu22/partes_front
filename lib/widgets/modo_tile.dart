// =============================================================================
// modo_tile.dart  -  Selector de modo (normal / jefe de obra)
// =============================================================================
// ASPECTO EN PANTALLA:
//   Recuadro con icono arriba, titulo en negrita y subtitulo pequeno.
//   Cuando esta SELECCIONADO: fondo azul claro, borde azul grueso.
//   Cuando NO: fondo gris claro, borde gris fino.
//
// USO:
//   Pantalla de seleccion de modo al iniciar la app o cambiar de perfil.
//   Dos opciones: "Partes normales" y "Partes jefe de obra".
//
// DATOS QUE NECESITA:
//   - label: titulo en negrita
//   - subtitulo: texto explicativo debajo
//   - icono: IconData a mostrar
//   - seleccionado: bool que determina el estilo visual
//   - onTap: callback al tocar
//
// INTERACCION DEL USUARIO:
//   Tocar el tile lo selecciona (cambia el estilo visual).
//   El padre debe gestionar la logica de seleccion unica.
// =============================================================================

/// Widget para seleccionar entre modo normal y modo jefe de obra.
/// Cada opción se muestra como un recuadro con icono, título y subtítulo.
import 'package:flutter/material.dart';

/// Tile seleccionable de modo con icono, titulo y subtitulo.
///
/// [StatelessWidget]: toda la info viene de parametros.
class ModoTile extends StatelessWidget {
  final String label;
  final String subtitulo;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const ModoTile({
    super.key,
    required this.label,
    required this.subtitulo,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Color principal: azul si seleccionado, gris si no.
    final color = seleccionado ? const Color(0xFF1565C0) : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Fondo: azul claro si seleccionado, gris muy claro si no.
          color: seleccionado ? const Color(0xFFE3EDFF) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          // Borde: grueso si seleccionado, fino si no.
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
