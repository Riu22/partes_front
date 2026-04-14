import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/parte_trabajo.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';

class EditarParteScreen extends ConsumerStatefulWidget {
  final ParteTrabajo parte;
  const EditarParteScreen({super.key, required this.parte});

  @override
  ConsumerState<EditarParteScreen> createState() => _EditarParteScreenState();
}

class _EditarParteScreenState extends ConsumerState<EditarParteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _horasCtrl = TextEditingController();

  late DateTime _fecha;
  late int? _idObraSeleccionada;
  late String? _especialidad;
  bool _enviando = false;

  final DateTime _fechaMinima = DateTime.now().subtract(
    const Duration(days: 14),
  );

  @override
  void initState() {
    super.initState();
    _fecha = widget.parte.fecha;
    _idObraSeleccionada = widget.parte.obraId;
    _especialidad = widget.parte.especialidad;
    _descripcionCtrl.text = widget.parte.descripcion;
    _horasCtrl.text = widget.parte.horasNormales.toString();
    _obraSearchCtrl.text = widget.parte.obraNombre;
  }

  @override
  void dispose() {
    _obraSearchCtrl.dispose();
    _descripcionCtrl.dispose();
    _horasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esPostventa = perfil?.postventa ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar parte'),
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
              // Info del parte
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Puedes editar este parte hasta el ${DateFormat('dd/MM/yyyy').format(widget.parte.fecha.add(const Duration(days: 14)))}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Obra
              const Text(
                'Obra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              obrasAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (obras) => TextFormField(
                  controller: _obraSearchCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar obra',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onTap: () => _abrirBuscadorObras(context, obras),
                  validator: (v) => _idObraSeleccionada == null
                      ? 'Selecciona una obra'
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Fecha
              const Text(
                'Fecha',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 24),

              // Horas
              const Text(
                'Horas normales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _horasCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'horas',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obligatorio';
                  if (double.tryParse(v) == null)
                    return 'Introduce un número válido';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Especialidad — solo si es postventa
              if (esPostventa) ...[
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
                        onTap: () =>
                            setState(() => _especialidad = 'FONTANERIA'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Descripción
              const Text(
                'Tareas realizadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Descripción del trabajo...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
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

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _fechaMinima,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  void _abrirBuscadorObras(BuildContext context, List obras) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _BuscadorObras(
            obras: obras,
            scrollController: scrollController,
            onSeleccionar: (o) {
              setState(() {
                _idObraSeleccionada = o.id;
                _obraSearchCtrl.text = o.nombre;
              });
            },
          ),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _enviando = true);

    final payload = {
      'id_obra': _idObraSeleccionada,
      'id_perfil': perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales':
          double.tryParse(_horasCtrl.text) ?? widget.parte.horasNormales,
      'descripcion': _descripcionCtrl.text.trim(),
      if (_especialidad != null) 'especialidad': _especialidad,
    };

    // Comprobamos si hay conexión en este momento
    final online = ref.read(conectividadProvider).valueOrNull ?? false;

    if (!online) {
      // Sin red: encolamos el update para sincronizar después
      final queue = ref.read(offlineQueueProvider);
      await queue.guardarUpdateOffline(widget.parte.id, payload);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión — el cambio se guardará al recuperar la red'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/partes');
      }
      setState(() => _enviando = false);
      return;
    }

    try {
      await ref.read(apiServiceProvider).updateParte(widget.parte.id, payload);
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte actualizado correctamente')),
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
// Buscador de obras
// ─────────────────────────────────────────
class _BuscadorObras extends StatefulWidget {
  final List obras;
  final ScrollController scrollController;
  final Function(dynamic) onSeleccionar;

  const _BuscadorObras({
    required this.obras,
    required this.scrollController,
    required this.onSeleccionar,
  });

  @override
  State<_BuscadorObras> createState() => _BuscadorObrasState();
}

class _BuscadorObrasState extends State<_BuscadorObras> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final filtradas = widget.obras
        .where(
          (o) =>
              o.nombre.toLowerCase().contains(_filtro.toLowerCase()) ||
              o.municipio.toLowerCase().contains(_filtro.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 50,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Nombre de obra o municipio...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (v) => setState(() => _filtro = v),
          ),
        ),
        Expanded(
          child: filtradas.isEmpty
              ? const Center(child: Text('No se encontraron obras'))
              : ListView.separated(
                  controller: widget.scrollController,
                  itemCount: filtradas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final o = filtradas[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.business, color: Colors.white),
                      ),
                      title: Text(
                        o.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(o.municipio),
                      onTap: () {
                        widget.onSeleccionar(o);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Botón especialidad
// ─────────────────────────────────────────
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: seleccionado ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icono, color: seleccionado ? Colors.white : color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
