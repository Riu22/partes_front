// =============================================================================
// formulario_parte_postventa.dart
// =============================================================================
// QUE ES:       Formulario para crear un parte de trabajo de postventa.
// PARA QUE:     Registrar partes con especialidad obligatoria (electricidad
//               o fontaneria) para operarios de postventa.
// QUIEN LO USA: Operarios de postventa y gestores que crean partes para ellos.
// COMO SE LLEGA: Desde partes_screen.dart al pulsar FAB y elegir "postventa",
//                o desde admin_home_screen.dart con operario postventa.
// A DONDE VA:   POST /api/partes (con campo es_post_venta=true) o cola offline.
// QUE DATOS USA: auth_provider, perfiles_provider, obras_provider,
//                apiServiceProvider, offlineQueueProvider, connectivity_plus.
// OFFLINE:      Si no hay red, guarda en offlineQueueProvider para envio posterior.
// =============================================================================

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
import '../../providers/perfiles_provider.dart';
import '../../models/perfil.dart';
import '../../helpers/perfil_helpers.dart';
import '../../widgets/buscador_obras_modal.dart';
import '../../widgets/buscador_operarios_modal.dart';
import '../../widgets/seccion_firma.dart';
import '../../widgets/boton_especialidad.dart';

/// Formulario para registrar un parte de postventa.
/// Los operarios de postventa eligen especialidad (electricidad/fontaneria).
/// Los gestores pueden crear partes para cualquier operario postventa.
class FormularioPostVenta extends ConsumerStatefulWidget {
  const FormularioPostVenta({
    super.key,
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  // -- Parametros opcionales para preseleccion --
  final String? perfilIdPreseleccionado;
  final String? nombrePreseleccionado;
  final DateTime? fechaPreseleccionada;

  @override
  ConsumerState<FormularioPostVenta> createState() =>
      _FormularioPostVentaState();
}

/// Estado mutable del formulario de parte postventa.
/// Similar a formulario_parte_normal pero con especialidad obligatoria
/// para el operario y logica de postventa integrada.
class _FormularioPostVentaState extends ConsumerState<FormularioPostVenta> {
  // -- Claves y controladores --
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();

  // -- Estado del formulario --
  late DateTime _fecha;
  double _horasNormales = 0;
  String _descripcion = '';
  String _trabajosExtra = '';
  int? _idObraSeleccionada;
  String? _especialidad; // Especialidad que elige el operario postventa
  String? _idPerfilSeleccionado;
  Perfil? _perfilOperarioSeleccionado;
  bool _enviando = false;
  String? _firmaBase64;
  String? _nombreFirma;

  // -- Perfiles y fechas --
  List<Perfil> _perfilesOrdenados = [];
  bool _cargandoFechas = false;
  List<DateTime> _fechasPermitidas = [];

  /// Navega a la pantalla de inicio segun el rol.
  void _volverAHome() {
    final perfil = ref.read(authProvider).valueOrNull;
    final esAdminOGestion =
        perfil != null && (perfil.esAdmin || perfil.esGestion);
    context.go(esAdminOGestion ? '/admin' : '/partes');
  }

  @override
  void initState() {
    super.initState();
    _fecha = widget.fechaPreseleccionada ?? DateTime.now();
    if (widget.perfilIdPreseleccionado != null) {
      _idPerfilSeleccionado = widget.perfilIdPreseleccionado;
      _cargarFechasDeOperario(widget.perfilIdPreseleccionado!);
    } else {
      _cargarMisFechas();
    }
    _cargarFechasPermitidas();
    // Escucha cambios en perfiles para mostrar buscador de operarios
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(perfilesProvider, (_, next) {
        next.whenData((perfiles) {
          if (mounted) {
            final ordenados = ordenarPerfiles(perfiles);
            setState(() {
              _perfilesOrdenados = ordenados;
              if (widget.perfilIdPreseleccionado != null &&
                  _perfilOperarioSeleccionado == null) {
                _perfilOperarioSeleccionado = ordenados
                    .where((p) => p.id == widget.perfilIdPreseleccionado)
                    .firstOrNull;
              }
            });
          }
        });
      }, fireImmediately: true);
    });
  }

  /// Carga fechas del usuario actual.
  Future<void> _cargarMisFechas() async {
    setState(() => _cargandoFechas = true);
    try {
      await ref.read(apiServiceProvider).getMisFechasConParte();
    } catch (e) {
      debugPrint('>>> error cargarMisFechas: $e');
    } finally {
      if (mounted) setState(() => _cargandoFechas = false);
    }
  }

  /// Carga fechas de un operario especifico.
  Future<void> _cargarFechasDeOperario(String id) async {
    setState(() => _cargandoFechas = true);
    try {
      await ref.read(apiServiceProvider).getFechasConParte(id);
    } catch (e) {
      debugPrint('>>> error cargarFechasDeOperario: $e');
    } finally {
      if (mounted) setState(() => _cargandoFechas = false);
    }
  }

  /// Carga fechas libres habilitadas por el admin.
  Future<void> _cargarFechasPermitidas() async {
    try {
      final fechas = await ref.read(apiServiceProvider).getMisFechasLibres();
      if (mounted) setState(() => _fechasPermitidas = fechas);
    } catch (e) {
      debugPrint('>>> error cargarFechasPermitidas: $e');
    }
  }

  /// Comprueba si una fecha esta en las fechas habilitadas por el admin.
  bool _fechaEstaPermitida(DateTime dia) => _fechasPermitidas.any(
    (f) => f.year == dia.year && f.month == dia.month && f.day == dia.day,
  );

  /// Permite o no seleccionar una fecha segun el rol del usuario.
  bool _predicate(DateTime dia, bool esGestor) {
    if (esGestor) return true;
    final ahora = DateTime.now();
    if (dia.year == ahora.year &&
        dia.month == ahora.month &&
        dia.day == ahora.day)
      return true;
    return _fechaEstaPermitida(dia);
  }

  @override
  void dispose() {
    _obraSearchCtrl.dispose();
    super.dispose();
  }

  /// Abre el selector de fechas respetando las fechas permitidas.
  /// Para no gestores busca automaticamente la fecha disponible mas cercana.
  Future<void> _pickDate(bool esGestor) async {
    final ahora = DateTime.now();
    DateTime initialDate = _fecha;
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime.now().add(const Duration(days: 365));

    // Ajusta limites para no gestores segun fechas permitidas
    if (!esGestor && _fechasPermitidas.isNotEmpty) {
      DateTime? minPermitida;
      DateTime? maxPermitida;
      for (final f in _fechasPermitidas) {
        if (minPermitida == null || f.isBefore(minPermitida)) minPermitida = f;
        if (maxPermitida == null || f.isAfter(maxPermitida)) maxPermitida = f;
      }
      if (minPermitida != null) firstDate = minPermitida;
      if (maxPermitida != null && maxPermitida.isAfter(ahora))
        lastDate = maxPermitida;
    }

    // Busca fecha disponible si la actual no lo esta
    if (!esGestor && !_predicate(initialDate, esGestor)) {
      DateTime? mejorFecha;
      for (int i = 1; i <= 60; i++) {
        final futuro = ahora.add(Duration(days: i));
        if (!futuro.isAfter(lastDate) && _predicate(futuro, esGestor)) {
          mejorFecha = futuro;
          break;
        }
      }
      if (mejorFecha == null) {
        for (int i = 1; i <= 365; i++) {
          final pasado = ahora.subtract(Duration(days: i));
          if (!pasado.isBefore(firstDate) && _predicate(pasado, esGestor)) {
            mejorFecha = pasado;
            break;
          }
        }
      }
      if (mejorFecha != null) {
        initialDate = mejorFecha;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay fechas disponibles')),
          );
        }
        return;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) => _predicate(day, esGestor),
      helpText: 'Selecciona un dia',
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  /// Abre el modal de busqueda de operarios.
  void _abrirBuscadorOperarios(BuildContext context) {
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
          child: CuerpoBuscadorOperarios(
            perfiles: _perfilesOrdenados,
            scrollController: scrollController,
            alSeleccionar: (p) {
              setState(() {
                _idPerfilSeleccionado = p.id;
                _perfilOperarioSeleccionado = p;
                _fecha = DateTime.now();
              });
              _cargarFechasDeOperario(p.id);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasActivasProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;
    final seleccionado = _perfilesOrdenados
        .where((p) => p.id == _idPerfilSeleccionado)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte Post Venta'),
        backgroundColor: Colors.purple[700], // Color distintivo para postventa
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _volverAHome,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Selector de operario (solo gestor) ----
              if (esGestor) ...[
                const Text(
                  'Operario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _perfilesOrdenados.isEmpty
                    ? const LinearProgressIndicator()
                    : TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText:
                              seleccionado?.nombreApellidoCompleto ??
                              widget.nombrePreseleccionado ??
                              'Seleccionar operario',
                          hintText: 'Toca para buscar...',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_search),
                          suffixIcon: seleccionado != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.perfilIdPreseleccionado !=
                                            null &&
                                        seleccionado.id ==
                                            widget.perfilIdPreseleccionado)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: Chip(
                                          label: const Text('Admin'),
                                          labelStyle: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                          backgroundColor: Colors.purple[700],
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() {
                                        _idPerfilSeleccionado = null;
                                        _perfilOperarioSeleccionado = null;
                                      }),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        onTap: () => _abrirBuscadorOperarios(context),
                        validator: (_) => _idPerfilSeleccionado == null
                            ? 'Selecciona un operario'
                            : null,
                      ),
                const SizedBox(height: 20),
              ],

              // ---- Fecha ----
              const Text(
                'Fecha',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (esGestor && _idPerfilSeleccionado == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Selecciona un operario primero',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: widget.fechaPreseleccionada != null
                          ? Colors.purple.shade700
                          : Colors.purple.shade300,
                      width: widget.fechaPreseleccionada != null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  leading: _cargandoFechas
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.calendar_today, color: Colors.purple[700]),
                  title: Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  subtitle: Text(
                    _cargandoFechas
                        ? 'Cargando dias disponibles...'
                        : widget.fechaPreseleccionada != null
                        ? 'Fecha preseleccionada desde el panel'
                        : _fechasPermitidas.isNotEmpty
                        ? 'Tienes ${_fechasPermitidas.length} dia(s) extra habilitados'
                        : 'Los partes son unicamente del dia de hoy',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.fechaPreseleccionada != null
                          ? Colors.purple[700]
                          : _fechasPermitidas.isNotEmpty
                          ? Colors.green[700]
                          : Colors.purple[700],
                    ),
                  ),
                  onTap: _cargandoFechas ? null : () => _pickDate(esGestor),
                ),
              const SizedBox(height: 20),

              // ---- Obra ----
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
                    hintText: 'Toca para buscar...',
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
              const SizedBox(height: 25),

              // ---- Horas normales ----
              const Text(
                'Horas normales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'horas',
                ),
                onChanged: (v) {
                  final h = double.tryParse(v.replaceAll(',', '.'));
                  if (h != null) _horasNormales = h;
                },
              ),
              const SizedBox(height: 25),

              // ---- Especialidad (operario no gestor) ----
              // El operario postventa elige especialidad manualmente
              if (!esGestor) ...[
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
                const SizedBox(height: 25),
              ],

              // ---- Especialidad (gestor con operario seleccionado) ----
              // Muestra la especialidad que ya tiene asignada el operario
              if (esGestor && _perfilOperarioSeleccionado != null) ...[
                const Text(
                  'Especialidad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _perfilOperarioSeleccionado!.especialidad ==
                                'ELECTRICIDAD'
                            ? Icons.electrical_services
                            : Icons.plumbing,
                        color:
                            _perfilOperarioSeleccionado!.especialidad ==
                                'ELECTRICIDAD'
                            ? Colors.amber[700]
                            : Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _perfilOperarioSeleccionado!.especialidad ==
                                'ELECTRICIDAD'
                            ? 'Electricidad (del operario)'
                            : _perfilOperarioSeleccionado!.especialidad ==
                                  'FONTANERIA'
                            ? 'Fontaneria (del operario)'
                            : 'Sin especialidad asignada',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],

              // ---- Descripcion ----
              const Text(
                'Tareas realizadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Descripcion del trabajo...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                onChanged: (v) => _descripcion = v,
              ),
              const SizedBox(height: 30),

              // ---- Firma + trabajos extra ----
              const Divider(),
              const SizedBox(height: 16),
              SeccionFirma(
                onFirmaChanged: (base64, nombre) => setState(() {
                  _firmaBase64 = base64;
                  _nombreFirma = nombre;
                }),
                onTrabajosExtraChanged: (v) => _trabajosExtra = v,
              ),
              const SizedBox(height: 30),

              // ---- Boton de envio ----
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
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

  /// Muestra dialogo de ayuda sobre formato de horas.
  void _mostrarDialogoHoras() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Formato de horas incorrecto'),
        content: const Text(
          'Las horas deben escribirse en decimales, 0,5 es media hora.\n\n'
          'Ejemplos validos:\n'
          '- 0.5  (media hora)\n'
          '- 2.5  (dos horas y media)\n',
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

  /// Envia el parte de postventa al servidor con especialidad incluida.
  /// Si no hay red, lo guarda en la cola offline.
  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    // Valida formato de horas
    if (_horasNormales % 0.5 != 0) {
      _mostrarDialogoHoras();
      return;
    }

    setState(() => _enviando = true);

    final esGestor = perfil.esAdmin || perfil.esGestion;

    // Determina especialidad: gestor usa la del operario, operario la eligio
    final String? especialidadFinal = esGestor
        ? (_perfilOperarioSeleccionado?.especialidad?.isNotEmpty == true
              ? _perfilOperarioSeleccionado!.especialidad
              : null)
        : _especialidad;

    // Construye datos incluyendo es_post_venta=true
    final data = <String, dynamic>{
      'id_obra': _idObraSeleccionada,
      'id_perfil': esGestor ? _idPerfilSeleccionado : perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales': _horasNormales,
      'descripcion': _descripcion,
      'es_post_venta': true, // Marca como parte de postventa
      if (especialidadFinal != null) 'especialidad': especialidadFinal,
      if (_firmaBase64 != null) 'firma_base64': _firmaBase64,
      if (_nombreFirma != null) 'nombre_firmado': _nombreFirma,
      if (_trabajosExtra.isNotEmpty) 'trabajos_extra': _trabajosExtra,
    };

    try {
      // Verifica conectividad
      final resultado = await Connectivity().checkConnectivity();
      final hayRed = resultado.any((r) => r != ConnectivityResult.none);

      if (!hayRed) {
        // Sin conexion: cola offline
        await ref.read(offlineQueueProvider).guardarParteOffline(data);
        ref.invalidate(pendientesOfflineProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sin conexion - parte guardado, se enviara automaticamente',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          _volverAHome();
        }
        return;
      }

      // Envia al servidor
      await ref.read(apiServiceProvider).crearParte(data);
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parte post venta enviado correctamente'),
          ),
        );
        _volverAHome();
      }
    } on DioException catch (_) {
      // Error de conexion: guarda offline
      await ref.read(offlineQueueProvider).guardarParteOffline(data);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexion - parte guardado localmente'),
            backgroundColor: Colors.orange,
          ),
        );
        _volverAHome();
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
