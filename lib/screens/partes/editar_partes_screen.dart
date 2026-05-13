import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/parte_trabajo.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';
import '../../providers/perfiles_provider.dart';
import '../../widgets/buscador_obras_modal.dart';
import '../../widgets/boton_especialidad.dart';

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
  late String? _idPerfilSeleccionado;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _fecha = widget.parte.fecha;
    _idObraSeleccionada = widget.parte.obraId;
    _especialidad = widget.parte.especialidad;
    _descripcionCtrl.text = widget.parte.descripcion;
    _horasCtrl.text = widget.parte.horasNormales.toString();
    _obraSearchCtrl.text = widget.parte.obraNombre;
    _idPerfilSeleccionado = widget.parte.operarioId;
  }

  @override
  void dispose() {
    _obraSearchCtrl.dispose();
    _descripcionCtrl.dispose();
    _horasCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasActivasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;

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
              // Banner info
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
                        esGestor
                            ? 'Como gestor puedes editar este parte sin restricciones de fecha'
                            : 'Solo puedes editar partes del día de hoy',
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

              // Selector de operario (solo admin/gestión)
              if (esGestor) ...[
                const Text(
                  'Operario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                perfilesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error cargando perfiles: $e'),
                  data: (perfiles) => DropdownButtonFormField<String>(
                    value: _idPerfilSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar operario',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: perfiles
                        .where((p) => p.activo)
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.nombreCompleto),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _idPerfilSeleccionado = v),
                    validator: (v) =>
                        v == null ? 'Selecciona un operario' : null,
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
                   onTap: () => abrirBuscadorObras(context, obras, (o) {
                    setState(() {
                      _idObraSeleccionada = o.id;
                      _obraSearchCtrl.text = o.nombre;
                    });
                  }),
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
                  side: BorderSide(
                    color: esGestor ? Colors.orange.shade300 : Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: Icon(
                  Icons.calendar_today,
                  color: esGestor ? Colors.orange : Colors.grey,
                ),
                title: Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}',
                  style: TextStyle(
                    color: esGestor ? Colors.black87 : Colors.grey,
                  ),
                ),
                subtitle: esGestor
                    ? const Text(
                        'Toca para cambiar la fecha',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      )
                    : null,
                onTap: esGestor ? _pickDate : null,
              ),
              const SizedBox(height: 24),

              // ── Horas ──
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

              // ── Especialidad ──
              if (widget.parte.esPostVenta || esGestor) ...[
                const Text(
                  'Especialidad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BotonEspecialidad(
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
                      child: BotonEspecialidad(
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

              // ── Descripción ──
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



  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _enviando = true);

    final esGestor = perfil.esAdmin || perfil.esGestion;

    final payload = {
      'id_obra': _idObraSeleccionada,
      'id_perfil': esGestor ? _idPerfilSeleccionado : perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales':
          double.tryParse(_horasCtrl.text) ?? widget.parte.horasNormales,
      'descripcion': _descripcionCtrl.text.trim(),
      if (_especialidad != null) 'especialidad': _especialidad,
    };

    final online = ref.read(conectividadProvider).valueOrNull ?? false;

    if (!online) {
      final queue = ref.read(offlineQueueProvider);
      await queue.guardarUpdateOffline(widget.parte.id, payload);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexión — el cambio se guardará al recuperar la red',
            ),
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


