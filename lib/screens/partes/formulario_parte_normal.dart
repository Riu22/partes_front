// =============================================================================
// formulario_parte_normal.dart  -  Formulario de parte de trabajo normal
// =============================================================================
// ASPECTO EN PANTALLA:
//   AppBar naranja con titulo "Nuevo Parte" y boton de cerrar (X).
//   Formulario vertical con:
//     - Selector de operario (solo gestores): campo de solo lectura que abre
//       un modal de busqueda de operarios con chip "Admin" si viene
//       preseleccionado desde el panel de admin.
//     - Fecha: ListTile que abre DatePicker con dias restringidos segun rol.
//     - Obra: campo de solo lectura que abre modal de busqueda de obras.
//     - Banner de postventa: si la obra seleccionada es de postventa.
//     - Horas: campo numerico con sufijo "horas".
//     - Especialidad: botones Electricidad/Fontaneria (solo gestor+postventa).
//     - Descripcion: textarea multilinea.
//     - Firma + trabajos extra: widget reutilizable SeccionFirma.
//     - Boton "ENVIAR PARTE" naranja a ancho completo.
//
// USO:
//   Registrar un parte con operario, fecha, obra, horas,
//   especialidad (si aplica), descripcion y firma del cliente.
//
// QUIEN LO USA:
//   Operarios (crean sus propios partes) y gestores (crean partes
//   para cualquier operario).
//
// COMO SE LLEGA:
//   Desde partes_screen.dart al pulsar FAB y elegir "normal",
//   o desde admin_home_screen.dart al pulsar "Crear parte" en
//   una incidencia.
//
// A DONDE VA:
//   POST /api/partes (servidor) o cola offline (shared_prefs).
//
// QUE DATOS USA:
//   auth_provider, perfiles_provider, obras_provider,
//   apiServiceProvider, offlineQueueProvider, connectivity_plus.
//
// INTERACCION DEL USUARIO:
//   - Gestor: toca campo operario -> abre modal con lista de operarios
//   - Todos: toca fecha -> abre DatePicker con validacion de permisos
//   - Todos: toca obra -> abre modal busqueda con filtro por texto
//   - Escribe horas en campo numerico (decimales, soporta coma/punto)
//   - Gestor+postventa: elige especialidad con botones de seleccion
//   - Escribe descripcion en textarea
//   - Toca "Tocar para firmar" -> modal con pad de firma
//   - Toca "ENVIAR PARTE" -> valida y envia o guarda offline
//
// OFFLINE:
//   Si no hay red, guarda en offlineQueueProvider y lo sincroniza
//   automaticamente al recuperar conexion.
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
///
/// Los gestores pueden crear partes para cualquier operario;
/// los operarios solo crean partes para si mismos.
///
/// Soporta preseleccion de operario y fecha cuando se navega desde
/// el panel de administracion (admin_home_screen), permitiendo crear
/// un parte directamente desde una incidencia sin tener que rellenar
/// todos los campos.
///
/// PARAMETROS OPCIONALES:
///   [perfilIdPreseleccionado] - ID del operario cuando viene desde admin.
///   [nombrePreseleccionado] - Nombre visible del operario preseleccionado.
///   [fechaPreseleccionada] - Fecha sugerida cuando viene desde admin.
class FormularioParteNormal extends ConsumerStatefulWidget {
  const FormularioParteNormal({
    super.key,
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  /// ID del operario preseleccionado cuando se navega desde el panel de
  /// administracion. Si es null, el usuario debe seleccionar un operario
  /// manualmente (solo gestores) o usa su propio perfil (operarios).
  final String? perfilIdPreseleccionado;

  /// Nombre visible del operario preseleccionado, se muestra en el campo
  /// de seleccion de operario como label. Si es null se muestra el texto
  /// generico "Seleccionar operario".
  final String? nombrePreseleccionado;

  /// Fecha sugerida para el parte cuando se navega desde el panel de
  /// administracion. Si es null se usa la fecha actual del dispositivo.
  /// Al pasarla, el ListTile de fecha se resalta con borde naranja.
  final DateTime? fechaPreseleccionada;

  @override
  ConsumerState<FormularioParteNormal> createState() =>
      _FormularioParteNormalState();
}

/// Estado mutable del formulario de parte normal.
///
/// Gestiona todo el ciclo de vida del formulario: inicializacion con datos
/// preseleccionados, carga asincrona de perfiles y fechas, seleccion de
/// obra/operario/fecha, captura de firma, validacion y envio al servidor
/// o a la cola offline si no hay conexion.
///
/// Lifecycle:
///   1. initState: inicializa fecha, carga perfiles y fechas permitidas.
///   2. build: renderiza el formulario completo con todos los campos.
///   3. dispose: libera controladores.
class _FormularioParteNormalState extends ConsumerState<FormularioParteNormal> {
  // --------------------------------------------------------------------------
  // CLAVES Y CONTROLADORES
  // --------------------------------------------------------------------------

  /// Clave global del formulario para validacion y acceso al estado del Form.
  /// Se usa en _enviarParte() para llamar a _formKey.currentState!.validate().
  final _formKey = GlobalKey<FormState>();

  /// Controlador del campo de busqueda de obra (solo lectura).
  /// Almacena el texto visible con el nombre de la obra seleccionada.
  final _obraSearchCtrl = TextEditingController();

  // --------------------------------------------------------------------------
  // ESTADO DEL FORMULARIO
  // --------------------------------------------------------------------------

  /// Fecha seleccionada para el parte de trabajo.
  /// Se inicializa en initState con widget.fechaPreseleccionada o DateTime.now().
  /// Se actualiza al seleccionar una fecha en el DatePicker (_pickDate).
  late DateTime _fecha;

  /// Horas normales trabajadas en formato decimal (ej: 8.0, 4.5).
  /// Se valida que sean multiplos de 0.5 antes de enviar.
  double _horasNormales = 0;

  /// Descripcion de las tareas realizadas durante la jornada.
  /// Es un campo obligatorio validado en el formulario.
  String _descripcion = '';

  /// Trabajos extra opcionales (texto libre).
  /// Se envia al servidor solo si no esta vacio.
  String _trabajosExtra = '';

  /// ID de la obra seleccionada (clave foranea).
  /// Se usa como 'id_obra' en la peticion al servidor.
  int? _idObraSeleccionada;

  /// ID del operario seleccionado (solo para gestores).
  /// Los operarios usan su propio id del perfil logueado.
  String? _idPerfilSeleccionado;

  /// Objeto Perfil completo del operario seleccionado.
  /// Se usa para acceder a datos como especialidad, postventa, etc.
  Perfil? _perfilOperarioSeleccionado;

  /// Especialidad seleccionada ('ELECTRICIDAD' o 'FONTANERIA').
  /// Solo aplica cuando gestor crea parte para operario de postventa.
  String? _especialidad;

  /// Bandera que deshabilita el boton de envio durante el proceso.
  /// Evita envios duplicados mientras se esta enviando al servidor.
  bool _enviando = false;

  /// Firma del cliente en formato base64 (data URI PNG).
  /// Se captura desde el widget SeccionFirma.
  String? _firmaBase64;

  /// Nombre de la persona que firmo (opcional, texto libre).
  /// Se muestra en el parte como identificador del firmante.
  String? _nombreFirma;

  /// Indica si la obra seleccionada es de postventa.
  /// Si es true, se muestra un banner informativo y se pide
  /// confirmacion antes de enviar el parte.
  bool _obraEsPostventa = false;

  // --------------------------------------------------------------------------
  // PERFILES Y FECHAS
  // --------------------------------------------------------------------------

  /// Lista de perfiles activos ordenados alfabeticamente por apellido.
  /// Se usa en el modal de busqueda de operarios para gestores.
  List<Perfil> _perfilesOrdenados = [];

  /// Indica si se estan cargando las fechas con parte del servidor.
  /// Muestra un indicador de progreso en el ListTile de fecha.
  bool _cargandoFechas = false;

  /// Fechas extras habilitadas por el administrador para crear partes
  /// en dias distintos al actual. Solo aplica para no gestores.
  List<DateTime> _fechasPermitidas = [];

  /// METODO: _volverAHome
  ///
  /// QUE HACE:
  ///   Navega a la pantalla de inicio correspondiente segun el rol del
  ///   usuario logueado.
  ///
  /// LOGICA INTERNA:
  ///   Lee el perfil actual de authProvider. Si es admin o gestion redirige
  ///   a '/admin', en caso contrario redirige a '/partes'.
  ///
  /// VALOR DE RETORNO:
  ///   void. La navegacion se realiza mediante context.go() de go_router.
  void _volverAHome() {
    final perfil = ref.read(authProvider).valueOrNull;
    final esAdminOGestion =
        perfil != null && (perfil.esAdmin || perfil.esGestion);
    context.go(esAdminOGestion ? '/admin' : '/partes');
  }

  @override
  void initState() {
    super.initState();

    // ── PASO 1: Inicializar fecha ──────────────────────────────────────────
    // Usa la fecha preseleccionada (desde admin) o la fecha actual
    _fecha = widget.fechaPreseleccionada ?? DateTime.now();

    // ── PASO 2: Cargar fechas del operario ─────────────────────────────────
    // Si hay perfil preseleccionado, carga sus fechas con parte
    if (widget.perfilIdPreseleccionado != null) {
      _idPerfilSeleccionado = widget.perfilIdPreseleccionado;
      _cargarFechasDeOperario(widget.perfilIdPreseleccionado!);
    } else {
      // Carga las fechas del usuario actual (operario)
      _cargarMisFechas();
    }

    // ── PASO 3: Cargar fechas libres ───────────────────────────────────────
    // Dias extras que el admin ha habilitado para crear partes
    _cargarFechasPermitidas();

    // ── PASO 4: Escuchar cambios en perfiles ───────────────────────────────
    // Despues del primer frame, suscribe al provider de perfiles para
    // tener la lista actualizada de operarios (necesaria para gestores)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(perfilesProvider, (_, next) {
        next.whenData((perfiles) {
          if (mounted) {
            final ordenados = ordenarPerfiles(perfiles);
            setState(() {
              _perfilesOrdenados = ordenados;
              // Si hay un perfil preseleccionado desde admin, lo asigna
              // automaticamente en el estado del formulario
              if (widget.perfilIdPreseleccionado != null &&
                  _perfilOperarioSeleccionado == null) {
                _perfilOperarioSeleccionado = ordenados
                    .where((p) => p.id == widget.perfilIdPreseleccionado)
                    .firstOrNull;
              }
            });
          }
        });
        // fireImmediately: true ejecuta el callback inmediatamente
        // con el ultimo valor conocido del provider
      }, fireImmediately: true);
    });
  }

  /// METODO: _cargarMisFechas
  ///
  /// QUE HACE:
  ///   Consulta al servidor las fechas en las que el usuario actual ya
  ///   tiene registrado un parte de trabajo.
  ///
  /// LOGICA INTERNA:
  ///   Activa el flag _cargandoFechas para mostrar indicador de progreso.
  ///   Llama a apiServiceProvider.getMisFechasConParte(). En caso de error
  ///   solo hace debugPrint, no interrumpe el flujo.
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

  /// METODO: _cargarFechasDeOperario
  ///
  /// QUE HACE:
  ///   Consulta al servidor las fechas con parte de un operario concreto.
  ///   Solo usado por gestores cuando seleccionan un operario.
  ///
  /// PARAMETROS:
  ///   [id] - ID del operario del que se quieren consultar las fechas.
  ///
  /// LOGICA INTERNA:
  ///   Similar a _cargarMisFechas pero para un operario especifico.
  ///   Usa apiServiceProvider.getFechasConParte(id) en lugar del metodo
  ///   generico sin parametros.
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

  /// METODO: _cargarFechasPermitidas
  ///
  /// QUE HACE:
  ///   Carga del servidor los dias extras que el administrador ha habilitado
  ///   para que los operarios puedan crear partes fuera de la fecha actual.
  ///
  /// LOGICA INTERNA:
  ///   Llama a apiServiceProvider.getMisFechasLibres() y almacena el resultado
  ///   en _fechasPermitidas. Los errores se capturan y muestran por debugPrint.
  Future<void> _cargarFechasPermitidas() async {
    try {
      final fechas = await ref.read(apiServiceProvider).getMisFechasLibres();
      if (mounted) setState(() => _fechasPermitidas = fechas);
    } catch (e) {
      debugPrint('>>> error cargarFechasPermitidas: $e');
    }
  }

  /// METODO: _fechaEstaPermitida
  ///
  /// QUE HACE:
  ///   Verifica si una fecha concreta esta dentro de la lista de dias
  ///   extras habilitados por el administrador.
  ///
  /// PARAMETROS:
  ///   [dia] - La fecha a comprobar (DateTime).
  ///
  /// LOGICA INTERNA:
  ///   Compara ano, mes y dia de cada fecha en _fechasPermitidas con el
  ///   parametro [dia]. No compara horas ni minutos.
  ///
  /// VALOR DE RETORNO:
  ///   true si la fecha esta en la lista de permitidas.
  bool _fechaEstaPermitida(DateTime dia) => _fechasPermitidas.any(
    (f) => f.year == dia.year && f.month == dia.month && f.day == dia.day,
  );

  /// METODO: _predicate
  ///
  /// QUE HACE:
  ///   Funcion de validacion para el DatePicker de Flutter. Determina si
  ///   un dia concreto puede ser seleccionado como fecha del parte.
  ///
  /// PARAMETROS:
  ///   [dia] - La fecha a evaluar.
  ///   [esGestor] - Indica si el usuario actual tiene rol de gestion/admin.
  ///
  /// REGLAS:
  ///   - Gestores: cualquier fecha es seleccionable.
  ///   - Operarios: solo el dia de hoy o fechas de _fechasPermitidas.
  ///
  /// VALOR DE RETORNO:
  ///   true si la fecha se puede seleccionar segun el rol del usuario.
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
    // Libera el controlador del campo de busqueda de obra
    _obraSearchCtrl.dispose();
    super.dispose();
  }

  /// METODO: _pickDate
  ///
  /// QUE HACE:
  ///   Abre el DatePicker nativo de Flutter para seleccionar la fecha del
  ///   parte. Aplica restricciones segun el rol del usuario.
  ///
  /// PARAMETROS:
  ///   [esGestor] - Indica si el usuario tiene permisos de gestion/admin.
  ///
  /// LOGICA INTERNA:
  ///   1. Para gestores: rango completo (2020 - hoy+365 dias).
  ///   2. Para operarios: ajusta el rango a las fechas permitidas.
  ///   3. Si la fecha actual no esta permitida, busca la mas cercana
  ///      hacia adelante (60 dias) o hacia atras (365 dias).
  ///   4. Si no encuentra ninguna, muestra SnackBar de error.
  ///   5. Abre showDatePicker con selectableDayPredicate.
  ///
  /// VALOR DE RETORNO:
  ///   void. Actualiza _fecha si el usuario selecciona una fecha.
  Future<void> _pickDate(bool esGestor) async {
    final ahora = DateTime.now();
    // Fecha que se mostrara seleccionada al abrir el DatePicker
    DateTime initialDate = _fecha;
    // Fecha minima que se puede seleccionar (ano 2020)
    DateTime firstDate = DateTime(2020);
    // Fecha maxima: un ano hacia adelante desde hoy
    DateTime lastDate = DateTime.now().add(const Duration(days: 365));

    // Para no gestores: ajusta el rango para que solo se puedan
    // seleccionar las fechas permitidas por el administrador
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

    // Si la fecha actual no esta disponible, busca automaticamente
    // la fecha permitida mas cercana
    if (!esGestor && !_predicate(initialDate, esGestor)) {
      DateTime? mejorFecha;
      // Primero busca hacia adelante hasta 60 dias
      for (int i = 1; i <= 60; i++) {
        final futuro = ahora.add(Duration(days: i));
        if (!futuro.isAfter(lastDate) && _predicate(futuro, esGestor)) {
          mejorFecha = futuro;
          break;
        }
      }
      // Si no encuentra hacia adelante, busca hacia atras hasta 365 dias
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

    // Abre el DatePicker nativo de Flutter con las restricciones definidas
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) => _predicate(day, esGestor),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  /// METODO: _abrirBuscadorOperarios
  ///
  /// QUE HACE:
  ///   Abre un modal bottom sheet con el buscador de operarios para que el
  ///   gestor seleccione un operario. Solo visible para roles admin/gestion.
  ///
  /// PARAMETROS:
  ///   [context] - BuildContext para mostrar el modal.
  ///
  /// LOGICA INTERNA:
  ///   Usa showModalBottomSheet con DraggableScrollableSheet al 80% de altura.
  ///   Al seleccionar un operario: actualiza _idPerfilSeleccionado,
  ///   _perfilOperarioSeleccionado, resetea _fecha y _especialidad, y
  ///   carga las fechas con parte del operario seleccionado.
  void _abrirBuscadorOperarios(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
        // Ocupa el 80% de la pantalla, minimo 50%, maximo 95%
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          // Fondo blanco con esquinas superiores redondeadas
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
    // ── PROVEEDORES Y ESTADO ──────────────────────────────────────────────
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
            // Al pulsar la X, navega al inicio segun el rol del usuario
            onPressed: _volverAHome,
          ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          // Asigna la clave global para validacion del formulario
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════════════════════
              // SECCION: Selector de operario
              // Solo visible para administradores y gestores. Los operarios
              // usan su propio perfil automaticamente.
              // El campo es de solo lectura y al tocarlo abre un modal con
              // la lista completa de operarios activos.
              // ═══════════════════════════════════════════════════════════════
              if (esGestor) ...[
                const Text(
                  'Operario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Mientras se cargan los perfiles, muestra indicador de progreso
                _perfilesOrdenados.isEmpty
                    ? const LinearProgressIndicator()
                    : TextFormField(
                        // Solo lectura: al tocarlo abre el modal de busqueda
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
                                    // Chip "Admin": indica que el operario fue
                                    // preseleccionado desde el panel de admin
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
                                    // Boton X: limpia la seleccion y resetea
                                    // la especialidad asociada
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

              // ═══════════════════════════════════════════════════════════════
              // SECCION: Fecha
              // Muestra la fecha seleccionada y permite abrir el DatePicker.
              // Para gestores sin operario seleccionado muestra un aviso
              // informativo en lugar del selector de fecha.
              // ═══════════════════════════════════════════════════════════════
              const Text(
                'Fecha',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Si es gestor pero aun no ha seleccionado operario, muestra aviso
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
                // ListTile con la fecha actual: al tocarlo abre el DatePicker
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

              // ═══════════════════════════════════════════════════════════════
              // SECCION: Obra
              // Selector de obra que abre un modal de busqueda con filtro
              // por nombre, municipio o calle. Las obras se cargan desde
              // obrasActivasProvider (solo obras en curso).
              // ═══════════════════════════════════════════════════════════════
              const Text(
                'Obra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Carga asincrona: muestra progreso, error o campo de seleccion
              // segun el estado de obrasActivasProvider
              obrasAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                  data: (obras) => TextFormField(
                  controller: _obraSearchCtrl,
                  // Solo lectura: al tocarlo abre el modal de busqueda de obras
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
                      // Actualiza el flag de postventa para mostrar el banner
                      _obraEsPostventa = o.postventa == true;
                    });
                  }),
                  validator: (v) => _idObraSeleccionada == null
                      ? 'Selecciona una obra'
                      : null,
                ),
              ),

              // ── BANNER: obra de postventa ──────────────────────────────────
              // Aparece debajo del selector de obra cuando la obra
              // seleccionada tiene el flag postventa = true.
              // Advierte al usuario que se pedira confirmacion al enviar.
              if (_obraEsPostventa) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[700]!, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber[800],
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta obra es de postventa. Al enviar el parte '
                          'se te pedirá confirmación.',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // ═══════════════════════════════════════════════════════════════
              // SECCION: Horas normales
              // Campo numerico que acepta decimales. Soporta tanto coma
              // como punto como separador decimal.
              // ═══════════════════════════════════════════════════════════════
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
                  // Reemplaza coma por punto para soportar ambos formatos
                  // y convierte a double. Si no es numero valido, ignora.
                  final h = double.tryParse(v.replaceAll(',', '.'));
                  if (h != null) _horasNormales = h;
                },
              ),
              const SizedBox(height: 25),

              // ═══════════════════════════════════════════════════════════════
              // SECCION: Especialidad
              // Solo visible cuando un gestor crea un parte para un operario
              // de postventa. El gestor debe elegir entre Electricidad o
              // Fontaneria para el parte.
              // ═══════════════════════════════════════════════════════════════
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

              // ═══════════════════════════════════════════════════════════════
              // SECCION: Descripcion de tareas
              // Area de texto multilinea donde el operario describe el
              // trabajo realizado. Es un campo obligatorio.
              // ═══════════════════════════════════════════════════════════════
              const Text(
                'Tareas realizadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Textarea de 5 lineas para la descripcion detallada
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
        hintText: 'Descripcion del trabajo...',
        border: OutlineInputBorder(),
      ),
      // Validacion: el campo no puede estar vacio
      validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                onChanged: (v) => _descripcion = v,
              ),
              const SizedBox(height: 30),

              // ═══════════════════════════════════════════════════════════════
              // SECCION: Firma del cliente + trabajos extra
              // Widget reutilizable SeccionFirma que permite:
              //   - Escribir el nombre del firmante
              //   - Anadir trabajos extra no previstos
              //   - Capturar la firma en un pad tactil
              // ═══════════════════════════════════════════════════════════════
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

              // ═══════════════════════════════════════════════════════════════
              // SECCION: Boton de envio
              // Boton naranja a ancho completo. Se deshabilita y muestra
              // un indicador de progreso mientras se procesa el envio.
              // ═══════════════════════════════════════════════════════════════
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

  /// METODO: _mostrarDialogoHoras
  ///
  /// QUE HACE:
  ///   Muestra un dialogo informativo cuando el usuario introduce un valor
  ///   de horas no valido (no multiplo de 0.5).
  ///
  /// CONTENIDO:
  ///   Explica que las horas deben escribirse en decimales y muestra
  ///   ejemplos validos (0.5, 2.5, etc.).
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

  /// METODO: _confirmarObraPostventa
  ///
  /// QUE HACE:
  ///   Muestra un dialogo de confirmacion cuando la obra seleccionada es de
  ///   postventa. El usuario debe confirmar explicitamente que quiere enviar
  ///   el parte a una obra de postventa.
  ///
  /// LOGICA INTERNA:
  ///   Usa showDialog<bool> que devuelve true si el usuario pulsa "Si, enviar"
  ///   o false si pulsa "Cancelar" o cierra el dialogo.
  ///
  /// VALOR DE RETORNO:
  ///   Future<bool> - true si el usuario confirma el envio.
  Future<bool> _confirmarObraPostventa() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber[700]),
            const SizedBox(width: 8),
            const Text('Obra de postventa'),
          ],
        ),
        content: const Text(
          'La obra seleccionada es de postventa.\n\n'
          '¿Estás seguro de que quieres enviar este parte?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, enviar'),
          ),
        ],
      ),
    );
    return confirmado == true;
  }

  /// METODO: _enviarParte
  ///
  /// QUE HACE:
  ///   Procesa el envio del parte de trabajo. Valida el formulario,
  ///   construye el mapa de datos, verifica la conectividad y envia al
  ///   servidor o guarda en la cola offline segun corresponda.
  ///
  /// LOGICA INTERNA:
  ///   1. Valida el formulario con _formKey.currentState!.validate().
  ///   2. Verifica que gestor haya seleccionado especialidad para postventa.
  ///   3. Valida que las horas sean multiplo de 0.5.
  ///   4. Si obra es postventa, pide confirmacion con _confirmarObraPostventa().
  ///   5. Construye el mapa 'data' con todos los campos del parte.
  ///   6. Verifica conectividad con Connectivity().checkConnectivity().
  ///   7. Sin conexion -> guardaParteOffline en offlineQueueProvider.
  ///   8. Con conexion -> crearParte en apiServiceProvider.
  ///   9. Error de red (DioException) -> guarda offline.
  ///   10. Error generico -> muestra SnackBar con el mensaje de error.
  ///
  /// VALOR DE RETORNO:
  ///   Future<void>. Navega a la pantalla de inicio al completar.
  Future<void> _enviarParte() async {
    // ── PASO 1: Validar formulario ─────────────────────────────────────────
    // Si la validacion falla, se muestran los errores en los campos y se sale
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    final esGestor = perfil.esAdmin || perfil.esGestion;
    final operarioEsPostventa = _perfilOperarioSeleccionado?.postventa == true;

    // ── PASO 2: Validar especialidad ───────────────────────────────────────
    // Si es gestor y el operario es postventa, debe elegir especialidad
    if (esGestor && operarioEsPostventa && _especialidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona una especialidad para el operario de postventa',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ── PASO 3: Validar horas ──────────────────────────────────────────────
    // Las horas deben ser multiplo de 0.5 (0.5, 1.0, 1.5, ..., 8.0, etc.)
    if (_horasNormales % 0.5 != 0) {
      _mostrarDialogoHoras();
      return;
    }

    // ── PASO 4: Confirmar postventa ────────────────────────────────────────
    // Si la obra seleccionada es de postventa, pedir confirmacion al usuario
    if (_obraEsPostventa) {
      final confirmado = await _confirmarObraPostventa();
      // Si el usuario cancela, se aborta el envio sin mostrar error
      if (!confirmado) return;
    }

    // ── PASO 5: Preparar datos ─────────────────────────────────────────────
    setState(() => _enviando = true);

    // Determina la especialidad final segun el contexto del usuario:
    // - Gestor con operario postventa: usa _especialidad seleccionada
    // - Gestor con operario normal: usa la especialidad del operario
    // - Operario normal: usa su propia especialidad
    final String? especialidad = esGestor
        ? (operarioEsPostventa
              ? _especialidad
              : (_perfilOperarioSeleccionado?.especialidad?.isNotEmpty == true
                    ? _perfilOperarioSeleccionado!.especialidad
                    : null))
        : (perfil.especialidad.isNotEmpty ? perfil.especialidad : null);

    // Construye el mapa con todos los campos del parte para enviar al
    // servidor. Solo incluye campos opcionales si tienen valor.
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

    // ── PASO 6: Enviar o guardar offline ───────────────────────────────────
    try {
      // Verifica el estado de la conexion a internet
      final resultado = await Connectivity().checkConnectivity();
      final hayRed = resultado.any((r) => r != ConnectivityResult.none);

      if (!hayRed) {
        // SIN CONEXION: Guarda el parte en la cola offline para envio
        // automatico cuando se recupere la red
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

      // CON CONEXION: Envia el parte al servidor
      await ref.read(apiServiceProvider).crearParte(data);
      // Invalida el cache de partes para que se recargue la lista
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        _volverAHome();
      }
    } on DioException catch (_) {
      // ERROR DE RED DURANTE EL ENVIO: guarda en cola offline como fallback
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
      // ERROR INESPERADO: muestra el mensaje al usuario
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
      // Restaura el estado del boton de envio
      if (mounted) setState(() => _enviando = false);
    }
  }
}