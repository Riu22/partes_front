import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';
import '../../providers/perfiles_provider.dart';

class CrearParteScreen extends ConsumerWidget {
  const CrearParteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (perfil.esJefeObra) return const _FormularioParteJefe();
    if (perfil.postventa) return const _FormularioPostVenta();
    return const _FormularioParteNormal();
  }
}

// ─────────────────────────────────────────
// Formulario OPERARIO / ENCARGADO
// ─────────────────────────────────────────
class _FormularioParteNormal extends ConsumerStatefulWidget {
  const _FormularioParteNormal();
  @override
  ConsumerState<_FormularioParteNormal> createState() =>
      _FormularioParteNormalState();
}

class _FormularioParteNormalState
    extends ConsumerState<_FormularioParteNormal> {
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  double _horasNormales = 0;
  String _descripcion = '';
  int? _idObraSeleccionada;
  String? _idPerfilSeleccionado;
  bool _enviando = false;

  // PRUEBAS: límite 2 semanas comentado, actualmente solo se permite el mismo día
  // final DateTime _fechaMinima = DateTime.now().subtract(const Duration(days: 14));

  @override
  void dispose() {
    _obraSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasActivasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
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
              // ── Selector de operario (solo admin/gestión) ──
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
                  onTap: () => _abrirBuscadorGeneral(context, obras, (o) {
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

              // ── Fecha — solo lectura ──
              // PRUEBAS: fecha fija a hoy, antes tenía date picker con límite 2 semanas
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.calendar_today, color: Colors.grey),
                title: Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                // PRUEBAS: date picker comentado, antes permitía elegir fecha hasta _fechaMinima
                // onTap: _pickDate,
              ),
              const SizedBox(height: 25),

              // ── Horas ──
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
                onChanged: (v) => _horasNormales = double.tryParse(v) ?? 8.0,
              ),
              const SizedBox(height: 25),

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

  // PRUEBAS: _pickDate comentado, antes permitía elegir fecha con límite 2 semanas
  // void _pickDate() async {
  //   final picked = await showDatePicker(
  //     context: context,
  //     initialDate: _fecha,
  //     firstDate: _fechaMinima,
  //     lastDate: DateTime.now(),
  //   );
  //   if (picked != null) setState(() => _fecha = picked);
  // }

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;
    setState(() => _enviando = true);

    final esGestor = perfil.esAdmin || perfil.esGestion;

    final data = {
      'id_obra': _idObraSeleccionada,
      'id_perfil': esGestor ? _idPerfilSeleccionado : perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales': _horasNormales,
      'descripcion': _descripcion,
      if (perfil.especialidad.isNotEmpty) 'especialidad': perfil.especialidad,
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
          context.go('/partes');
        }
        return;
      }

      await ref.read(apiServiceProvider).crearParte(data);
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        context.go('/partes');
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
        context.go('/partes');
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

// ─────────────────────────────────────────
// Formulario POST VENTA
// ─────────────────────────────────────────
class _FormularioPostVenta extends ConsumerStatefulWidget {
  const _FormularioPostVenta();
  @override
  ConsumerState<_FormularioPostVenta> createState() =>
      _FormularioPostVentaState();
}

class _FormularioPostVentaState extends ConsumerState<_FormularioPostVenta> {
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  double _horasNormales = 0;
  String _descripcion = '';
  int? _idObraSeleccionada;
  String? _especialidad;
  String? _idPerfilSeleccionado;
  bool _enviando = false;

  // PRUEBAS: límite 2 semanas comentado, actualmente solo se permite el mismo día
  // final DateTime _fechaMinima = DateTime.now().subtract(const Duration(days: 14));

  @override
  void dispose() {
    _obraSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte Post Venta'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
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
              // ── Selector de operario (solo admin/gestión) ──
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
                  onTap: () => _abrirBuscadorGeneral(context, obras, (o) {
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

              // ── Fecha — solo lectura ──
              // PRUEBAS: fecha fija a hoy, antes tenía date picker con límite 2 semanas
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.calendar_today, color: Colors.grey),
                title: Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                // PRUEBAS: date picker comentado, antes permitía elegir fecha hasta _fechaMinima
                // onTap: _pickDate,
              ),
              const SizedBox(height: 25),

              // ── Horas ──
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
                onChanged: (v) => _horasNormales = double.tryParse(v) ?? 8.0,
              ),
              const SizedBox(height: 25),

              // ── Especialidad ──
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
                      onTap: () => setState(() => _especialidad = 'FONTANERIA'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

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

  // PRUEBAS: _pickDate comentado, antes permitía elegir fecha con límite 2 semanas
  // void _pickDate() async {
  //   final picked = await showDatePicker(
  //     context: context,
  //     initialDate: _fecha,
  //     firstDate: _fechaMinima,
  //     lastDate: DateTime.now(),
  //   );
  //   if (picked != null) setState(() => _fecha = picked);
  // }

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;
    setState(() => _enviando = true);

    final esGestor = perfil.esAdmin || perfil.esGestion;

    final data = {
      'id_obra': _idObraSeleccionada,
      'id_perfil': esGestor ? _idPerfilSeleccionado : perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales': _horasNormales,
      'especialidad': _especialidad,
      'descripcion': _descripcion,
      'es_post_venta': true,
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
          context.go('/partes');
        }
        return;
      }

      await ref.read(apiServiceProvider).crearParte(data);
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parte post venta enviado correctamente'),
          ),
        );
        context.go('/partes');
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
        context.go('/partes');
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

// ─────────────────────────────────────────
// Formulario JEFE DE OBRA
// ─────────────────────────────────────────
class _FormularioParteJefe extends ConsumerStatefulWidget {
  const _FormularioParteJefe();
  @override
  ConsumerState<_FormularioParteJefe> createState() =>
      _FormularioParteJefeState();
}

class _FormularioParteJefeState extends ConsumerState<_FormularioParteJefe> {
  final _formKey = GlobalKey<FormState>();
  String _descripcion = '';
  bool _enviando = false;
  final List<Map<String, dynamic>> _lineas = [];

  double get _totalPorcentaje => _lineas.fold(
    0.0,
    (sum, l) => sum + ((l['porcentaje'] as double?) ?? 0.0),
  );

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final double total = _totalPorcentaje;
    final bool totalValido = (total - 100.0).abs() < 0.01;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parte Jefe de Obra'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
              _buildInfoFecha(),
              const SizedBox(height: 25),
              _buildHeaderPorcentajes(total, totalValido),
              const SizedBox(height: 12),
              ..._lineas.asMap().entries.map(
                (e) => _buildCardLinea(e.key, e.value),
              ),
              obrasAsync.when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (obras) {
                  final obraIds = _lineas.map((l) => l['obra_id']).toSet();
                  final disponibles = obras
                      .where((o) => !obraIds.contains(o.id))
                      .toList();
                  if (disponibles.isEmpty) return const SizedBox();
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                    ),
                    onPressed: () =>
                        _abrirBuscadorGeneral(context, disponibles, (o) {
                          setState(
                            () => _lineas.add({
                              'obra_id': o.id,
                              'obra_nombre': o.nombre,
                              'porcentaje': 0.0,
                            }),
                          );
                        }),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar y añadir obra'),
                  );
                },
              ),
              const SizedBox(height: 25),
              const Text(
                'Descripción general',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                onChanged: (v) => _descripcion = v,
              ),
              const SizedBox(height: 30),
              if (!totalValido && _lineas.isNotEmpty)
                _buildWarningPorcentaje(total),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_enviando || !totalValido || _lineas.isEmpty)
                      ? null
                      : _enviarParte,
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

  Widget _buildInfoFecha() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.teal.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.teal.withOpacity(0.2)),
    ),
    child: Text(
      'Fecha del parte: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
    ),
  );

  Widget _buildHeaderPorcentajes(double total, bool totalValido) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'Distribución',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(
        'Total: ${total.toStringAsFixed(0)}%',
        style: TextStyle(
          color: totalValido ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    ],
  );

  Widget _buildCardLinea(int i, Map<String, dynamic> linea) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      title: Text(
        linea['obra_nombre'] ?? '',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            child: TextFormField(
              initialValue: '0',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(suffixText: '%'),
              onChanged: (v) => setState(
                () => _lineas[i]['porcentaje'] = double.tryParse(v) ?? 0.0,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => setState(() => _lineas.removeAt(i)),
          ),
        ],
      ),
    ),
  );

  Widget _buildWarningPorcentaje(double total) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      '⚠️ La suma debe ser 100% (actual: ${total.toStringAsFixed(0)}%)',
      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
    ),
  );

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final data = {
      'descripcion': _descripcion,
      'obras': _lineas
          .map((l) => {'id_obra': l['obra_id'], 'porcentaje': l['porcentaje']})
          .toList(),
    };

    try {
      final resultado = await Connectivity().checkConnectivity();
      final hayRed = resultado.any((r) => r != ConnectivityResult.none);

      if (!hayRed) {
        await ref.read(offlineQueueProvider).guardarParteJefeOffline(data);
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
          context.go('/partes');
        }
        return;
      }

      await ref.read(apiServiceProvider).crearParteJefe(data);
      ref.invalidate(partesJefeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        context.go('/partes');
      }
    } on DioException catch (_) {
      await ref.read(offlineQueueProvider).guardarParteJefeOffline(data);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión — parte guardado localmente'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/partes');
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

// ─────────────────────────────────────────
// BUSCADOR GENERAL
// ─────────────────────────────────────────
void _abrirBuscadorGeneral(
  BuildContext context,
  List obras,
  Function(dynamic) alSeleccionar,
) {
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
        child: _CuerpoBuscador(
          obras: obras,
          alSeleccionar: alSeleccionar,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class _CuerpoBuscador extends StatefulWidget {
  final List obras;
  final Function(dynamic) alSeleccionar;
  final ScrollController scrollController;
  const _CuerpoBuscador({
    required this.obras,
    required this.alSeleccionar,
    required this.scrollController,
  });
  @override
  State<_CuerpoBuscador> createState() => _CuerpoBuscadorState();
}

class _CuerpoBuscadorState extends State<_CuerpoBuscador> {
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
              ? const Center(child: Text('No se han encontrado obras'))
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
                        widget.alSeleccionar(o);
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
// BOTÓN ESPECIALIDAD
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
