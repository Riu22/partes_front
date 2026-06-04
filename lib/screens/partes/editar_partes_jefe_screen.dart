/// Pantalla para editar un parte de jefe de obra existente.
/// Permite modificar la fecha, las obras con sus horas (eléctricas/mecánicas)
/// y la descripción general.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/partes_provider.dart';
import '../../providers/obras_provider.dart';
import '../../widgets/buscador_obras_modal.dart';

/// Formulario de edición para partes de jefe de obra.
/// Carga las obras existentes del parte y permite añadir, quitar
/// o modificar las horas de cada una.
class EditarParteJefeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> parte;

  const EditarParteJefeScreen({super.key, required this.parte});

  @override
  ConsumerState<EditarParteJefeScreen> createState() =>
      _EditarParteJefeScreenState();
}

class _EditarParteJefeScreenState extends ConsumerState<EditarParteJefeScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _descripcion;
  bool _enviando = false;
  late DateTime _fecha;
  late List<Map<String, dynamic>> _lineas;

  @override
  void initState() {
    super.initState();
    final p = widget.parte;
    _descripcion = p['descripcion'] ?? '';
    _fecha = DateTime.tryParse(p['fecha'] ?? '') ?? DateTime.now();

    // Carga las obras existentes del parte
    final obras = (p['obras'] as List?) ?? [];
    _lineas = obras.map<Map<String, dynamic>>((o) {
      final totalHoras =
          ((o['porcentaje_electrico'] as num?)?.toDouble() ?? 0.0) +
          ((o['porcentaje_mecanico'] as num?)?.toDouble() ?? 0.0);
      return {
        'obra_id': o['obra']?['id'],
        'obra_nombre': o['obra']?['nombre'] ?? '',
        'horas_electricas':
            (o['porcentaje_electrico'] as num?)?.toDouble() ?? 0.0,
        'horas_mecanicas':
            (o['porcentaje_mecanico'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  }

  double get _totalHoras => _lineas.fold(
    0.0,
    (sum, l) =>
        sum +
        ((l['horas_electricas'] as double?) ?? 0.0) +
        ((l['horas_mecanicas'] as double?) ?? 0.0),
  );

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 1),
      lastDate: ahora,
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  /// Envía los cambios del parte de jefe al servidor con las obras
  /// actualizadas y sus horas desglosadas.
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final fmt = DateFormat('yyyy-MM-dd');
    final data = <String, dynamic>{
      'descripcion': _descripcion,
      'fecha': fmt.format(_fecha),
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
      final parteId = widget.parte['id'] as int;
      await ref.read(apiServiceProvider).updateParteJefe(parteId, data);
      ref.invalidate(partesJefeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte actualizado correctamente')),
        );
        context.go('/partes');
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.response?.data?.toString() ?? 'Error de conexión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Parte Jefe'),
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
              // ── Fecha ────────────────────────────────────────────
              const Text(
                'Fecha del parte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _seleccionarFecha,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.teal.withOpacity(0.04),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fmt.format(_fecha),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
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
                      'Total: ${_totalHoras.toStringAsFixed(1)} h',
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
                initialValue: _descripcion,
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                onChanged: (v) => _descripcion = v,
              ),

              const SizedBox(height: 30),

              // ── Botón guardar ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _enviando ? null : _guardar,
                  child: _enviando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'GUARDAR CAMBIOS',
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
}
