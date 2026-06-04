/// Selector múltiple de obras con campo de búsqueda.
/// Permite seleccionar una o varias obras de la lista mediante checkboxes.
/// Incluye botones para seleccionar todas o ninguna.
import 'package:flutter/material.dart';
import '../models/obra.dart';

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

  List<Obra> get _filtradas {
    final base = [
      ...widget.obras,
    ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    if (_busqueda.isEmpty) return base;
    final q = _busqueda.toLowerCase();
    return base.where((o) => o.nombre.toLowerCase().contains(q)).toList();
  }

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
        Row(
          children: [
            Expanded(
              child: Text(
                totalSel == 0
                    ? 'Obras (vacío = todas)'
                    : 'Obras ($totalSel de $total seleccionadas)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Buscar obra...',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
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
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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
