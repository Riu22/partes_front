import 'package:flutter/material.dart';
import '../models/perfil.dart';

class PerfilesSelector extends StatefulWidget {
  final List<Perfil> perfiles;
  final Set<String> seleccionados;
  final void Function(Set<String>) onChanged;

  const PerfilesSelector({
    super.key,
    required this.perfiles,
    required this.seleccionados,
    required this.onChanged,
  });

  @override
  State<PerfilesSelector> createState() => _PerfilesSelectorState();
}

class _PerfilesSelectorState extends State<PerfilesSelector> {
  String _busqueda = '';
  final _ctrl = TextEditingController();

  List<Perfil> get _filtrados {
    var result = widget.perfiles;
    final q = _busqueda.toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((p) =>
        p.apellidos.toLowerCase().contains(q) ||
        p.nombre.toLowerCase().contains(q)
      ).toList();
    }
    return result;
  }

  void _seleccionarTodos() {
    widget.onChanged(widget.perfiles.map((p) => p.id).toSet());
  }

  void _seleccionarNinguno() {
    widget.onChanged({});
  }

  void _seleccionarEspecialidad(String esp) {
    widget.onChanged(
      widget.perfiles
          .where((p) => p.especialidad == esp)
          .map((p) => p.id)
          .toSet(),
    );
  }

  void _seleccionarPostventa() {
    widget.onChanged(
      widget.perfiles
          .where((p) => p.postventa)
          .map((p) => p.id)
          .toSet(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final totalSel = widget.seleccionados.length;
    final total = widget.perfiles.length;
    final todasSel = totalSel == total && total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                totalSel == 0
                    ? 'Operarios'
                    : 'Operarios ($totalSel de $total)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _seleccionarTodos,
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Todos'),
            ),
            TextButton.icon(
              onPressed: _seleccionarNinguno,
              icon: const Icon(Icons.deselect, size: 16),
              label: const Text('Ninguno'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Buscar operario...',
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
        Wrap(
          spacing: 8,
          children: [
            _AccionEspecialidad(
              label: 'Electricidad',
              icono: Icons.electrical_services,
              color: Colors.amber[700]!,
              onTap: () => _seleccionarEspecialidad('ELECTRICIDAD'),
            ),
            _AccionEspecialidad(
              label: 'Fontanería',
              icono: Icons.plumbing,
              color: Colors.blue[700]!,
              onTap: () => _seleccionarEspecialidad('FONTANERIA'),
            ),
            _AccionEspecialidad(
              label: 'Postventa',
              icono: Icons.verified_user,
              color: Colors.purple[700]!,
              onTap: _seleccionarPostventa,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: filtrados.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No hay operarios que coincidan')),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final p = filtrados[i];
                    final sel = widget.seleccionados.contains(p.id);
                    // Icono de especialidad visual para identificar rápidamente el tipo
                    final espLabel = p.especialidad == 'ELECTRICIDAD'
                        ? '⚡'
                        : p.especialidad == 'FONTANERIA'
                        ? '🔧'
                        : '';
                    return ListTile(
                      dense: true,
                      leading: Checkbox(
                        value: sel,
                        onChanged: (_) {
                          final nuevos = Set<String>.from(widget.seleccionados);
                          sel ? nuevos.remove(p.id) : nuevos.add(p.id);
                          widget.onChanged(nuevos);
                        },
                      ),
                      title: Text(
                        p.nombreApellidoCompleto,
                        style: TextStyle(
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: espLabel.isNotEmpty
                          ? Text(espLabel, style: const TextStyle(fontSize: 16))
                          : null,
                      onTap: () {
                        final nuevos = Set<String>.from(widget.seleccionados);
                        sel ? nuevos.remove(p.id) : nuevos.add(p.id);
                        widget.onChanged(nuevos);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AccionEspecialidad extends StatelessWidget {
  final String label;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _AccionEspecialidad({
    required this.label,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11),
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        icon: Icon(icono, size: 14),
        label: Text(label),
      ),
    );
  }
}
