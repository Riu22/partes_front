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
  final List<Map<String, dynamic>> _lineas = [];

  double get _totalPorcentaje => _lineas.fold(
    0.0,
    (sum, l) => sum + ((l['porcentaje'] as double?) ?? 0.0),
  );

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final double total = _totalPorcentaje;
    final bool totalValido = (total - 100.0).abs() < 0.01;

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
              _buildInfoFecha(),
              const SizedBox(height: 25),
              _buildHeaderPorcentajes(total, totalValido),
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
                              'porcentaje': 0.0,
                            }),
                          );
                        }),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar y añadir obra'),
                  );
                },
              ),
              const SizedBox(height: 25),
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
              if (!totalValido && _lineas.isNotEmpty)
                _buildWarningPorcentaje(total),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_enviando || !totalValido || _lineas.isEmpty)
                      ? null
                      : _enviarParte,
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

  Widget _buildInfoFecha() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.teal.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.teal.withOpacity(0.2)),
    ),
    child: Text(
      'Fecha del parte: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
    ),
  );

  Widget _buildHeaderPorcentajes(double total, bool totalValido) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'Distribución',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(
        'Total: ${total.toStringAsFixed(0)}%',
        style: TextStyle(
          color: totalValido ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    ],
  );

  Widget _buildCardLinea(int i, Map<String, dynamic> linea) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      title: Text(
        linea['obra_nombre'] ?? '',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            child: TextFormField(
              initialValue: '0',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(suffixText: '%'),
              onChanged: (v) => setState(
                () => _lineas[i]['porcentaje'] = double.tryParse(v) ?? 0.0,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => setState(() => _lineas.removeAt(i)),
          ),
        ],
      ),
    ),
  );

  Widget _buildWarningPorcentaje(double total) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      '⚠️ La suma debe ser 100% (actual: ${total.toStringAsFixed(0)}%)',
      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
    ),
  );

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final data = <String, dynamic>{
      'descripcion': _descripcion,
      'obras': _lineas
          .map((l) => {'id_obra': l['obra_id'], 'porcentaje': l['porcentaje']})
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
