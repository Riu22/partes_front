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
    final totalHoras = _datos.fold<double>(
      0,
      (sum, d) => sum + ((d['total_horas'] as num?)?.toDouble() ?? 0),
    );

    return Scaffold(
      body: Column(
        children: [
          // Selector de fechas
          Padding(
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
                        onPressed:
                            (_desde == null || _hasta == null || _cargando)
                            ? null
                            : _buscar,
                        icon: _cargando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: const Text('Calcular quincena'),
                      ),
                    ),
                    if (hayDatos) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _exportando ? null : _exportar,
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
                        label: const Text('Exportar CSV'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // Resumen total
          if (hayDatos)
            Container(
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
                  Text(
                    '${_datos.length} trabajadores',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: ${totalHoras.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Tabla de datos
          if (hayDatos)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _datos.length,
                itemBuilder: (context, index) {
                  final d = _datos[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Text(
                          (d['nombre'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        d['nombre'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (d['codigo'] != null)
                            Text(
                              'Código: ${d['codigo']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            d['obra'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      isThreeLine: d['codigo'] != null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${(d['total_horas'] as num?)?.toStringAsFixed(1) ?? '0'}h',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (!hayDatos && !_cargando)
            const Expanded(
              child: Center(
                child: Text(
                  'Selecciona un rango de fechas\ny pulsa Calcular',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
                  fecha != null ? formato.format(fecha!) : 'Seleccionar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: fecha != null ? Colors.black : Colors.grey,
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
