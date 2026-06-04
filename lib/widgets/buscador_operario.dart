// =============================================================================
// buscador_operario.dart  -  Campo de busqueda de operarios en pantalla
// =============================================================================
// ASPECTO EN PANTALLA:
//   TextField con padding, icono de lupa (search), label "Buscar por nombre..."
//   y boton "X" cuando hay texto. Borde OutlineInputBorder. Diseno compacto.
//
// USO:
//   Filtrar operarios por nombre en pantallas de listado de personal.
//   Comunica al padre mediante callbacks onBuscar y onLimpiar.
//
// DATOS QUE NECESITA:
//   - onBuscar(String): llamado con el texto cada vez que se escribe
//   - onLimpiar: llamado cuando el texto se borra (manual o por la X)
//
// INTERACCION DEL USUARIO:
//   - Escribir en el campo: llama a onBuscar con el texto actual
//   - Si el texto se vacia, llama tambien a onLimpiar
//   - Tocar la "X": limpia el campo, llama a onLimpiar y actualiza UI
// =============================================================================

/// Campo de texto para buscar operarios por nombre en la misma pantalla.
/// Notifica al padre cuando el usuario escribe o limpia la búsqueda.
import 'package:flutter/material.dart';

/// Widget de busqueda de operarios con callbacks de busqueda/limpieza.
///
/// [StatefulWidget] porque gestiona su propio TextEditingController y
/// necesita setState para mostrar/ocultar el icono de limpiar.
class BuscadorOperario extends StatefulWidget {
  final Function(String) onBuscar;
  final VoidCallback onLimpiar;

  const BuscadorOperario({
    super.key,
    required this.onBuscar,
    required this.onLimpiar,
  });

  @override
  State<BuscadorOperario> createState() => _BuscadorOperarioState();
}

class _BuscadorOperarioState extends State<BuscadorOperario> {
  // Controlador interno para el campo de texto.
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: 'Buscar por nombre...',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          // Muestra el icono de limpiar solo si hay texto.
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onLimpiar(); // Notifica al padre que se limpio.
                    setState(() {}); // Oculta el icono X.
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {}); // Reconstruye para el icono X.
          if (value.isEmpty) widget.onLimpiar();
          widget.onBuscar(value);
        },
      ),
    );
  }
}
