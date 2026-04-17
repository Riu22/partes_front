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
  DateTimeRange? _rangoSeleccionado; // ← sustituye _desde y _hasta
  List<dynamic> _datos = [];
  bool _cargando = false;
  bool _exportando = false;
  String? _error;

  final _fmt = DateFormat('dd/MM/yy');
  final _fmtApi = DateFormat('yyyy-MM-dd');

  Map<String, List<dynamic>> _agruparPorObra() {
    final Map<String, List<dynamic>> grupos = {};
    for (var d in _datos) {
      final obra = d['obra'] ?? 'Sin Obra';
      grupos.putIfAbsent(obra, () => []).add(d);
    }
    return grupos;
  }

  Future<void> _seleccionarFechas(BuildContext context) async {
    final DateTimeRange? nuevoRango = await showDateRangePicker(
      context: context,
      initialDateRange:
          _rangoSeleccionado ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 14)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'SELECCIONE EL PERIODO',
    );

    if (nuevoRango != null) {
      setState(() {
        _rangoSeleccionado = nuevoRango;
        _datos = [];
        _error = null;
      });
      _buscar();
    }
  }

  Future<void> _buscar() async {
    if (_rangoSeleccionado == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await ref
          .read(apiServiceProvider)
          .getQuincena(
            _fmtApi.format(_rangoSeleccionado!.start),
            _fmtApi.format(_rangoSeleccionado!.end),
          );
      setState(() => _datos = datos);
    } catch (e) {
      setState(() => _error = 'Error al cargar: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _exportar() async {
    if (_rangoSeleccionado == null) return;
    setState(() => _exportando = true);
    try {
      await ref
          .read(apiServiceProvider)
          .exportarQuincena(
            _fmtApi.format(_rangoSeleccionado!.start),
            _fmtApi.format(_rangoSeleccionado!.end),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _exportando = false);
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
          _buildSelectorHeader(),
          if (_error != null) _buildError(),
          if (hayDatos) _buildResumenTotal(totalHorasGeneral),
          const SizedBox(height: 8),
          if (hayDatos)
            Expanded(child: _buildListaObras())
          else if (!_cargando)
            _buildEmptyState(),
          if (_cargando)
            const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildSelectorHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _seleccionarFechas(context),
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _rangoSeleccionado == null
                    ? 'Seleccionar Rango'
                    : '${_fmt.format(_rangoSeleccionado!.start)} - ${_fmt.format(_rangoSeleccionado!.end)}',
              ),
            ),
          ),
          if (_datos.isNotEmpty) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _exportando ? null : _exportar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              icon: _exportando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              label: const Text('CSV'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenTotal(double total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

  Widget _buildListaObras() {
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
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
            children: operarios
                .map(
                  (t) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline, size: 20),
                    title: Text(t['nombre'] ?? ''),
                    subtitle: Text('Cód. Operario: ${t['codigo'] ?? 'N/A'}'),
                    trailing: Text(
                      '${(t['total_horas'] as num).toStringAsFixed(1)}h',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

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
