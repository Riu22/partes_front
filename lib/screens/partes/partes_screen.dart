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
import '../../widgets/search_field.dart';
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
  String? _especialidadFiltro;
  bool _buscando = false;
  List<dynamic>? _resultadosBusqueda;
  final _updateService = UpdateService();

  bool get _hayFiltros =>
      _obraCtrl.text.isNotEmpty ||
      _operarioCtrl.text.isNotEmpty ||
      _especialidadFiltro != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final conectado = ref.read(conectividadProvider).valueOrNull ?? false;
      if (conectado) {
        ref.invalidate(obrasActivasProvider);
        ref.invalidate(obrasProvider);
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

  Future<void> _buscar() async {
    if (!_hayFiltros) {
      setState(() => _resultadosBusqueda = null);
      return;
    }
    setState(() => _buscando = true);
    try {
      final r = await ref
          .read(apiServiceProvider)
          .buscarPartes(
            obra: _obraCtrl.text,
            operario: _operarioCtrl.text,
            especialidad: _especialidadFiltro,
          );
      setState(() => _resultadosBusqueda = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _refrescar() async {
    ref.invalidate(partesProvider);
    ref.invalidate(partesJefeProvider);
    ref.invalidate(pendientesOfflineProvider);
    ref.invalidate(fechasPermitidasProvider);
  }

  void _limpiarBusqueda() {
    _obraCtrl.clear();
    _operarioCtrl.clear();
    setState(() {
      _especialidadFiltro = null;
      _resultadosBusqueda = null;
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
              child: _resultadosBusqueda != null
                  ? ListaPartes(
                      partes: _resultadosBusqueda!
                          .map((p) => ParteTrabajo.fromJson(p))
                          .toList(),
                      agruparPorOperario: true,
                    )
                  : perfil.esJefeObra
                  ? const PartesJefeCombinadaView() // ← fix: combinada en vez de solo jefe
                  : PartesNormalesView(
                      agruparPorOperario:
                          perfil.esEncargado ||
                          perfil.esAdmin ||
                          perfil.esGestion,
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
              Expanded(
                child: SearchField(
                  controller: _obraCtrl,
                  hint: 'Obra',
                  icon: Icons.business_outlined,
                  onSubmit: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SearchField(
                  controller: _operarioCtrl,
                  hint: 'Operario',
                  icon: Icons.person_outline,
                  onSubmit: (_) => _buscar(),
                ),
              ),
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
                onTap: _buscando ? null : _buscar,
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
                  child: _buscando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: blue,
                          ),
                        )
                      : const Row(
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
}
