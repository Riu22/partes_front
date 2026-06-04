// =============================================================================
// PANTALLA: EditarParteScreen
// -----------------------------------------------------------------------------
// QUE ES: Formulario para editar un parte de trabajo existente.
// PARA QUE SIRVE: Modificar obra, fecha, horas, descripcion, especialidad y firma.
// QUIEN LA VE (rol): Operarios (solo su parte del dia actual) y gestores/admin.
// COMO SE LLEGA: Pulsando sobre un parte en la lista de partes_screen.
// A DONDE VA DESPUES: Vuelve a '/partes' al guardar o cancelar.
// QUE DATOS NECESITA: El objeto ParteTrabajo a editar.
// OFFLINE: Si, guarda los cambios en cola offline si no hay conexion.
// =============================================================================

/// Pantalla para editar un parte de trabajo existente (operario normal).
/// Permite cambiar obra, fecha, horas, descripcion, especialidad y firma.
/// Si no hay conexion, guarda el cambio en la cola offline.
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
import '../../widgets/seccion_firma.dart';

/// Formulario de edicion para un parte de trabajo.
/// Los gestores pueden editar cualquier campo y cambiar la fecha;
/// los operarios solo pueden editar el parte del dia actual.
class EditarParteScreen extends ConsumerStatefulWidget {
  final ParteTrabajo parte;
  const EditarParteScreen({super.key, required this.parte});

  @override
  ConsumerState<EditarParteScreen> createState() => _EditarParteScreenState();
}

/// Estado del formulario de edicion.
///
/// Lifecycle:
/// 1. initState: inicializa todos los campos con los valores del parte existente.
/// 2. build: renderiza el formulario con los campos editables.
/// 3. dispose: libera los controladores de texto.
class _EditarParteScreenState extends ConsumerState<EditarParteScreen> {
  // GlobalKey para validar el formulario
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _horasCtrl = TextEditingController();

  late DateTime _fecha;
  late int? _idObraSeleccionada;
  late String? _especialidad;
  late String? _idPerfilSeleccionado;
  bool _enviando = false;

  // Estado de firma - lo llena SeccionFirma via callbacks
  String? _firmaBase64;
  String? _nombreFirma;
  String _trabajosExtra = '';

  @override
  void initState() {
    super.initState();
    // Inicializa todos los campos con los valores actuales del parte
    _fecha = widget.parte.fecha;
    _idObraSeleccionada = widget.parte.obraId;
    _especialidad = widget.parte.especialidad;
    _descripcionCtrl.text = widget.parte.descripcion;
    _horasCtrl.text = widget.parte.horasNormales.toString();
    _obraSearchCtrl.text = widget.parte.obraNombre;
    _idPerfilSeleccionado = widget.parte.operarioId;
    _trabajosExtra = widget.parte.trabajosExtra;
    _nombreFirma = widget.parte.nombreFirma;
  }

  @override
  void dispose() {
    _obraSearchCtrl.dispose();
    _descripcionCtrl.dispose();
    _horasCtrl.dispose();
    super.dispose();
  }

  /// Abre el selector de fecha nativa de Flutter.
  /// Solo los gestores pueden cambiar la fecha.
  Future<void> _pickDate() async {
    // showDatePicker: dialogo nativo de seleccion de fecha
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasActivasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    // Determina si el usuario es gestor (admin o gestion)
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
              // -- Banner informativo ------------------------------------------
              // Muestra restricciones segun el rol del usuario
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
                            : 'Solo puedes editar partes del dia de hoy',
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

              // -- Operario (solo gestor) -------------------------------------
              // Los gestores pueden reasignar el parte a otro operario
              if (esGestor) ...[
                _sectionTitle('Operario'),
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
                    onChanged: (v) =>
                        setState(() => _idPerfilSeleccionado = v),
                    validator: (v) =>
                        v == null ? 'Selecciona un operario' : null,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // -- Obra -------------------------------------------------------
              _sectionTitle('Obra'),
              const SizedBox(height: 12),
              obrasAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (obras) => TextFormField(
                  controller: _obraSearchCtrl,
                  readOnly: true, // Solo lectura, se abre modal al pulsar
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
                  validator: (v) =>
                      _idObraSeleccionada == null ? 'Selecciona una obra' : null,
                ),
              ),
              const SizedBox(height: 20),

              // -- Fecha ------------------------------------------------------
              _sectionTitle('Fecha'),
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
                // Solo los gestores pueden pulsar para cambiar la fecha
                onTap: esGestor ? _pickDate : null,
              ),
              const SizedBox(height: 24),

              // -- Horas normales ---------------------------------------------
              _sectionTitle('Horas normales'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _horasCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'horas',
                ),
              ),
              const SizedBox(height: 24),

              // -- Especialidad -----------------------------------------------
              // Solo visible si el parte es postventa o el usuario es gestor
              if (widget.parte.esPostVenta || esGestor) ...[
                _sectionTitle('Especialidad'),
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
                        label: 'Fontaneria',
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

              // -- Descripcion ------------------------------------------------
              _sectionTitle('Tareas realizadas'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Descripcion del trabajo...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 24),

              // -- Firma del cliente + trabajos extra -------------------------
              const Divider(),
              const SizedBox(height: 16),
              // SeccionFirma: widget que maneja la captura de firma digital
              // Recibe callbacks que se ejecutan cuando la firma cambia
              SeccionFirma(
                onFirmaChanged: (base64, nombre) {
                  _firmaBase64 = base64;
                  _nombreFirma = nombre;
                },
                onTrabajosExtraChanged: (v) => _trabajosExtra = v,
              ),
              const SizedBox(height: 32),

              // -- Boton guardar ----------------------------------------------
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

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );

  // -- Dialogo horas ---------------------------------------------------------

  /// Muestra un dialogo informativo sobre el formato correcto de horas.
  void _mostrarDialogoHoras() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Formato de horas incorrecto'),
        content: const Text(
          'Las horas deben escribirse en decimales, 0,5 es media hora.\n\n'
          'Ejemplos validos:\n'
          ' 0.5  (media hora)\n'
          ' 2.5  (dos horas y media)\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // -- Guardar ----------------------------------------------------------------

  /// Guarda los cambios del parte. Si no hay conexion, lo encola en
  /// la cola offline para enviarlo cuando se recupere la red.
  ///
  /// Flujo offline:
  /// 1. Valida el formulario
  /// 2. Construye el payload con los datos actualizados
  /// 3. Verifica conectividad mediante conectividadProvider
  /// 4. Si no hay red, guarda en la cola offline y vuelve a /partes
  /// 5. Si hay red, llama al API y actualiza
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    // Validacion de formato de horas (decimales de 0.5)
    final h = double.tryParse(_horasCtrl.text.replaceAll(',', '.'));
    if (h == null || h % 0.5 != 0) {
      _mostrarDialogoHoras();
      return;
    }

    setState(() => _enviando = true);

    final esGestor = perfil.esAdmin || perfil.esGestion;

    // Construye el payload con solo los campos que cambiaron
    final payload = <String, dynamic>{
      'id_obra': _idObraSeleccionada,
      'id_perfil': esGestor ? _idPerfilSeleccionado : perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales':
          double.tryParse(_horasCtrl.text) ?? widget.parte.horasNormales,
      'descripcion': _descripcionCtrl.text.trim(),
      if (_especialidad != null) 'especialidad': _especialidad,
      if (_trabajosExtra.trim().isNotEmpty)
        'trabajo_extra': _trabajosExtra.trim(),
      if (_nombreFirma != null && _nombreFirma!.isNotEmpty)
        'nombre_firmado': _nombreFirma,
      if (_firmaBase64 != null) 'firma_base64': _firmaBase64,
    };

    final online = ref.read(conectividadProvider).valueOrNull ?? false;

    // Sin conexion: guarda en cola offline
    if (!online) {
      final queue = ref.read(offlineQueueProvider);
      await queue.guardarUpdateOffline(widget.parte.id, payload);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexion - el cambio se guardara al recuperar la red',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/partes');
      }
      setState(() => _enviando = false);
      return;
    }

    // Con conexion: envia al servidor
    try {
      await ref
          .read(apiServiceProvider)
          .updateParte(widget.parte.id, payload);
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte actualizado correctamente')),
        );
        context.go('/partes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}
