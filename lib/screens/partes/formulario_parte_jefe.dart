import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';
import '../../providers/partes_provider.dart';
import '../../widgets/buscador_obras_modal.dart';

class FormularioParteJefe extends ConsumerStatefulWidget {
  const FormularioParteJefe({super.key});

  @override
  ConsumerState<FormularioParteJefe> createState() =>
      _FormularioParteJefeState();
}

class _FormularioParteJefeState extends ConsumerState<FormularioParteJefe> {
  final _formKey = GlobalKey<FormState>();
  String _descripcion = '';
  bool _enviando = false;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  // Cada línea: { obra_id, obra_nombre, horas_electricas, horas_mecanicas }
  final List<Map<String, dynamic>> _lineas = [];

  // ── Horas totales introducidas por el usuario ──────────────────────
  double get _totalHorasIntroducidas => _lineas.fold(
    0.0,
    (sum, l) =>
        sum +
        ((l['horas_electricas'] as double?) ?? 0.0) +
        ((l['horas_mecanicas'] as double?) ?? 0.0),
  );

  bool get _fechasValidas =>
      _fechaInicio != null &&
      _fechaFin != null &&
      !_fechaFin!.isBefore(_fechaInicio!);

  bool get _formularioListo =>
      _fechasValidas && _lineas.isNotEmpty && !_enviando;

  // ── Selector de fecha ──────────────────────────────────────────────
  Future<void> _seleccionarFecha({required bool esInicio}) async {
    final ahora = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio ? (_fechaInicio ?? ahora) : (_fechaFin ?? ahora),
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 1),
      locale: const Locale('es'),
    );
    if (picked == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = picked;
        // Si la fecha fin es anterior a la nueva inicio, la reseteamos
        if (_fechaFin != null && _fechaFin!.isBefore(picked)) {
          _fechaFin = null;
        }
      } else {
        _fechaFin = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parte Jefe de Obra'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/partes'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Rango de fechas ──────────────────────────────────
              const Text(
                'Período del parte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSelectorFecha(
                      label: 'Fecha inicio',
                      valor: _fechaInicio != null
                          ? fmt.format(_fechaInicio!)
                          : 'Seleccionar',
                      onTap: () => _seleccionarFecha(esInicio: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSelectorFecha(
                      label: 'Fecha fin',
                      valor: _fechaFin != null
                          ? fmt.format(_fechaFin!)
                          : 'Seleccionar',
                      onTap: () => _seleccionarFecha(esInicio: false),
                    ),
                  ),
                ],
              ),
              if (!_fechasValidas &&
                  (_fechaInicio != null || _fechaFin != null))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ La fecha fin debe ser igual o posterior a la fecha inicio',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 25),

              // ── Obras ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Obras',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_lineas.isNotEmpty)
                    Text(
                      'Total: ${_totalHorasIntroducidas.toStringAsFixed(1)} h',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              ..._lineas.asMap().entries.map(
                (e) => _buildCardLinea(e.key, e.value),
              ),

              obrasAsync.when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (obras) {
                  final obraIds = _lineas.map((l) => l['obra_id']).toSet();
                  final disponibles = obras
                      .where((o) => !obraIds.contains(o.id))
                      .toList();
                  if (disponibles.isEmpty) return const SizedBox();
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                    ),
                    onPressed: () =>
                        abrirBuscadorObras(context, disponibles, (o) {
                          setState(
                            () => _lineas.add({
                              'obra_id': o.id,
                              'obra_nombre': o.nombre,
                              'horas_electricas': 0.0,
                              'horas_mecanicas': 0.0,
                            }),
                          );
                        }),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar y añadir obra'),
                  );
                },
              ),

              const SizedBox(height: 25),

              // ── Descripción ──────────────────────────────────────
              const Text(
                'Descripción general',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                onChanged: (v) => _descripcion = v,
              ),

              const SizedBox(height: 30),

              // ── Botón enviar ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _formularioListo ? _enviarParte : null,
                  child: _enviando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ENVIAR PARTE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets auxiliares ─────────────────────────────────────────────

  Widget _buildSelectorFecha({
    required String label,
    required String valor,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.teal.withOpacity(0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              Text(
                valor,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildCardLinea(int i, Map<String, dynamic> linea) {
    final electricas = (linea['horas_electricas'] as double?) ?? 0.0;
    final mecanicas = (linea['horas_mecanicas'] as double?) ?? 0.0;
    final totalLinea = electricas + mecanicas;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera obra + eliminar
            Row(
              children: [
                Expanded(
                  child: Text(
                    linea['obra_nombre'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _lineas.removeAt(i)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Inputs horas
            Row(
              children: [
                Expanded(
                  child: _buildInputHoras(
                    label: '⚡ Eléctricas (h)',
                    valor: electricas,
                    onChanged: (v) =>
                        setState(() => _lineas[i]['horas_electricas'] = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputHoras(
                    label: '🔧 Mecánicas (h)',
                    valor: mecanicas,
                    onChanged: (v) =>
                        setState(() => _lineas[i]['horas_mecanicas'] = v),
                  ),
                ),
              ],
            ),
            if (totalLinea > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Subtotal: ${totalLinea.toStringAsFixed(1)} h',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputHoras({
    required String label,
    required double valor,
    required ValueChanged<double> onChanged,
  }) => TextFormField(
    initialValue: valor == 0 ? '' : valor.toStringAsFixed(1),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    onChanged: (v) => onChanged(double.tryParse(v) ?? 0.0),
  );

  // ── Envío ──────────────────────────────────────────────────────────

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_fechasValidas) return;
    setState(() => _enviando = true);

    final fmt = DateFormat('yyyy-MM-dd');
    final data = <String, dynamic>{
      'descripcion': _descripcion,
      'fecha_inicio': fmt.format(_fechaInicio!),
      'fecha_fin': fmt.format(_fechaFin!),
      'obras': _lineas
          .map(
            (l) => {
              'id_obra': l['obra_id'],
              'horas_electricas': l['horas_electricas'] ?? 0.0,
              'horas_mecanicas': l['horas_mecanicas'] ?? 0.0,
            },
          )
          .toList(),
    };

    try {
      final resultado = await Connectivity().checkConnectivity();
      final hayRed = resultado.any((r) => r != ConnectivityResult.none);

      if (!hayRed) {
        await ref.read(offlineQueueProvider).guardarParteJefeOffline(data);
        ref.invalidate(pendientesOfflineProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sin conexión — parte guardado, se enviará automáticamente',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          context.go('/partes');
        }
        return;
      }

      await ref.read(apiServiceProvider).crearParteJefe(data);
      ref.invalidate(partesJefeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        context.go('/partes');
      }
    } on DioException catch (_) {
      await ref.read(offlineQueueProvider).guardarParteJefeOffline(data);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión — parte guardado localmente'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/partes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}
