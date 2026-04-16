import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

class QuincenaScreen extends ConsumerStatefulWidget {
  const QuincenaScreen({super.key});

  @override
  ConsumerState<QuincenaScreen> createState() => _QuincenaScreenState();
}

class _QuincenaScreenState extends ConsumerState<QuincenaScreen> {
  DateTime? _desde;
  DateTime? _hasta;
  List<dynamic> _datos = [];
  bool _cargando = false;
  bool _exportando = false;
  String? _error;

  final _fmt = DateFormat('dd/MM/yyyy');
  final _fmtApi = DateFormat('yyyy-MM-dd');

  // Lógica para agrupar los datos que vienen de la API por el nombre de la obra
  Map<String, List<dynamic>> _agruparPorObra() {
    final Map<String, List<dynamic>> grupos = {};
    for (var d in _datos) {
      final obra = d['obra'] ?? 'Sin Obra';
      if (!grupos.containsKey(obra)) {
        grupos[obra] = [];
      }
      grupos[obra]!.add(d);
    }
    return grupos;
  }

  Future<void> _buscar() async {
    if (_desde == null || _hasta == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await ref
          .read(apiServiceProvider)
          .getQuincena(_fmtApi.format(_desde!), _fmtApi.format(_hasta!));
      setState(() => _datos = datos);
    } catch (e) {
      setState(() => _error = 'Error al cargar: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _exportar() async {
    if (_desde == null || _hasta == null) return;
    setState(() => _exportando = true);
    try {
      await ref
          .read(apiServiceProvider)
          .exportarQuincena(_fmtApi.format(_desde!), _fmtApi.format(_hasta!));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      setState(() => _exportando = false);
    }
  }

  Future<void> _pickFecha(bool esDesde) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (esDesde)
          _desde = picked;
        else
          _hasta = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayDatos = _datos.isNotEmpty;
    final totalHorasGeneral = _datos.fold<double>(
      0,
      (sum, d) => sum + ((d['total_horas'] as num?)?.toDouble() ?? 0),
    );

    return Scaffold(
      body: Column(
        children: [
          _buildSelectorFechas(),
          if (_error != null) _buildError(),

          // Resumen General
          if (hayDatos) _buildResumenTotal(totalHorasGeneral),

          const SizedBox(height: 8),

          // Listado Agrupado por Obra
          if (hayDatos)
            Expanded(
              child: Builder(
                builder: (context) {
                  final grupos = _agruparPorObra();
                  final nombresObras = grupos.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: nombresObras.length,
                    itemBuilder: (context, index) {
                      final nombreObra = nombresObras[index];
                      final operarios = grupos[nombreObra]!;
                      final totalObra = operarios.fold<double>(
                        0,
                        (s, t) => s + (t['total_horas'] as num).toDouble(),
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          backgroundColor: Colors.white,
                          title: Text(
                            nombreObra,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${operarios.length} trabajadores en esta obra',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${totalObra.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'TOTAL OBRA',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          children: operarios
                              .map(
                                (t) => ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.person_outline,
                                    size: 20,
                                  ),
                                  title: Text(t['nombre'] ?? ''),
                                  subtitle: Text(
                                    'Cód. Operario: ${t['codigo'] ?? 'N/A'}',
                                  ),
                                  trailing: Text(
                                    '${(t['total_horas'] as num).toStringAsFixed(1)}h',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

          if (!hayDatos && !_cargando) _buildEmptyState(),
        ],
      ),
    );
  }

  // --- Widgets de apoyo para limpiar el build ---

  Widget _buildSelectorFechas() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SelectorFecha(
                  label: 'Desde',
                  fecha: _desde,
                  formato: _fmt,
                  onTap: () => _pickFecha(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SelectorFecha(
                  label: 'Hasta',
                  fecha: _hasta,
                  formato: _fmt,
                  onTap: () => _pickFecha(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_desde == null || _hasta == null || _cargando)
                      ? null
                      : _buscar,
                  icon: _cargando ? _miniLoader() : const Icon(Icons.search),
                  label: const Text('Calcular quincena'),
                ),
              ),
              if (_datos.isNotEmpty) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _exportando ? null : _exportar,
                  icon: _exportando
                      ? _miniLoader()
                      : const Icon(Icons.download),
                  label: const Text('CSV'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTotal(double total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TOTAL GENERAL QUINCENA',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${total.toStringAsFixed(1)}h',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniLoader() => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(_error!, style: const TextStyle(color: Colors.red)),
  );

  Widget _buildEmptyState() => const Expanded(
    child: Center(
      child: Text(
        'Selecciona fechas para ver el desglose por obras',
        style: TextStyle(color: Colors.grey),
      ),
    ),
  );
}

// Widget auxiliar para los selectores de fecha
class _SelectorFecha extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final DateFormat formato;
  final VoidCallback onTap;

  const _SelectorFecha({
    required this.label,
    required this.fecha,
    required this.formato,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  fecha != null ? formato.format(fecha!) : 'Elegir',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
