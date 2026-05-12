import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/obras_provider.dart';
import '../../providers/perfiles_provider.dart';
import '../../models/obra.dart';
import '../../models/perfil.dart';
import '../../widgets/app_drawer.dart';

// Modo de exportación
enum _ModoExport { zip, pdf }

// Parámetros del informe
class _PdfParams {
  final DateTime desde;
  final DateTime hasta;
  final List<int> obraIds;
  final List<String> perfilIds;
  final _ModoExport modo;

  const _PdfParams({
    required this.desde,
    required this.hasta,
    required this.obraIds,
    required this.perfilIds,
    required this.modo,
  });

  @override
  bool operator ==(Object other) =>
      other is _PdfParams &&
      desde == other.desde &&
      hasta == other.hasta &&
      obraIds.toString() == other.obraIds.toString() &&
      perfilIds.toString() == other.perfilIds.toString() &&
      modo == other.modo;

  @override
  int get hashCode =>
      Object.hash(desde, hasta, obraIds.toString(), perfilIds.toString(), modo);
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final _exportProvider = FutureProvider.family<Uint8List, _PdfParams>((
  ref,
  params,
) async {
  if (params.modo == _ModoExport.zip) {
    return ref
        .read(apiServiceProvider)
        .generarZipPartes(
          desde: params.desde,
          hasta: params.hasta,
          obraIds: params.obraIds,
          perfilIds: params.perfilIds,
        );
  } else {
    return ref
        .read(apiServiceProvider)
        .generarPdfPartes(
          desde: params.desde,
          hasta: params.hasta,
          obraIds: params.obraIds,
          perfilIds: params.perfilIds,
        );
  }
});

// ─── Pantalla principal ───────────────────────────────────────────────────────
class InformePartesScreen extends ConsumerStatefulWidget {
  const InformePartesScreen({super.key});

  @override
  ConsumerState<InformePartesScreen> createState() =>
      _InformePartesScreenState();
}

class _InformePartesScreenState extends ConsumerState<InformePartesScreen> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();

  final Set<int> _obrasSeleccionadas = {};
  final Set<String> _perfilesSeleccionados = {};
  _ModoExport _modo = _ModoExport.zip;
  _PdfParams? _params;

  Future<void> _pickFecha({required bool esDe}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDe ? _desde : _hasta,
      firstDate: esDe ? DateTime(2020) : _desde,
      lastDate: esDe ? _hasta : DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (esDe) {
        _desde = picked;
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = picked;
      }
      _params = null;
    });
  }

  void _generarInforme() {
    setState(() {
      _params = _PdfParams(
        desde: _desde,
        hasta: _hasta,
        obraIds: _obrasSeleccionadas.toList(),
        perfilIds: _perfilesSeleccionados.toList(),
        modo: _modo,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Informe de partes')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Rango de fechas ──────────────────────────────────
                  const Text(
                    'Rango de fechas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _FechaTile(
                          label: 'Desde',
                          fecha: _desde,
                          onTap: () => _pickFecha(esDe: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FechaTile(
                          label: 'Hasta',
                          fecha: _hasta,
                          onTap: () => _pickFecha(esDe: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Selector de obras ────────────────────────────────
                  obrasAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (obras) => _ObrasSelector(
                      obras: obras,
                      seleccionadas: _obrasSeleccionadas,
                      onChanged: (ids) => setState(() {
                        _obrasSeleccionadas
                          ..clear()
                          ..addAll(ids);
                        _params = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Selector de operarios ────────────────────────────
                  perfilesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (perfiles) => _PerfilesSelector(
                      perfiles: perfiles.where((p) => p.activo).toList(),
                      seleccionados: _perfilesSeleccionados,
                      onChanged: (ids) => setState(() {
                        _perfilesSeleccionados
                          ..clear()
                          ..addAll(ids);
                        _params = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Modo de exportación ──────────────────────────────
                  const Text(
                    'Formato de exportación',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ModoTile(
                          label: 'ZIP (un PDF por obra)',
                          subtitulo: 'Cada obra en un archivo separado',
                          icono: Icons.folder_zip,
                          seleccionado: _modo == _ModoExport.zip,
                          onTap: () => setState(() {
                            _modo = _ModoExport.zip;
                            _params = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModoTile(
                          label: 'PDF único',
                          subtitulo: 'Todas las obras en un archivo',
                          icono: Icons.picture_as_pdf,
                          seleccionado: _modo == _ModoExport.pdf,
                          onTap: () => setState(() {
                            _modo = _ModoExport.pdf;
                            _params = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Botón generar ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _generarInforme,
                      icon: Icon(
                        _modo == _ModoExport.zip
                            ? Icons.folder_zip
                            : Icons.picture_as_pdf,
                      ),
                      label: Text(
                        _modo == _ModoExport.zip
                            ? 'Generar ZIP'
                            : 'Generar PDF',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // ── Resultado ────────────────────────────────────────
                  if (_params != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _ExportPreview(params: _params!),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Modelo interno de chip ───────────────────────────────────────────────────
class _GrupoChip {
  final String label;
  final IconData icono;
  final Color color;
  final Color colorFondo;

  const _GrupoChip({
    required this.label,
    required this.icono,
    required this.color,
    required this.colorFondo,
  });
}

// ─── Selector de obras — lista plana ─────────────────────────────────────────
class _ObrasSelector extends StatefulWidget {
  final List<Obra> obras;
  final Set<int> seleccionadas;
  final void Function(Set<int>) onChanged;

  const _ObrasSelector({
    required this.obras,
    required this.seleccionadas,
    required this.onChanged,
  });

  @override
  State<_ObrasSelector> createState() => _ObrasSelectorState();
}

class _ObrasSelectorState extends State<_ObrasSelector> {
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
        // Cabecera
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => _toggleTodas(!todasSel),
              icon: Icon(
                todasSel ? Icons.deselect : Icons.select_all,
                size: 16,
              ),
              label: Text(
                todasSel ? 'Ninguna' : 'Todas',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Buscador
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Buscar obra...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
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

        // Lista plana
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 260),
          child: filtradas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No hay obras que coincidan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
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
                        activeColor: const Color(0xFF1565C0),
                      ),
                      title: Text(
                        o.nombre,
                        style: TextStyle(
                          fontSize: 13,
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

// ─── Selector de perfiles con chips de especialidad ───────────────────────────
class _PerfilesSelector extends StatefulWidget {
  final List<Perfil> perfiles;
  final Set<String> seleccionados;
  final void Function(Set<String>) onChanged;

  const _PerfilesSelector({
    required this.perfiles,
    required this.seleccionados,
    required this.onChanged,
  });

  @override
  State<_PerfilesSelector> createState() => _PerfilesSelectorState();
}

class _PerfilesSelectorState extends State<_PerfilesSelector> {
  String _busqueda = '';
  final _ctrl = TextEditingController();
  String? _grupoActivo; // null = todos

  static const _grupos = [
    _GrupoChip(
      label: 'Postventa',
      icono: Icons.home_repair_service,
      color: Color(0xFF7B1FA2),
      colorFondo: Color(0xFFF3E5F5),
    ),
    _GrupoChip(
      label: 'Electricidad',
      icono: Icons.bolt,
      color: Color(0xFFF9A825),
      colorFondo: Color(0xFFFFF8E1),
    ),
    _GrupoChip(
      label: 'Fontanería',
      icono: Icons.water_drop,
      color: Color(0xFF0288D1),
      colorFondo: Color(0xFFE1F5FE),
    ),
  ];

  String _labelEspecialidad(String esp) {
    switch (esp.toUpperCase()) {
      case 'ELECTRICIDAD':
        return 'Electricidad';
      case 'FONTANERIA':
      case 'FONTANERÍA':
        return 'Fontanería';
      default:
        return esp.isEmpty ? 'Sin especialidad' : esp;
    }
  }

  bool _perteneceGrupo(Perfil p, String grupo) {
    if (grupo == 'Postventa') return p.postventa;
    return _labelEspecialidad(p.especialidad) == grupo && !p.postventa;
  }

  List<Perfil> get _filtrados {
    var base = [...widget.perfiles]
      ..sort(
        (a, b) =>
            a.apellidos.toLowerCase().compareTo(b.apellidos.toLowerCase()),
      );
    if (_grupoActivo != null) {
      base = base.where((p) => _perteneceGrupo(p, _grupoActivo!)).toList();
    }
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      base = base
          .where(
            (p) =>
                p.nombre.toLowerCase().contains(q) ||
                p.apellidos.toLowerCase().contains(q),
          )
          .toList();
    }
    return base;
  }

  void _toggleTodos(bool seleccionar) {
    final visibles = _filtrados.map((p) => p.id).toSet();
    final nuevos = Set<String>.from(widget.seleccionados);
    seleccionar ? nuevos.addAll(visibles) : nuevos.removeAll(visibles);
    widget.onChanged(nuevos);
  }

  bool get _todosVisiblesSeleccionados {
    final visibles = _filtrados;
    if (visibles.isEmpty) return false;
    return visibles.every((p) => widget.seleccionados.contains(p.id));
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
    final todasSel = _todosVisiblesSeleccionados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                totalSel == 0
                    ? 'Operarios (vacío = todos)'
                    : 'Operarios ($totalSel de $total seleccionados)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => _toggleTodos(!todasSel),
              icon: Icon(
                todasSel ? Icons.deselect : Icons.select_all,
                size: 16,
              ),
              label: Text(
                todasSel ? 'Ninguno' : 'Todos',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Chips de especialidad ─────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Chip "Todos"
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Todos'),
                  avatar: const Icon(Icons.group, size: 16),
                  selected: _grupoActivo == null,
                  onSelected: (_) => setState(() => _grupoActivo = null),
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: Colors.grey.shade300,
                  checkmarkColor: Colors.black87,
                  labelStyle: TextStyle(
                    fontWeight: _grupoActivo == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              // Chips por especialidad
              ..._grupos.map((g) {
                final activo = _grupoActivo == g.label;
                final countSel = widget.perfiles
                    .where(
                      (p) =>
                          _perteneceGrupo(p, g.label) &&
                          widget.seleccionados.contains(p.id),
                    )
                    .length;
                final countTotal = widget.perfiles
                    .where((p) => _perteneceGrupo(p, g.label))
                    .length;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      g.icono,
                      size: 16,
                      color: activo ? Colors.white : g.color,
                    ),
                    label: Text(
                      countSel > 0
                          ? '${g.label} ($countSel/$countTotal)'
                          : g.label,
                    ),
                    selected: activo,
                    onSelected: (_) =>
                        setState(() => _grupoActivo = activo ? null : g.label),
                    backgroundColor: g.colorFondo,
                    selectedColor: g.color,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: activo ? Colors.white : g.color,
                      fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: activo ? g.color : g.color.withOpacity(0.4),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Buscador ──────────────────────────────────────────────────
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o apellidos...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
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

        // ── Lista plana ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 280),
          child: filtrados.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No hay operarios que coincidan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final p = filtrados[i];
                    final sel = widget.seleccionados.contains(p.id);
                    final chipGrupo = _grupos.firstWhere(
                      (g) => _perteneceGrupo(p, g.label),
                      orElse: () => const _GrupoChip(
                        label: 'Otro',
                        icono: Icons.person,
                        color: Color(0xFF9E9E9E),
                        colorFondo: Color(0xFFF5F5F5),
                      ),
                    );
                    return ListTile(
                      dense: true,
                      leading: Checkbox(
                        value: sel,
                        onChanged: (_) {
                          final nuevos = Set<String>.from(widget.seleccionados);
                          sel ? nuevos.remove(p.id) : nuevos.add(p.id);
                          widget.onChanged(nuevos);
                        },
                        activeColor: const Color(0xFF1565C0),
                      ),
                      title: Text(
                        p.nombreApellidoCompleto,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: chipGrupo.colorFondo,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: chipGrupo.color.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              chipGrupo.icono,
                              size: 11,
                              color: chipGrupo.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              chipGrupo.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: chipGrupo.color,
                              ),
                            ),
                          ],
                        ),
                      ),
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

// ─── Widget de resultado ──────────────────────────────────────────────────────
class _ExportPreview extends ConsumerWidget {
  final _PdfParams params;

  const _ExportPreview({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_exportProvider(params));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Generando informe...'),
            ],
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Error al generar el informe:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
      data: (bytes) {
        final esZip = params.modo == _ModoExport.zip;
        final kb = (bytes.length / 1024).toStringAsFixed(1);
        final desde = DateFormat('yyyy-MM-dd').format(params.desde);
        final hasta = DateFormat('yyyy-MM-dd').format(params.hasta);
        final nombre = esZip
            ? 'partes_${desde}_$hasta.zip'
            : 'partes_${desde}_$hasta.pdf';

        return Container(
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    esZip ? Icons.folder_zip : Icons.picture_as_pdf,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${esZip ? 'ZIP' : 'PDF'} generado — $kb KB',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      ref
                          .read(apiServiceProvider)
                          .guardarPdfLocal(bytes, nombre);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Descargando $nombre...'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Descargar'),
                  ),
                ],
              ),
              if (esZip) ...[
                const SizedBox(height: 8),
                Text(
                  'El ZIP contiene un PDF por cada obra seleccionada.\n'
                  'Dentro de cada PDF las partes se agrupan por especialidad '
                  '(Electricidad / Fontanería) y por operario en orden cronológico.',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Tile de modo de exportación ─────────────────────────────────────────────
class _ModoTile extends StatelessWidget {
  final String label;
  final String subtitulo;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ModoTile({
    required this.label,
    required this.subtitulo,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? const Color(0xFF1565C0) : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado ? const Color(0xFFE3EDFF) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
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

// ─── Tile de fecha ────────────────────────────────────────────────────────────
class _FechaTile extends StatelessWidget {
  final String label;
  final DateTime fecha;
  final VoidCallback onTap;

  const _FechaTile({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd/MM/yyyy').format(fecha),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
