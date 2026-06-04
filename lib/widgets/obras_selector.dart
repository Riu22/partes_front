// =============================================================================
// obras_selector.dart  -  Selector multiple de obras con busqueda
// =============================================================================
// ASPECTO EN PANTALLA:
//   Titulo con contador "Obras (N de M seleccionadas)", boton "Todas/Ninguna",
//   campo de busqueda con lupa, y lista con checkboxes dentro de un recuadro
//   con borde y altura maxima de 260px. Si no hay coincidencias: mensaje
//   "No hay obras que coincidan".
//
// USO:
//   Filtrar obras en pantallas de exportacion, informes, o seleccion multiple
//   donde se necesita elegir un subconjunto de obras.
//
// DATOS QUE NECESITA:
//   - obras: List<Obra> completa
//   - seleccionadas: Set<int> con IDs de obras seleccionadas
//   - onChanged: callback con el nuevo Set<int> de seleccionadas
//
// INTERACCION DEL USUARIO:
//   - Escribir en el campo filtra la lista en tiempo real
//   - Tocar un item o su checkbox lo selecciona/deselecciona
//   - Tocar "Todas" selecciona todas, "Ninguna" deselecciona todas
//   - El boton Todas/Ninguna alterna segun el estado actual
// =============================================================================

/// Selector múltiple de obras con campo de búsqueda.
/// Permite seleccionar una o varias obras de la lista mediante checkboxes.
/// Incluye botones para seleccionar todas o ninguna.
import 'package:flutter/material.dart';
import '../models/obra.dart';

/// Selector de obras con checkboxes, busqueda y botones todo/nada.
///
/// [StatefulWidget] porque gestiona el estado del filtro de busqueda.
class ObrasSelector extends StatefulWidget {
  final List<Obra> obras;
  final Set<int> seleccionadas;
  final void Function(Set<int>) onChanged;

  const ObrasSelector({
    super.key,
    required this.obras,
    required this.seleccionadas,
    required this.onChanged,
  });

  @override
  State<ObrasSelector> createState() => _ObrasSelectorState();
}

class _ObrasSelectorState extends State<ObrasSelector> {
  String _busqueda = '';
  final _ctrl = TextEditingController();

  /// Getter que devuelve las obras filtradas por el texto de busqueda
  /// y ordenadas alfabeticamente por nombre.
  List<Obra> get _filtradas {
    final base = [
      ...widget.obras,
    ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    if (_busqueda.isEmpty) return base;
    final q = _busqueda.toLowerCase();
    return base.where((o) => o.nombre.toLowerCase().contains(q)).toList();
  }

  /// Selecciona o deselecciona todas las obras.
  void _toggleTodas(bool seleccionar) {
    final ids = widget.obras.map((o) => o.id).toSet();
    widget.onChanged(seleccionar ? ids : {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;
    final totalSel = widget.seleccionadas.length;
    final total = widget.obras.length;
    final todasSel = totalSel == total && total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CABECERA: titulo + boton Todas/Ninguna ────────────
        Row(
          children: [
            Expanded(
              child: Text(
                totalSel == 0
                    ? 'Obras (vacio = todas)'
                    : 'Obras ($totalSel de $total seleccionadas)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Boton que alterna entre "Todas" y "Ninguna".
            TextButton.icon(
              onPressed: () => _toggleTodas(!todasSel),
              icon: Icon(
                todasSel ? Icons.deselect : Icons.select_all,
                size: 16,
              ),
              label: Text(todasSel ? 'Ninguna' : 'Todas'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── CAMPO DE BUSQUEDA ───────────────────────────────
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Buscar obra...',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            // Boton X para limpiar la busqueda.
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _busqueda = '');
                    },
                  )
                : null,
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),

        // ── LISTA CON CHECKBOXES ────────────────────────────
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: filtradas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No hay obras que coincidan')),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtradas.length,
                  itemBuilder: (context, i) {
                    final o = filtradas[i];
                    final sel = widget.seleccionadas.contains(o.id);
                    return ListTile(
                      dense: true,
                      leading: Checkbox(
                        value: sel,
                        onChanged: (_) {
                          final nuevas = Set<int>.from(widget.seleccionadas);
                          sel ? nuevas.remove(o.id) : nuevas.add(o.id);
                          widget.onChanged(nuevas);
                        },
                      ),
                      title: Text(
                        o.nombre,
                        style: TextStyle(
                          // Negrita si seleccionado, normal si no.
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      // Tocar en cualquier parte del item tambien alterna.
                      onTap: () {
                        final nuevas = Set<int>.from(widget.seleccionadas);
                        sel ? nuevas.remove(o.id) : nuevas.add(o.id);
                        widget.onChanged(nuevas);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
