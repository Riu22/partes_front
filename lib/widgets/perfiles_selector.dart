// =============================================================================
// perfiles_selector.dart  -  Selector multiple de operarios con busqueda
// =============================================================================
// ASPECTO EN PANTALLA:
//   Titulo "Operarios (N de M seleccionados)", botones "Todos" y "Ninguno",
//   campo de busqueda, tres botones de filtro rapido por especialidad
//   (Electricidad, Fontaneria, Postventa), y lista con checkboxes dentro
//   de un recuadro con borde y altura maxima de 280px. Cada item muestra
//   nombre completo, checkbox y un icono de especialidad (unicode).
//
// USO:
//   Seleccionar operarios para filtros de exportacion, informes, o
//   asignacion masiva. Permite filtrar por nombre y por especialidad.
//
// DATOS QUE NECESITA:
//   - perfiles: List<Perfil> completa
//   - seleccionados: Set<String> con IDs de perfiles seleccionados
//   - onChanged: callback con el nuevo Set<String>
//
// INTERACCION DEL USUARIO:
//   - Escribir filtra por nombre o apellido
//   - Tocar "Todos"/"Ninguno" selecciona/deselecciona todo
//   - Tocar "Electricidad"/"Fontaneria"/"Postventa" filtra por especialidad
//   - Tocar un item o su checkbox lo selecciona/deselecciona
// =============================================================================

/// Selector múltiple de perfiles (operarios) con búsqueda.
/// Permite filtrar por nombre, seleccionar por especialidad
/// (Electricidad, Fontanería, Postventa) o elegir todos/ninguno.
import 'package:flutter/material.dart';
import '../models/perfil.dart';

/// Selector de operarios con checkboxes, busqueda, filtros por
/// especialidad y botones todo/nada.
///
/// [StatefulWidget] porque gestiona _busqueda (filtro local).
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

  /// Getter que filtra perfiles por nombre/apellido.
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

  /// Selecciona solo los perfiles de una especialidad concreta.
  void _seleccionarEspecialidad(String esp) {
    widget.onChanged(
      widget.perfiles
          .where((p) => p.especialidad == esp)
          .map((p) => p.id)
          .toSet(),
    );
  }

  /// Selecciona solo los perfiles marcados como postventa.
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
        // ── CABECERA: titulo + Todos/Ninguno ─────────────────
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

        // ── CAMPO DE BUSQUEDA ───────────────────────────────
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

        // ── BOTONES DE FILTRO POR ESPECIALIDAD ──────────────
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

        // ── LISTA CON CHECKBOXES ────────────────────────────
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
                    // Icono de especialidad visual para identificar
                    // rapidamente el tipo.
                    // NOTA: contiene caracteres unicode (rayo, llave).
                    final espLabel = p.especialidad == 'ELECTRICIDAD'
                        ? '\u26A1'
                        : p.especialidad == 'FONTANERIA'
                        ? '\uD83D\uDD27'
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

/// Boton interno para filtro rapido por especialidad.
/// Muestra icono + label con fondo de color y texto blanco.
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
