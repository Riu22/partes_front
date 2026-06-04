// =============================================================================
// formulario_parte_normal.dart
// =============================================================================
// QUE ES:       Formulario para crear un parte de trabajo normal (operario).
// PARA QUE:     Registrar un parte con operario, fecha, obra, horas,
//               especialidad (si aplica), descripcion y firma del cliente.
// QUIEN LO USA: Operarios (crean sus propios partes) y gestores (crean partes
//               para cualquier operario).
// COMO SE LLEGA: Desde partes_screen.dart al pulsar FAB y elegir "normal",
//                o desde admin_home_screen.dart al pulsar "Crear parte" en
//                una incidencia.
// A DONDE VA:   POST /api/partes (servidor) o cola offline (shared_prefs).
// QUE DATOS USA: auth_provider, perfiles_provider, obras_provider,
//                apiServiceProvider, offlineQueueProvider, connectivity_plus.
// OFFLINE:      Si no hay red, guarda en offlineQueueProvider y lo sincroniza
//              automaticamente al recuperar conexion.
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

/// Formulario para registrar un nuevo parte de trabajo de un operario.
/// Los gestores pueden crear partes para cualquier operario;
/// los operarios solo crean partes para si mismos.
class FormularioParteNormal extends ConsumerStatefulWidget {
  const FormularioParteNormal({
    super.key,
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  // -- Parametros opcionales para preseleccion --
  final String? perfilIdPreseleccionado; // ID del operario preseleccionado
  final String? nombrePreseleccionado; // Nombre visible del operario
  final DateTime? fechaPreseleccionada; // Fecha sugerida desde admin

  @override
  ConsumerState<FormularioParteNormal> createState() =>
      _FormularioParteNormalState();
}

/// Estado mutable del formulario de parte normal.
/// Gestiona controladores, fecha, obra, horas, especialidad, firma y envio.
class _FormularioParteNormalState extends ConsumerState<FormularioParteNormal> {
  // -- Claves y controladores --
  final _formKey = GlobalKey<FormState>(); // Clave del formulario para validacion
  final _obraSearchCtrl = TextEditingController(); // Texto del buscador de obra

  // -- Estado del formulario --
  late DateTime _fecha; // Fecha seleccionada para el parte
  double _horasNormales = 0; // Horas trabajadas (en decimales)
  String _descripcion = ''; // Descripcion de las tareas realizadas
  String _trabajosExtra = ''; // Trabajos extra opcionales
  int? _idObraSeleccionada; // ID de la obra seleccionada
  String? _idPerfilSeleccionado; // ID del operario seleccionado (para gestores)
  Perfil? _perfilOperarioSeleccionado; // Objeto Perfil del operario
  String? _especialidad; // Especialidad seleccionada (ELECTRICIDAD/FONTANERIA)
  bool _enviando = false; // Bandera para deshabilitar boton durante el envio
  String? _firmaBase64; // Firma del cliente en base64
  String? _nombreFirma; // Nombre de la persona que firmo

  // -- Perfiles y fechas --
  List<Perfil> _perfilesOrdenados = []; // Lista de perfiles ordenada alfabeticamente
  bool _cargandoFechas = false; // Indica si se estan cargando fechas disponibles
  List<DateTime> _fechasPermitidas = []; // Fechas extras habilitadas por admin

  /// Navega a la pantalla de inicio segun el rol del usuario.
  /// Admin/gestion -> /admin, otros -> /partes.
  void _volverAHome() {
    final perfil = ref.read(authProvider).valueOrNull;
    final esAdminOGestion =
        perfil != null && (perfil.esAdmin || perfil.esGestion);
    context.go(esAdminOGestion ? '/admin' : '/partes');
  }

  @override
  void initState() {
    super.initState();
    // Inicializa la fecha: usa la preseleccionada o la actual
    _fecha = widget.fechaPreseleccionada ?? DateTime.now();
    // Si hay perfil preseleccionado, carga sus fechas con parte
    if (widget.perfilIdPreseleccionado != null) {
      _idPerfilSeleccionado = widget.perfilIdPreseleccionado;
      _cargarFechasDeOperario(widget.perfilIdPreseleccionado!);
    } else {
      _cargarMisFechas(); // Carga las fechas del usuario actual
    }
    // Carga las fechas libres habilitadas por el admin
    _cargarFechasPermitidas();
    // Despues del primer frame, escucha cambios en perfilesProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(perfilesProvider, (_, next) {
        next.whenData((perfiles) {
          if (mounted) {
            final ordenados = ordenarPerfiles(perfiles);
            setState(() {
              _perfilesOrdenados = ordenados;
              // Si hay preseleccion, asigna el perfil correspondiente
              if (widget.perfilIdPreseleccionado != null &&
                  _perfilOperarioSeleccionado == null) {
                _perfilOperarioSeleccionado = ordenados
                    .where((p) => p.id == widget.perfilIdPreseleccionado)
                    .firstOrNull;
              }
            });
          }
        });
      }, fireImmediately: true); // Ejecuta inmediatamente
    });
  }

  /// Carga las fechas en las que el usuario actual ya tiene parte.
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

  /// Carga las fechas con parte de un operario especifico (para gestores).
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

  /// Carga las fechas libres (dias extra habilitados por el admin).
  Future<void> _cargarFechasPermitidas() async {
    try {
      final fechas = await ref.read(apiServiceProvider).getMisFechasLibres();
      if (mounted) setState(() => _fechasPermitidas = fechas);
    } catch (e) {
      debugPrint('>>> error cargarFechasPermitidas: $e');
    }
  }

  /// Comprueba si una fecha esta dentro de las fechas habilitadas
  /// por el administrador (dias libres para crear partes).
  bool _fechaEstaPermitida(DateTime dia) => _fechasPermitidas.any(
    (f) => f.year == dia.year && f.month == dia.month && f.day == dia.day,
  );

  /// Determina si una fecha se puede seleccionar.
  /// Los gestores pueden seleccionar cualquier fecha.
  /// Los operarios solo pueden seleccionar el dia de hoy o fechas libres.
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
  /// Para no gestores, busca automaticamente la fecha disponible mas
  /// cercana si la fecha actual no esta permitida.
  Future<void> _pickDate(bool esGestor) async {
    final ahora = DateTime.now();
    DateTime initialDate = _fecha; // Fecha inicial del selector
    DateTime firstDate = DateTime(2020); // Fecha minima seleccionable
    DateTime lastDate = DateTime.now().add(const Duration(days: 365)); // Fecha maxima

    // Para no gestores, ajusta el rango segun las fechas permitidas
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

    // Si la fecha inicial no esta permitida, busca la mas cercana
    if (!esGestor && !_predicate(initialDate, esGestor)) {
      DateTime? mejorFecha;
      // Busca hacia adelante (60 dias)
      for (int i = 1; i <= 60; i++) {
        final futuro = ahora.add(Duration(days: i));
        if (!futuro.isAfter(lastDate) && _predicate(futuro, esGestor)) {
          mejorFecha = futuro;
          break;
        }
      }
      // Si no encuentra, busca hacia atras (365 dias)
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

    // Abre el DatePicker de Flutter
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) => _predicate(day, esGestor),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  /// Abre un modal de busqueda de operarios (solo para gestores).
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
    // Obtiene las obras activas desde el provider
    final obrasAsync = ref.watch(obrasActivasProvider);
    // Obtiene el perfil del usuario logueado
    final perfil = ref.watch(authProvider).valueOrNull;
    // Determina si es gestor (admin o gestion)
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;

    // Busca el perfil seleccionado en la lista ordenada
    final seleccionado = _perfilesOrdenados
        .where((p) => p.id == _idPerfilSeleccionado)
        .firstOrNull;

    // Verifica si el operario seleccionado es de postventa
    final operarioEsPostventa = _perfilOperarioSeleccionado?.postventa == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _volverAHome, // Cierra y vuelve al inicio
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey, // Asigna la clave para validacion
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Selector de operario (solo admin/gestion) ----
              if (esGestor) ...[
                const Text(
                  'Operario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Muestra progreso mientras carga o el campo de seleccion
                _perfilesOrdenados.isEmpty
                    ? const LinearProgressIndicator()
                    : TextFormField(
                        readOnly: true, // Solo lectura, se toca para abrir modal
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
                                    // Muestra chip "Admin" si viene preseleccionado
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
                                    // Boton para limpiar la seleccion
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

              // ---- Fecha ----
              const Text(
                'Fecha',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Si gestor sin operario, muestra mensaje informativo
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
                // ListTile que abre el selector de fecha
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
                        ? 'Cargando dias disponibles...'
                        : widget.fechaPreseleccionada != null
                        ? 'Fecha preseleccionada desde el panel'
                        : _fechasPermitidas.isNotEmpty
                        ? 'Tienes ${_fechasPermitidas.length} dia(s) extra habilitados'
                        : 'No tienes dias disponibles',
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

              // ---- Obra ----
              const Text(
                'Obra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Carga asincrona de obras desde obrasActivasProvider
              obrasAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (obras) => TextFormField(
                  controller: _obraSearchCtrl,
                  readOnly: true, // Solo lectura, se toca para abrir modal
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

              // ---- Horas ----
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
                  // Convierte comas a puntos y parsea a double
                  final h = double.tryParse(v.replaceAll(',', '.'));
                  if (h != null) _horasNormales = h;
                },
              ),
              const SizedBox(height: 25),

              // ---- Especialidad (solo gestor con operario postventa) ----
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

              // ---- Descripcion ----
              const Text(
                'Tareas realizadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 5, // Area de texto multilinea
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

  /// Muestra un dialogo de ayuda sobre el formato de horas.
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

  /// Envia el parte al servidor. Si no hay conexion, lo guarda en la
  /// cola offline para enviarlo automaticamente cuando se recupere la red.
  Future<void> _enviarParte() async {
    // Valida el formulario
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    final esGestor = perfil.esAdmin || perfil.esGestion;
    final operarioEsPostventa = _perfilOperarioSeleccionado?.postventa == true;

    // Valida que gestor seleccione especialidad para postventa
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

    // Valida formato de horas (multiplos de 0.5)
    if (_horasNormales % 0.5 != 0) {
      _mostrarDialogoHoras();
      return;
    }

    setState(() => _enviando = true);

    // Determina la especialidad final segun el contexto
    final String? especialidad = esGestor
        ? (operarioEsPostventa
              ? _especialidad
              : (_perfilOperarioSeleccionado?.especialidad?.isNotEmpty == true
                    ? _perfilOperarioSeleccionado!.especialidad
                    : null))
        : (perfil.especialidad.isNotEmpty ? perfil.especialidad : null);

    // Construye el mapa de datos del parte
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
      // Verifica conectividad con connectivity_plus
      final resultado = await Connectivity().checkConnectivity();
      final hayRed = resultado.any((r) => r != ConnectivityResult.none);

      if (!hayRed) {
        // Sin conexion: guarda en la cola offline
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

      // Con conexion: envia al servidor
      await ref.read(apiServiceProvider).crearParte(data);
      ref.invalidate(partesProvider); // Refresca la lista de partes
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        _volverAHome();
      }
    } on DioException catch (_) {
      // Error de red: guarda en la cola offline
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
