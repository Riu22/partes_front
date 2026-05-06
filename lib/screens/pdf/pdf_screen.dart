import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/obras_provider.dart';
import '../../providers/perfiles_provider.dart';
import '../../models/obra.dart';
import '../../models/perfil.dart';

// ─── Provider que llama al backend ───────────────────────────────────────────
final _pdfProvider = FutureProvider.family<Uint8List, _PdfParams>((
  ref,
  params,
) async {
  return ref
      .read(apiServiceProvider)
      .generarPdfPartes(
        desde: params.desde,
        hasta: params.hasta,
        obraIds: params.obraIds,
        perfilIds: params.perfilIds,
      );
});

class _PdfParams {
  final DateTime desde;
  final DateTime hasta;
  final List<int> obraIds;
  final List<String> perfilIds;

  const _PdfParams({
    required this.desde,
    required this.hasta,
    required this.obraIds,
    required this.perfilIds,
  });

  @override
  bool operator ==(Object other) =>
      other is _PdfParams &&
      desde == other.desde &&
      hasta == other.hasta &&
      obraIds.toString() == other.obraIds.toString() &&
      perfilIds.toString() == other.perfilIds.toString();

  @override
  int get hashCode =>
      Object.hash(desde, hasta, obraIds.toString(), perfilIds.toString());
}

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

  _PdfParams? _params;

  Future<void> _pickFecha({required bool esDe}) async {
    final inicial = esDe ? _desde : _hasta;
    final primera = esDe ? DateTime(2020) : _desde;
    final ultima = esDe ? _hasta : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera,
      lastDate: ultima,
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

  void _generarPdf() {
    setState(() {
      _params = _PdfParams(
        desde: _desde,
        hasta: _hasta,
        obraIds: _obrasSeleccionadas.toList(),
        perfilIds: _perfilesSeleccionados.toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Informe de partes')),
      // ── Usamos un Column con Expanded para evitar overflow ──
      body: Column(
        children: [
          // Panel de filtros — scrollable, ocupa lo que necesita
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rango de fechas
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

                  // Selector de obras
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

                  // Selector de operarios
                  const Text(
                    'Operarios (vacío = todos)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      getSubtitle: (p) => p.rol ?? '',
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

                  // Botón generar
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
                      onPressed: _generarPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text(
                        'Generar informe',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Resultado inline — aparece debajo del botón dentro del scroll
                  if (_params != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _PdfPreview(params: _params!),
                  ],

                  // Espacio final para no quedar pegado al borde
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

// ─── Widget de previsualización ───────────────────────────────────────────────
class _PdfPreview extends ConsumerWidget {
  final _PdfParams params;

  const _PdfPreview({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfAsync = ref.watch(_pdfProvider(params));

    return pdfAsync.when(
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
                'Error al generar el PDF:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
      data: (bytes) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de estado + descarga
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PDF generado — ${(bytes.length / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(fontSize: 13),
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
                  onPressed: () => _descargar(context, ref, bytes),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Descargar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Resumen del informe
          _ResumenInforme(params: params),
        ],
      ),
    );
  }

  void _descargar(BuildContext context, WidgetRef ref, Uint8List bytes) {
    final desde = DateFormat('yyyy-MM-dd').format(params.desde);
    final hasta = DateFormat('yyyy-MM-dd').format(params.hasta);
    final nombre = 'partes_${desde}_$hasta.pdf';
    ref.read(apiServiceProvider).guardarPdfLocal(bytes, nombre);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando $nombre...'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// ─── Resumen del informe generado ─────────────────────────────────────────────
class _ResumenInforme extends ConsumerWidget {
  final _PdfParams params;

  const _ResumenInforme({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obrasAsync = ref.watch(obrasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);

    final desde = DateFormat('dd/MM/yyyy').format(params.desde);
    final hasta = DateFormat('dd/MM/yyyy').format(params.hasta);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResumenTile(
            icon: Icons.calendar_today,
            label: 'Período',
            valor: '$desde → $hasta',
          ),
          const SizedBox(height: 10),
          _ResumenTile(
            icon: Icons.business,
            label: 'Obras incluidas',
            valor: params.obraIds.isEmpty
                ? 'Todas'
                : obrasAsync.valueOrNull
                          ?.where((o) => params.obraIds.contains(o.id))
                          .map((o) => o.nombre)
                          .join(', ') ??
                      '${params.obraIds.length} obras',
          ),
          const SizedBox(height: 10),
          _ResumenTile(
            icon: Icons.people,
            label: 'Operarios incluidos',
            valor: params.perfilIds.isEmpty
                ? 'Todos'
                : perfilesAsync.valueOrNull
                          ?.where((p) => params.perfilIds.contains(p.id))
                          .map((p) => p.nombreCompleto)
                          .join(', ') ??
                      '${params.perfilIds.length} operarios',
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pulsa "Descargar" para guardar el PDF en tu dispositivo.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumenTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;

  const _ResumenTile({
    required this.icon,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
