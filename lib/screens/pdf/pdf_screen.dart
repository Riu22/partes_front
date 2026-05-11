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

// ─── Modo de exportación ──────────────────────────────────────────────────────
enum _ModoExport { zip, pdf }

// ─── Parámetros del informe ───────────────────────────────────────────────────
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

  /// Selecciona todos los perfiles con postventa = true
  void _seleccionarPostventa(List<Perfil> perfiles) {
    setState(() {
      final postventaIds = perfiles
          .where((p) => p.activo && (p.postventa == true))
          .map((p) => p.id)
          .toSet();
      _perfilesSeleccionados
        ..clear()
        ..addAll(postventaIds);
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
                  // ── Rango de fechas ────────────────────────────────────
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

                  // ── Selector de obras ──────────────────────────────────
                  const Text(
                    'Obras (vacío = todas)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  obrasAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (obras) => _MultiSelector<Obra>(
                      items: obras,
                      selectedIds: _obrasSeleccionadas
                          .map((e) => e as Object)
                          .toSet(),
                      getId: (o) => o.id,
                      getLabel: (o) => o.nombre,
                      getSubtitle: (o) => o.municipio,
                      onToggle: (id) {
                        setState(() {
                          if (_obrasSeleccionadas.contains(id)) {
                            _obrasSeleccionadas.remove(id);
                          } else {
                            _obrasSeleccionadas.add(id as int);
                          }
                          _params = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Selector de operarios ──────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Operarios (vacío = todos)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Botón seleccionar postventa
                      perfilesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (perfiles) => TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purple[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                          ),
                          onPressed: () => _seleccionarPostventa(perfiles),
                          icon: const Icon(Icons.construction, size: 16),
                          label: const Text(
                            'Postventa',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  perfilesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (perfiles) => _MultiSelector<Perfil>(
                      items: perfiles.where((p) => p.activo).toList(),
                      selectedIds: _perfilesSeleccionados,
                      getId: (p) => p.id,
                      getLabel: (p) => p.nombreCompleto,
                      getSubtitle: (p) =>
                          '${p.rol ?? ''}${p.postventa == true ? ' · Postventa' : ''}',
                      onToggle: (id) {
                        setState(() {
                          if (_perfilesSeleccionados.contains(id)) {
                            _perfilesSeleccionados.remove(id);
                          } else {
                            _perfilesSeleccionados.add(id as String);
                          }
                          _params = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Modo de exportación ────────────────────────────────
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

                  // ── Botón generar ──────────────────────────────────────
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

                  // ── Resultado ──────────────────────────────────────────
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

// ─── Selector múltiple genérico ───────────────────────────────────────────────
class _MultiSelector<T> extends StatelessWidget {
  final List<T> items;
  final Set<Object> selectedIds;
  final Object Function(T) getId;
  final String Function(T) getLabel;
  final String Function(T) getSubtitle;
  final void Function(Object) onToggle;

  const _MultiSelector({
    required this.items,
    required this.selectedIds,
    required this.getId,
    required this.getLabel,
    required this.getSubtitle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, i) {
          final item = items[i];
          final id = getId(item);
          final selected = selectedIds.contains(id);

          return ListTile(
            dense: true,
            leading: Checkbox(
              value: selected,
              onChanged: (_) => onToggle(id),
              activeColor: const Color(0xFF1565C0),
            ),
            title: Text(
              getLabel(item),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              getSubtitle(item),
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => onToggle(id),
          );
        },
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
