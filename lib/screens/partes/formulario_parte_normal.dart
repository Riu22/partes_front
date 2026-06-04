/// Formulario para crear un parte de trabajo normal (operario/encargado).
/// Permite seleccionar operario (si eres gestor), fecha, obra, horas,
/// especialidad, descripción y firma del cliente. Soporta guardado offline
/// y selección de fechas permitidas por el administrador.
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

/// Formulario para registrar un nuevo parte de trabajo de un operario.
/// Los gestores pueden crear partes para cualquier operario;
/// los operarios solo crean partes para sí mismos.
class FormularioParteNormal extends ConsumerStatefulWidget {
  const FormularioParteNormal({
    super.key,
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  final String? perfilIdPreseleccionado;
  final String? nombrePreseleccionado;
  final DateTime? fechaPreseleccionada;

  @override
  ConsumerState<FormularioParteNormal> createState() =>
      _FormularioParteNormalState();
}

class _FormularioParteNormalState extends ConsumerState<FormularioParteNormal> {
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();
  late DateTime _fecha;
  double _horasNormales = 0;
  String _descripcion = '';
  String _trabajosExtra = '';
  int? _idObraSeleccionada;
  String? _idPerfilSeleccionado;
  Perfil? _perfilOperarioSeleccionado;
  String? _especialidad;
  bool _enviando = false;
  String? _firmaBase64;
  String? _nombreFirma;

  List<Perfil> _perfilesOrdenados = [];
  bool _cargandoFechas = false;
  List<DateTime> _fechasPermitidas = [];

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

  Future<void> _cargarFechasPermitidas() async {
    try {
      final fechas = await ref.read(apiServiceProvider).getMisFechasLibres();
      if (mounted) setState(() => _fechasPermitidas = fechas);
    } catch (e) {
      debugPrint('>>> error cargarFechasPermitidas: $e');
    }
  }

  /// Comprueba si una fecha está dentro de las fechas habilitadas
  /// por el administrador (días libres para crear partes).
  bool _fechaEstaPermitida(DateTime dia) => _fechasPermitidas.any(
    (f) => f.year == dia.year && f.month == dia.month && f.day == dia.day,
  );

  /// Determina si una fecha se puede seleccionar.
  /// Los gestores pueden seleccionar cualquier fecha.
  /// Los operarios solo pueden seleccionar el día de hoy o fechas libres.
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

  /// Abre un selector de fechas restringido a las fechas permitidas.
  /// Para no gestores, busca automáticamente la fecha disponible más
  /// cercana si la fecha actual no está permitida.
  Future<void> _pickDate(bool esGestor) async {
    final ahora = DateTime.now();
    DateTime initialDate = _fecha;
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime.now().add(const Duration(days: 365));

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
    );
    if (picked != null) setState(() => _fecha = picked);
  }

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
                _especialidad = null;
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

    final operarioEsPostventa = _perfilOperarioSeleccionado?.postventa == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte'),
        backgroundColor: Colors.orange[800],
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
              // ── Selector de operario (solo admin/gestión) ──
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
                                          backgroundColor: Colors.orange[800],
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() {
                                        _idPerfilSeleccionado = null;
                                        _perfilOperarioSeleccionado = null;
                                        _especialidad = null;
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

              // ── Fecha ──
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
                          ? Colors.orange.shade700
                          : Colors.orange.shade300,
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
                      : Icon(Icons.calendar_today, color: Colors.orange[800]),
                  title: Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  subtitle: Text(
                    _cargandoFechas
                        ? 'Cargando días disponibles...'
                        : widget.fechaPreseleccionada != null
                        ? 'Fecha preseleccionada desde el panel'
                        : _fechasPermitidas.isNotEmpty
                        ? 'Tienes ${_fechasPermitidas.length} día(s) extra habilitados'
                        : 'No tienes días disponibles',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.fechaPreseleccionada != null
                          ? Colors.orange[800]
                          : _fechasPermitidas.isNotEmpty
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                  onTap: _cargandoFechas ? null : () => _pickDate(esGestor),
                ),
              const SizedBox(height: 20),

              // ── Obra ──
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

              // ── Horas ──
              const Text(
                'Horas',
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

              // ── Especialidad (solo gestor con operario postventa) ──
              if (esGestor && operarioEsPostventa) ...[
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
                const SizedBox(height: 25),
              ],

              // ── Descripción ──
              const Text(
                'Tareas realizadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Descripción del trabajo...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                onChanged: (v) => _descripcion = v,
              ),
              const SizedBox(height: 30),

              // ── Firma + trabajos extra ──
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

  void _mostrarDialogoHoras() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Formato de horas incorrecto'),
        content: const Text(
          'Las horas deben escribirse en decimales, 0,5 es media hora.\n\n'
          'Ejemplos válidos:\n'
          '• 0.5  (media hora)\n'
          '• 2.5  (dos horas y media)\n',
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

  /// Envía el parte al servidor. Si no hay conexión, lo guarda en la
  /// cola offline para enviarlo automáticamente cuando se recupere la red.
  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    final esGestor = perfil.esAdmin || perfil.esGestion;
    final operarioEsPostventa = _perfilOperarioSeleccionado?.postventa == true;

    if (esGestor && operarioEsPostventa && _especialidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona una especialidad para el operario de post venta',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_horasNormales % 0.5 != 0) {
      _mostrarDialogoHoras();
      return;
    }

    setState(() => _enviando = true);

    final String? especialidad = esGestor
        ? (operarioEsPostventa
              ? _especialidad
              : (_perfilOperarioSeleccionado?.especialidad?.isNotEmpty == true
                    ? _perfilOperarioSeleccionado!.especialidad
                    : null))
        : (perfil.especialidad.isNotEmpty ? perfil.especialidad : null);

    final data = <String, dynamic>{
      'id_obra': _idObraSeleccionada,
      'id_perfil': esGestor ? _idPerfilSeleccionado : perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales': _horasNormales,
      'descripcion': _descripcion,
      if (especialidad != null) 'especialidad': especialidad,
      if (_firmaBase64 != null) 'firma_base64': _firmaBase64,
      if (_nombreFirma != null) 'nombre_firmado': _nombreFirma,
      if (_trabajosExtra.isNotEmpty) 'trabajos_extra': _trabajosExtra,
    };

    try {
      final resultado = await Connectivity().checkConnectivity();
      final hayRed = resultado.any((r) => r != ConnectivityResult.none);

      if (!hayRed) {
        await ref.read(offlineQueueProvider).guardarParteOffline(data);
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
          _volverAHome();
        }
        return;
      }

      await ref.read(apiServiceProvider).crearParte(data);
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        _volverAHome();
      }
    } on DioException catch (_) {
      await ref.read(offlineQueueProvider).guardarParteOffline(data);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión — parte guardado localmente'),
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