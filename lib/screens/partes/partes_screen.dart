// =============================================================================
// PANTALLA: PartesScreen
// -----------------------------------------------------------------------------
// QUE ES: Pantalla principal de partes de trabajo.
// PARA QUE SIRVE: Muestra la lista de partes con filtros por obra, operario y especialidad.
// QUIEN LA VE (rol): Todos los roles autenticados (operario, encargado, jefe, admin, gestion).
// COMO SE LLEGA: Ruta '/partes' despues del login, o desde el menu lateral.
// A DONDE VA DESPUES: A '/partes/nuevo' para crear, o a detalle de parte al hacer tap.
// QUE DATOS NECESITA: Lista de partes desde el provider, perfil del usuario.
// OFFLINE: Si, soporta visualizacion de partes cacheados y cola offline.
// =============================================================================

/// Pantalla principal de partes de trabajo.
/// Muestra la lista de partes con filtros por obra, operario y especialidad.
/// Incluye un selector de calendario (vista semanal/mensual), un indicador
/// de partes pendientes sin conexion y un boton para crear nuevos partes.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parte_trabajo.dart';
import '../../providers/sync_provider.dart';
import '../../services/update_service.dart';
import '../../providers/obras_provider.dart';
import '../../providers/perfiles_provider.dart';
import '../../helpers/tema_constants.dart';
import '../../widgets/buscador_obras_modal.dart';
import '../../widgets/buscador_operarios_modal.dart';
import '../../models/obra.dart';
import '../../models/perfil.dart';
import '../../widgets/lista_partes.dart';
import '../../widgets/partes_views.dart';

/// Lista principal de partes con filtros, vista de calendario y
/// boton para crear nuevos partes. Soporta carga directa de un parte
/// concreto (usado desde la tabla de contabilidad).
class PartesScreen extends ConsumerStatefulWidget {
  const PartesScreen({super.key, this.parteIdInicial});

  /// Si viene informado, la pantalla arranca mostrando solo ese parte.
  /// Usado al navegar desde la tabla de contabilidad (quincena_screen).
  final int? parteIdInicial;

  @override
  ConsumerState<PartesScreen> createState() => _PartesScreenState();
}

/// Estado interno de la pantalla de partes.
/// Gestiona filtros, carga de datos, sincronizacion offline y actualizaciones.
///
/// Lifecycle:
/// 1. initState: precarga datos (obras, fechas), comprueba actualizacion,
///    y si viene un parteIdInicial lo carga directamente.
/// 2. build: renderiza la interfaz con filtros, lista y boton FAB.
/// 3. dispose: libera controladores de texto.
class _PartesScreenState extends ConsumerState<PartesScreen> {
  // TextEditingController: controla el texto de los campos de busqueda
  final _obraCtrl     = TextEditingController();
  final _operarioCtrl = TextEditingController();
  Obra?   _obraSeleccionada;
  Perfil? _operarioSeleccionado;
  String? _especialidadFiltro;
  List<ParteTrabajo>? _partesFiltradas;
  bool _cargandoParte = false;

  final _updateService = UpdateService();

  // Propiedad calculada: true si hay al menos un filtro activo
  bool get _hayFiltros =>
      _obraSeleccionada != null ||
      _operarioSeleccionado != null ||
      _especialidadFiltro != null;

  // -- Ciclo de vida ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback: ejecuta el codigo despues del primer frame
    // para asegurar que el widget ya esta montado en el arbol
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Verifica conectividad antes de precargar datos
      final conectado = ref.read(conectividadProvider).valueOrNull ?? false;
      if (conectado) {
        // Invalida los providers para forzar recarga de datos frescos
        ref.invalidate(obrasActivasProvider);
        ref.invalidate(obrasProvider);
        ref.invalidate(fechasPermitidasProvider);
        try {
          // Precarga las fechas libres del usuario
          await ref.read(apiServiceProvider).getMisFechasLibres();
        } catch (e) {
          debugPrint('>>> error precarga fechas permitidas: $e');
        }
      }
      // Comprueba actualizaciones solo en movil
      if (!kIsWeb) _checkUpdate();

      // Carga directa si venimos desde contabilidad con un parte concreto
      if (widget.parteIdInicial != null) {
        await _cargarParteConcreto(widget.parteIdInicial!);
      }
    });
  }

  @override
  void dispose() {
    _obraCtrl.dispose();
    _operarioCtrl.dispose();
    super.dispose();
  }

  // -- Carga de parte concreto -----------------------------------------------

  /// Carga un parte especifico desde el proveedor y lo muestra
  /// filtrado. Se usa al navegar desde la pantalla de contabilidad.
  ///
  /// Filtra la lista completa de partes por el ID proporcionado
  /// y lo asigna a _partesFiltradas para que el build lo muestre.
  Future<void> _cargarParteConcreto(int parteId) async {
    setState(() => _cargandoParte = true);
    try {
      // Obtiene todas las partes del provider
      final partes = await ref.read(partesProvider.future);
      // Filtra por el ID solicitado
      final parte  = partes.where((p) => p.id == parteId).toList();
      if (mounted) {
        setState(() => _partesFiltradas = parte.isNotEmpty ? parte : null);
      }
    } catch (e) {
      debugPrint('>>> error cargando parte $parteId: $e');
    } finally {
      if (mounted) setState(() => _cargandoParte = false);
    }
  }

  // -- Actualizacion ---------------------------------------------------------

  /// Comprueba si hay una version mas reciente de la app.
  /// Muestra un dialogo para descargarla si es necesario.
  /// Similar a login_screen pero con mensaje extendido para
  /// indicar que hacer si falla la instalacion.
  Future<void> _checkUpdate() async {
    final update = await _updateService.hayActualizacion();
    if (update != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Nueva version disponible'),
          content: Text(
            'Hay una actualizacion a la version ${update['version']}.\n\n'
            'Descargala para tener las ultimas mejoras.\n\n'
            'Una vez descargado dale a abrir y selecciona actualizar.\n\n'
            'En caso de que de un error desinstale la aplicacion y '
            'vuelva a instalarla con el instalador que acaba de descargar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _updateService.abrirDescarga(update['url']!);
              },
              child: const Text('Descargar'),
            ),
          ],
        ),
      );
    }
  }

  // -- Filtros ---------------------------------------------------------------

  /// Llama al endpoint /partes/buscar del backend con los filtros activos
  /// (obra, operario, especialidad) y actualiza la lista de partes.
  ///
  /// Flujo:
  /// 1. Si no hay filtros, limpia _partesFiltradas para mostrar todo.
  /// 2. Construye un mapa con los filtros y llama al provider de busqueda.
  /// 3. Convierte el resultado JSON a objetos ParteTrabajo.
  Future<void> _aplicarFiltro() async {
    if (!_hayFiltros) {
      setState(() => _partesFiltradas = null);
      return;
    }

    setState(() => _cargandoParte = true);
    try {
      // Provider parametrizado: recibe los filtros y devuelve resultados
      final resultado = await ref.read(
        busquedaPartesProvider({
          'obra':         _obraSeleccionada?.nombre,
          'operario':     _operarioSeleccionado?.nombreCompleto,
          'especialidad': _especialidadFiltro,
        }).future,
      );
      if (mounted) {
        // Mapea los resultados JSON a objetos del modelo
        setState(() => _partesFiltradas =
            resultado.map((e) => ParteTrabajo.fromJson(e)).toList());
      }
    } on Exception catch (e) {
      debugPrint('>>> error buscando partes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar partes')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoParte = false);
    }
  }

  /// Refresca todos los providers: invalida sus datos para forzar recarga.
  /// Invalida partes normales, de jefe, cola offline y fechas permitidas.
  Future<void> _refrescar() async {
    ref.invalidate(partesProvider);
    ref.invalidate(partesJefeProvider);
    ref.invalidate(pendientesOfflineProvider);
    ref.invalidate(listaOfflineProvider);
    ref.invalidate(fechasPermitidasProvider);
  }

  /// Limpia todos los filtros activos y restablece la vista completa.
  void _limpiarBusqueda() {
    _obraCtrl.clear();
    _operarioCtrl.clear();
    setState(() {
      _obraSeleccionada     = null;
      _operarioSeleccionado = null;
      _especialidadFiltro   = null;
      _partesFiltradas      = null;
    });
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // ref.watch(syncProvider): observa el estado de sincronizacion
    ref.watch(syncProvider);
    final pendientesAsync = ref.watch(pendientesOfflineProvider);
    final totalPendientes = pendientesAsync.valueOrNull ?? 0;
    final conexionAsync   = ref.watch(conectividadProvider);
    final perfil          = ref.watch(authProvider).valueOrNull;

    if (perfil == null) {
      return const Scaffold(
        backgroundColor: bgPage,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: bgPage,
        elevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        // Si hay filtro activo por parte concreto, muestra el ID en la barra
        title: _partesFiltradas != null && widget.parteIdInicial != null
            ? Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.indigo),
                  const SizedBox(width: 6),
                  Text(
                    'Parte #${widget.parteIdInicial}',
                    style: const TextStyle(fontSize: 14, color: Colors.indigo),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _limpiarBusqueda,
                    child: const Icon(Icons.close, size: 16, color: Colors.indigo),
                  ),
                ],
              )
            : null,
        actions: [
          // Badge: muestra el numero de partes pendientes de envio offline
          if (totalPendientes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Sincronizar partes pendientes',
                onPressed: () {
                  // Al pulsar, invalida el syncProvider para reintentar el envio
                  ref.invalidate(syncProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Intentando enviar $totalPendientes parte(s)...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Badge(
                  label: Text('$totalPendientes'),
                  backgroundColor: orange,
                  child: const Icon(Icons.cloud_off, color: orange, size: 26),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: textPrimary),
            onPressed: _refrescar,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Partes de Trabajo',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),

          // Buscador: solo visible para roles que no son operarios
          if (!perfil.esOperario) _buildBuscador(),

          // Banner sin conexion: se muestra cuando no hay internet
          // conectividadProvider expone un AsyncValue<bool> con el estado de red
          conexionAsync.when(
            data: (online) => online
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Colors.red.shade100,
                    padding: const EdgeInsets.all(6),
                    child: const Text(
                      'Sin conexion - los partes se guardaran en el movil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),

          Expanded(
            child: _cargandoParte
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refrescar,
                    child: CustomScrollView(
                      slivers: [
                        // Muestra los partes pendientes de envio offline
                        const SliverToBoxAdapter(
                            child: _PartesPendientesOffline()),
                        SliverFillRemaining(
                          child: _partesFiltradas != null
                              // Vista filtrada
                              ? ListaPartes(
                                  partes: _partesFiltradas!,
                                  agruparPorOperario: true,
                                )
                              // Vista segun el rol del usuario
                              : perfil.esJefeObra
                              ? const PartesJefeCombinadaView()
                              : PartesNormalesView(
                                  agruparPorOperario: perfil.esEncargado ||
                                      perfil.esAdmin ||
                                      perfil.esGestion,
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      // FloatingActionButton: boton flotante para crear nuevo parte
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_partes_unique',
        backgroundColor: bgCard,
        foregroundColor: blue,
        elevation: 2,
        onPressed: () => context.push('/partes/nuevo'),
        child: const Icon(Icons.add),
      ),
    );
  }

  // -- Buscador --------------------------------------------------------------

  /// Construye la fila de filtros: obra, operario, especialidad y boton buscar.
  /// Solo visible para roles no operario.
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSelectorObra()),
              const SizedBox(width: 8),
              Expanded(child: _buildSelectorOperario()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // DropdownButtonHideUnderline: oculta la linea inferior del dropdown
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _especialidadFiltro,
                      isDense: true,
                      hint: const Text(
                        'Especialidad',
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Todas')),
                        DropdownMenuItem(
                          value: 'ELECTRICIDAD',
                          child: Text('Electricidad'),
                        ),
                        DropdownMenuItem(
                          value: 'FONTANERIA',
                          child: Text('Fontaneria'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _especialidadFiltro = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _aplicarFiltro,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 16, color: textPrimary),
                      SizedBox(width: 6),
                      Text('Buscar',
                          style: TextStyle(fontSize: 14, color: textPrimary)),
                    ],
                  ),
                ),
              ),
              // Boton de limpiar filtros, solo visible cuando hay filtros activos
              if (_hayFiltros)
                IconButton(
                  icon: const Icon(Icons.clear,
                      size: 18, color: textSecondary),
                  onPressed: _limpiarBusqueda,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Selector obra ---------------------------------------------------------

  /// Selector de obra: al pulsar abre un modal de busqueda de obras.
  /// Muestra el nombre de la obra seleccionada o "Obra" como placeholder.
  Widget _buildSelectorObra() {
    final obras = ref.watch(obrasProvider).valueOrNull ?? [];

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // abrirBuscadorObras: funcion definida en buscador_obras_modal.dart
          // Muestra un modal con lista de obras filtrable por texto
          abrirBuscadorObras(context, obras, (o) {
            setState(() {
              _obraSeleccionada = o;
              _obraCtrl.text    = o.nombre;
            });
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.business_outlined,
                  size: 18, color: textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _obraSeleccionada?.nombre ?? 'Obra',
                  style: TextStyle(
                    fontSize: 14,
                    color: _obraSeleccionada != null
                        ? textPrimary
                        : textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Boton de limpiar, solo visible si hay obra seleccionada
              if (_obraSeleccionada != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _obraSeleccionada = null;
                    _obraCtrl.clear();
                  }),
                  child: const Icon(Icons.clear,
                      size: 16, color: textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Selector operario -----------------------------------------------------

  /// Selector de operario: al pulsar abre un modal de busqueda.
  /// Muestra el nombre completo del operario o "Operario" como placeholder.
  Widget _buildSelectorOperario() {
    final perfiles  = ref.watch(perfilesProvider).valueOrNull ?? [];
    // Filtra solo activos y ordena alfabeticamente
    final operarios = perfiles.where((p) => p.activo).toList()
      ..sort((a, b) =>
          a.nombreApellidoCompleto.compareTo(b.nombreApellidoCompleto));

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _abrirBuscadorOperarios(context, operarios),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _operarioSeleccionado?.nombreApellidoCompleto ?? 'Operario',
                  style: TextStyle(
                    fontSize: 14,
                    color: _operarioSeleccionado != null
                        ? textPrimary
                        : textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_operarioSeleccionado != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _operarioSeleccionado = null;
                    _operarioCtrl.clear();
                  }),
                  child: const Icon(Icons.clear,
                      size: 16, color: textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Abre un modal bottom sheet con la lista de operarios para seleccionar.
  /// DraggableScrollableSheet permite arrastrar para expandir/contraer.
  void _abrirBuscadorOperarios(
      BuildContext context, List<Perfil> perfiles) {
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
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CuerpoBuscadorOperarios(
            perfiles: perfiles,
            scrollController: scrollController,
            alSeleccionar: (p) {
              setState(() {
                _operarioSeleccionado = p;
                _operarioCtrl.text    = p.nombreApellidoCompleto;
              });
            },
          ),
        ),
      ),
    );
  }
}

// -- Widget: seccion de partes pendientes offline -----------------------------

/// Muestra las tarjetas de partes que aun no se han enviado
/// por falta de conexion a internet.
///
/// ConsumerWidget: widget sin estado que lee providers.
/// Se reconstruye cuando el proveedor listaOfflineProvider cambia.
class _PartesPendientesOffline extends ConsumerWidget {
  const _PartesPendientesOffline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(listaOfflineProvider);

    return listaAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (partes) {
        if (partes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 13, color: orange),
                  const SizedBox(width: 6),
                  Text(
                    '${partes.length} parte(s) pendiente(s) de envio',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: orange,
                    ),
                  ),
                ],
              ),
            ),
            // Itera sobre cada parte pendiente y crea una tarjeta
            ...partes.map((p) => _TarjetaParteOffline(data: p)),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

/// Tarjeta que muestra un parte pendiente de envio por falta de conexion.
/// Indica el estado (intentando enviar / pendiente) y permite borrarlo.
///
/// Manejo offline: los partes se guardan en una cola local (SQLite/Hive)
/// y se reenvian automaticamente cuando se recupera la conexion.
class _TarjetaParteOffline extends ConsumerWidget {
  const _TarjetaParteOffline({required this.data});
  final Map<String, dynamic> data;

  /// Borra un parte de la cola offline con confirmacion del usuario.
  Future<void> _borrar(BuildContext context, WidgetRef ref) async {
    // showDialog<bool>: dialogo que devuelve un booleano
    // Navigator.pop(context, true/false) es como se devuelve el valor
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar parte'),
        content: const Text(
          'Seguro que quieres eliminar este parte pendiente? '
          'No se podra recuperar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Obtiene la cola offline y determina el tipo de parte
    final queue      = ref.read(offlineQueueProvider);
    final esJefe     = data['_tipo'] == 'jefe';
    final dataLimpia = Map<String, dynamic>.from(data)..remove('_tipo');

    if (esJefe) {
      await queue.borrarParteJefe(dataLimpia);
    } else {
      await queue.borrarParteNormal(dataLimpia);
    }

    // Invalida los providers para actualizar la UI
    ref.invalidate(pendientesOfflineProvider);
    ref.invalidate(listaOfflineProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fecha       = data['fecha'] as String? ?? '—';
    final horas       = data['horas_normales'];
    final descripcion = (data['descripcion'] as String? ?? '').trim();
    final esPostVenta = data['es_post_venta'] == true;
    final esJefe      = data['_tipo'] == 'jefe';
    // Verifica si hay conexion a internet
    final tieneRed    = ref.watch(conectividadProvider).valueOrNull ?? false;
    final errorSync   = ref.watch(syncErrorProvider);

    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.cloud_off, size: 15, color: orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fecha,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Badge para tipo Post Venta o Jefe Obra
                    if (esPostVenta || esJefe)
                      _Badge(
                        label: esPostVenta ? 'Post Venta' : 'Jefe Obra',
                        color: esPostVenta ? Colors.purple : Colors.teal,
                      ),
                    const Spacer(),
                    Text(
                      '${horas ?? 0} h',
                      style: const TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _borrar(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: Colors.red),
                      ),
                    ),
                  ],
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: textSecondary),
                  ),
                ],
                const SizedBox(height: 4),

                // -- Pie de estado ----------------------------------------
                // Muestra el estado actual del parte pendiente:
                // - Si hay red y no hay error: "Intentando enviar..."
                // - Si no hay red: "Pendiente de envio..."
                // - Si hay error: muestra el mensaje de error en rojo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Spinner cuando se esta intentando enviar
                        if (tieneRed && errorSync == null) ...[
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: orange,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (errorSync == null)
                          Text(
                            tieneRed
                                ? 'Intentando enviar...'
                                : 'Pendiente de envio - se enviara al recuperar conexion',
                            style: const TextStyle(
                              fontSize: 11,
                              color: orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),

                    // Linea de error (solo si hay error de sincronizacion)
                    if (errorSync != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 12, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              errorSync,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pequena etiqueta de color para indicar el tipo de parte
/// (Post Venta o Jefe Obra).
///
/// StatelessWidget: widget sin estado, solo recibe parametros y renderiza.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
