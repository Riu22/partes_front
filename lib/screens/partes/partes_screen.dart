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
import '../../helpers/tema_constants.dart';
import '../../widgets/buscador_obras_modal.dart';
import '../../widgets/buscador_operarios_modal.dart';
import '../../models/obra.dart';
import '../../models/perfil.dart';
import '../../widgets/lista_partes.dart';
import '../../widgets/partes_views.dart';

class PartesScreen extends ConsumerStatefulWidget {
  const PartesScreen({super.key});

  @override
  ConsumerState<PartesScreen> createState() => _PartesScreenState();
}

class _PartesScreenState extends ConsumerState<PartesScreen> {
  final _obraCtrl = TextEditingController();
  final _operarioCtrl = TextEditingController();
  Obra? _obraSeleccionada;
  Perfil? _operarioSeleccionado;
  String? _especialidadFiltro;
  List<ParteTrabajo>? _partesFiltradas;
  final _updateService = UpdateService();

  bool get _hayFiltros =>
      _obraSeleccionada != null ||
      _operarioSeleccionado != null ||
      _especialidadFiltro != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final conectado = ref.read(conectividadProvider).valueOrNull ?? false;
      if (conectado) {
        ref.invalidate(obrasActivasProvider);
        ref.invalidate(obrasProvider);
        // Precarga fechas permitidas para que el formulario las tenga listas
        ref.invalidate(fechasPermitidasProvider);
        try {
          await ref.read(apiServiceProvider).getMisFechasLibres();
        } catch (e) {
          debugPrint('>>> error precarga fechas permitidas: $e');
        }
      }
      if (!kIsWeb) _checkUpdate();
    });
  }

  Future<void> _checkUpdate() async {
    final update = await _updateService.hayActualizacion();
    if (update != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Nueva version disponible'),
          content: Text(
            'Hay una actualizacion a la versión ${update['version']}.\n\n'
            'Descargala para tener las ultimas mejoras.\n\n'
            'Una vez descargado dale a abrir y selecciona actualizar.\n\n'
            'En caso de que de un error desinstale la aplicacion y vuelva a instalarla con el instalador que acaba de descargar.',
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

  void _aplicarFiltro() {
    if (!_hayFiltros) {
      setState(() => _partesFiltradas = null);
      return;
    }
    final partes = ref.read(partesProvider).valueOrNull ?? [];
    final filtradas = partes.where((p) {
      if (_obraSeleccionada != null && p.obraNombre != _obraSeleccionada!.nombre) {
        return false;
      }
      if (_operarioSeleccionado != null &&
          p.operarioNombreCompleto != _operarioSeleccionado!.nombreApellidoCompleto) {
        return false;
      }
      if (_especialidadFiltro != null && p.especialidad != _especialidadFiltro) {
        return false;
      }
      return true;
    }).toList();
    setState(() => _partesFiltradas = filtradas);
  }

  Future<void> _refrescar() async {
    ref.invalidate(partesProvider);
    ref.invalidate(partesJefeProvider);
    ref.invalidate(pendientesOfflineProvider);
    ref.invalidate(listaOfflineProvider); // también refresca la lista visual
    ref.invalidate(fechasPermitidasProvider);
  }

  void _limpiarBusqueda() {
    _obraCtrl.clear();
    _operarioCtrl.clear();
    setState(() {
      _obraSeleccionada = null;
      _operarioSeleccionado = null;
      _especialidadFiltro = null;
      _partesFiltradas = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncProvider);
    final pendientesAsync = ref.watch(pendientesOfflineProvider);
    final totalPendientes = pendientesAsync.valueOrNull ?? 0;
    final conexionAsync = ref.watch(conectividadProvider);
    final perfil = ref.watch(authProvider).valueOrNull;

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
        actions: [
          if (totalPendientes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Sincronizar partes pendientes',
                onPressed: () {
                  ref.invalidate(syncProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Intentando enviar $totalPendientes parte(s)...',
                      ),
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

          if (!perfil.esOperario) _buildBuscador(),

          // Banner sin conexión
          conexionAsync.when(
            data: (online) => online
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Colors.red.shade100,
                    padding: const EdgeInsets.all(6),
                    child: const Text(
                      'Sin conexión — los partes se guardarán en el móvil',
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
            child: RefreshIndicator(
              onRefresh: _refrescar,
              child: CustomScrollView(
                slivers: [
                  // ── Partes guardados offline ──────────────────────────────
                  const SliverToBoxAdapter(child: _PartesPendientesOffline()),
                  // ── Lista principal ───────────────────────────────────────
                  SliverFillRemaining(
                    child: _partesFiltradas != null
                        ? ListaPartes(
                            partes: _partesFiltradas!,
                            agruparPorOperario: true,
                          )
                        : perfil.esJefeObra
                        ? const PartesJefeCombinadaView()
                        : PartesNormalesView(
                            agruparPorOperario:
                                perfil.esEncargado ||
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_partes_unique',
        backgroundColor: bgCard,
        foregroundColor: blue,
        elevation: 2,
        onPressed: () => context.go('/partes/nuevo'),
        child: const Icon(Icons.add),
      ),
    );
  }

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
                          child: Text('Fontanería'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _especialidadFiltro = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _aplicarFiltro,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 16, color: textPrimary),
                      SizedBox(width: 6),
                      Text(
                        'Buscar',
                        style: TextStyle(
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_hayFiltros)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: textSecondary),
                  onPressed: _limpiarBusqueda,
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Obra> _obrasDesdePartes(List<ParteTrabajo> partes) {
    final nombres = partes.map((p) => p.obraNombre).toSet().toList()..sort();
    return nombres
        .map((n) => Obra(
              id: 0,
              nombre: n,
              ubicacion: '',
              municipio: '',
              codigo: '',
              activa: true,
            ))
        .toList();
  }

  Widget _buildSelectorObra() {
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final partes = ref.read(partesProvider).valueOrNull ?? [];
          final obras = _obrasDesdePartes(partes);
          abrirBuscadorObras(context, obras, (o) {
            setState(() {
              _obraSeleccionada = o;
              _obraCtrl.text = o.nombre;
            });
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.business_outlined, size: 18, color: textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _obraSeleccionada?.nombre ?? 'Obra',
                  style: TextStyle(
                    fontSize: 14,
                    color: _obraSeleccionada != null ? textPrimary : textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_obraSeleccionada != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _obraSeleccionada = null;
                    _obraCtrl.clear();
                  }),
                  child: const Icon(Icons.clear, size: 16, color: textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Perfil> _operariosDesdePartes(List<ParteTrabajo> partes) {
    final map = <String, Perfil>{};
    for (final p in partes) {
      final key = p.operarioId ?? p.operarioNombreCompleto;
      map.putIfAbsent(key, () => Perfil(
            id: p.operarioId ?? key,
            email: '',
            nombre: p.operarioNombre,
            apellidos: p.operarioApellidos,
            rol: 'OPERARIO',
            activo: true,
          ));
    }
    final sorted = map.values.toList();
    sorted.sort((a, b) => a.nombreApellidoCompleto.compareTo(b.nombreApellidoCompleto));
    return sorted;
  }

  Widget _buildSelectorOperario() {
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final partes = ref.read(partesProvider).valueOrNull ?? [];
          final perfiles = _operariosDesdePartes(partes);
          _abrirBuscadorOperarios(context, perfiles);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _operarioSeleccionado?.nombreApellidoCompleto ?? 'Operario',
                  style: TextStyle(
                    fontSize: 14,
                    color: _operarioSeleccionado != null ? textPrimary : textSecondary,
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
                  child: const Icon(Icons.clear, size: 16, color: textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirBuscadorOperarios(BuildContext context, List<Perfil> perfiles) {
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
            perfiles: perfiles,
            scrollController: scrollController,
            alSeleccionar: (p) {
              setState(() {
                _operarioSeleccionado = p;
                _operarioCtrl.text = p.nombreApellidoCompleto;
              });
            },
          ),
        ),
      ),
    );
  }
}

// ── Widget: sección de partes pendientes offline ─────────────────────────────

class _PartesPendientesOffline extends ConsumerWidget {
  const _PartesPendientesOffline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(listaOfflineProvider);

    return listaAsync.when(
      // Mientras carga no ocupa espacio
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (partes) {
        if (partes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de sección
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 13, color: orange),
                  const SizedBox(width: 6),
                  Text(
                    '${partes.length} parte(s) pendiente(s) de envío',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: orange,
                    ),
                  ),
                ],
              ),
            ),
            // Tarjetas
            ...partes.map((p) => _TarjetaParteOffline(data: p)),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _TarjetaParteOffline extends ConsumerWidget {
  const _TarjetaParteOffline({required this.data});
  final Map<String, dynamic> data;

  Future<void> _borrar(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar parte'),
        content: const Text(
          '¿Seguro que quieres eliminar este parte pendiente? No se podrá recuperar.',
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

    final queue = ref.read(offlineQueueProvider);
    final esJefe = data['_tipo'] == 'jefe';

    // Copia limpia sin la clave interna _tipo
    final dataLimpia = Map<String, dynamic>.from(data)..remove('_tipo');

    if (esJefe) {
      await queue.borrarParteJefe(dataLimpia);
    } else {
      await queue.borrarParteNormal(dataLimpia);
    }

    ref.invalidate(pendientesOfflineProvider);
    ref.invalidate(listaOfflineProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fecha = data['fecha'] as String? ?? '—';
    final horas = data['horas_normales'];
    final descripcion = (data['descripcion'] as String? ?? '').trim();
    final esPostVenta = data['es_post_venta'] == true;
    final esJefe = data['_tipo'] == 'jefe';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
                    // ── Botón eliminar ──
                    GestureDetector(
                      onTap: () => _borrar(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red,
                        ),
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
                    style: const TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'Pendiente de envío — se enviará al recuperar conexión',
                  style: TextStyle(
                    fontSize: 11,
                    color: orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

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
