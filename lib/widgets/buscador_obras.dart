// =============================================================================
// buscador_obras.dart  -  Campo de busqueda de obras en pantalla
// =============================================================================
// ASPECTO EN PANTALLA:
//   TextField con borde, icono de edificio (business) a la izquierda,
//   label "Buscar por obra" y, cuando hay texto, un boton "X" a la derecha
//   para limpiar. Diseno compacto (isDense).
//
// USO:
//   Filtrar obras dentro de la misma pagina sin abrir un modal.
//   Se usa en pantallas donde ya hay una lista de obras cargada.
//
// DATOS QUE NECESITA:
//   - controller: TextEditingController para manejar el texto
//   - onChanged: callback sin parametros que se dispara al escribir o limpiar
//
// INTERACCION DEL USUARIO:
//   - Escribir actualiza el controller y llama a onChanged
//   - Tocar la "X" limpia el campo, llama a onChanged y actualiza la UI
//   - Pulsar Enter tambien llama a onChanged
// =============================================================================

/// Campo de texto para buscar obras dentro de la misma pantalla.
/// Incluye un botón para borrar el texto rápidamente.
import 'package:flutter/material.dart';

/// Widget de busqueda de obras con boton de limpieza.
///
/// [StatefulWidget] porque necesita setState() para mostrar/ocultar
/// el icono de limpiar segun si hay texto.
class BuscadorObrasFiltro extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const BuscadorObrasFiltro({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<BuscadorObrasFiltro> createState() => _BuscadorObrasFiltroState();
}

class _BuscadorObrasFiltroState extends State<BuscadorObrasFiltro> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: 'Buscar por obra',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.business),
        isDense: true,
        // Boton para limpiar el texto rapidamente.
        // Solo visible si hay texto en el controller.
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged();
                },
              )
            : null,
      ),
      // Actualiza el estado del sufijo (limpiar) mientras escribes.
      // onChanged se llama cada vez que el texto cambia.
      onChanged: (value) {
        setState(() {}); // Reconstruye para mostrar/ocultar el icono X.
        widget.onChanged();
      },
      onSubmitted: (_) => widget.onChanged(),
    );
  }
}
