import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';

class CrearParteScreen extends ConsumerWidget {
  const CrearParteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    if (perfil == null) return const SizedBox();

    if (perfil.esJefeObra) {
      return const _FormularioParteJefe();
    }
    return const _FormularioParteNormal();
  }
}

// ─────────────────────────────────────────
// Formulario OPERARIO / ENCARGADO
// ─────────────────────────────────────────
class _FormularioParteNormal extends ConsumerStatefulWidget {
  const _FormularioParteNormal();

  @override
  ConsumerState<_FormularioParteNormal> createState() =>
      _FormularioParteNormalState();
}

class _FormularioParteNormalState
    extends ConsumerState<_FormularioParteNormal> {
  final _formKey = GlobalKey<FormState>();
  DateTime _fecha = DateTime.now();
  double _horasNormales = 8.0;
  String _descripcion = '';
  int? _idObraSeleccionada;
  String? _especialidad;
  bool _enviando = false;

  final DateTime _fechaMinima = DateTime.now().subtract(
    const Duration(days: 14),
  );

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Obra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              obrasAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (obras) => DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Obra',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.foundation),
                  ),
                  items: obras
                      .map(
                        (o) => DropdownMenuItem<int>(
                          value: o.id,
                          child: Text(o.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _idObraSeleccionada = v),
                  validator: (v) => v == null ? 'Selecciona la obra' : null,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}',
                ),
                subtitle: Text(
                  'Mínimo: ${DateFormat('dd/MM/yyyy').format(_fechaMinima)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 25),
              const Text(
                'Horas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '8',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Horas normales',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _horasNormales = double.tryParse(v) ?? 8.0,
              ),
              const SizedBox(height: 25),
              const Text(
                'Especialidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BotonEspecialidad(
                      label: 'Electricidad',
                      icono: Icons.electrical_services,
                      color: Colors.amber[700]!,
                      seleccionado: _especialidad == 'ELECTRICIDAD',
                      onTap: () =>
                          setState(() => _especialidad = 'ELECTRICIDAD'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BotonEspecialidad(
                      label: 'Fontanería',
                      icono: Icons.plumbing,
                      color: Colors.blue[700]!,
                      seleccionado: _especialidad == 'FONTANERIA',
                      onTap: () => setState(() => _especialidad = 'FONTANERIA'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                'Tareas realizadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe qué has hecho hoy...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v!.isEmpty ? 'Describe las tareas realizadas' : null,
                onChanged: (v) => _descripcion = v,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _enviando ? null : _enviarParte,
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

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _fechaMinima,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _enviando = true);
    try {
      await ref.read(apiServiceProvider).crearParte({
        'id_obra': _idObraSeleccionada,
        'id_perfil': perfil.id,
        'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
        'horas_normales': _horasNormales,
        'especialidad': _especialidad,
        'descripcion': _descripcion,
      });
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        context.go('/partes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

// ─────────────────────────────────────────
// Formulario JEFE DE OBRA
// ─────────────────────────────────────────
class _FormularioParteJefe extends ConsumerStatefulWidget {
  const _FormularioParteJefe();

  @override
  ConsumerState<_FormularioParteJefe> createState() =>
      _FormularioParteJefeState();
}

class _FormularioParteJefeState extends ConsumerState<_FormularioParteJefe> {
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
        title: const Text('Nuevo Parte — Jefe de Obra'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.teal),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha del parte',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Text(
                          'Se asigna automáticamente',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Obras y porcentajes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: totalValido ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Total: ${total.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'La suma de porcentajes debe ser exactamente 100%',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              // LISTA DE OBRAS
              ..._lineas.asMap().entries.map((entry) {
                final i = entry.key;
                final linea = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.business, color: Colors.teal),
                    title: Text(linea['obra_nombre'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 70,
                          child: TextFormField(
                            initialValue:
                                linea['porcentaje']?.toString() ?? '0',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              suffixText: '%',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            onChanged: (v) => setState(() {
                              _lineas[i]['porcentaje'] =
                                  double.tryParse(v) ?? 0.0;
                            }),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed: () => setState(() => _lineas.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
                    onPressed: () => _mostrarSelectorObra(context, disponibles),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir obra'),
                  );
                },
              ),
              const SizedBox(height: 25),
              const Text(
                'Descripción',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe las tareas realizadas hoy...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Describe las tareas' : null,
                onChanged: (v) => _descripcion = v,
              ),
              const SizedBox(height: 30),
              if (!totalValido && _lineas.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Los porcentajes suman ${total.toStringAsFixed(1)}%. '
                          'Deben sumar exactamente 100%.',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
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

  void _mostrarSelectorObra(BuildContext context, List obras) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar obra'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: obras.length,
            itemBuilder: (context, index) {
              final o = obras[index];
              return ListTile(
                leading: const Icon(Icons.business),
                title: Text(o.nombre),
                subtitle: Text(o.municipio),
                onTap: () {
                  setState(() {
                    _lineas.add({
                      'obra_id': o.id,
                      'obra_nombre': o.nombre,
                      'porcentaje': 0.0,
                    });
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await ref.read(apiServiceProvider).crearParteJefe({
        'descripcion': _descripcion,
        'obras': _lineas
            .map(
              (l) => {'id_obra': l['obra_id'], 'porcentaje': l['porcentaje']},
            )
            .toList(),
      });
      ref.invalidate(partesJefeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        context.go('/partes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

class _BotonEspecialidad extends StatelessWidget {
  final String label;
  final IconData icono;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BotonEspecialidad({
    required this.label,
    required this.icono,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: seleccionado ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icono, color: seleccionado ? Colors.white : color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.white : color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
