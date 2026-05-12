import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:signature/signature.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';
import '../../providers/perfiles_provider.dart';
import '../../models/perfil.dart';

class CrearParteScreen extends ConsumerWidget {
  const CrearParteScreen({
    super.key,
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  final String? perfilIdPreseleccionado;
  final String? nombrePreseleccionado;
  final DateTime? fechaPreseleccionada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (perfil.esJefeObra) return const _FormularioParteJefe();
    if (perfil.postventa)
      return _FormularioPostVenta(
        perfilIdPreseleccionado: perfilIdPreseleccionado,
        nombrePreseleccionado: nombrePreseleccionado,
        fechaPreseleccionada: fechaPreseleccionada,
      );
    return _FormularioParteNormal(
      perfilIdPreseleccionado: perfilIdPreseleccionado,
      nombrePreseleccionado: nombrePreseleccionado,
      fechaPreseleccionada: fechaPreseleccionada,
    );
  }
}

// ─────────────────────────────────────────────
// Widget reutilizable de firma
// ─────────────────────────────────────────────

class _SeccionFirma extends StatefulWidget {
  final void Function(String? base64, String? nombreFirma) onFirmaChanged;

  const _SeccionFirma({required this.onFirmaChanged});

  @override
  State<_SeccionFirma> createState() => _SeccionFirmaState();
}

class _SeccionFirmaState extends State<_SeccionFirma> {
  late final SignatureController _controller;
  final _nombreCtrl = TextEditingController();
  bool _firmado = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _controller.addListener(() {
      if (_controller.isNotEmpty && !_firmado) {
        setState(() => _firmado = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarFirma() async {
    final bytes = await _controller.toPngBytes();
    if (bytes == null) return;
    final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
    final nombre = _nombreCtrl.text.trim().isEmpty
        ? null
        : _nombreCtrl.text.trim();
    widget.onFirmaChanged(base64Str, nombre);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firma guardada'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _limpiarFirma() {
    _controller.clear();
    _nombreCtrl.clear();
    setState(() => _firmado = false);
    widget.onFirmaChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Firma del cliente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Opcional',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'El cliente puede firmar aquí para confirmar la realización del trabajo',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // ── Nombre del firmante ──────────────────────────────
        TextField(
          controller: _nombreCtrl,
          decoration: InputDecoration(
            hintText: 'Nombre del firmante (opcional)',
            prefixIcon: const Icon(Icons.person_outline, size: 18),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _nombreCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _nombreCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // ── Pad de firma ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: _controller,
              height: 160,
              backgroundColor: Colors.grey.shade50,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Firmar con el dedo en el recuadro',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Limpiar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
                onPressed: _limpiarFirma,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirmar firma'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: _firmado ? _confirmarFirma : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

String _normalizarApellido(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

List<Perfil> _ordenarPerfiles(List<Perfil> perfiles) =>
    [...perfiles.where((p) => p.activo)]..sort(
      (a, b) => _normalizarApellido(
        a.apellidos,
      ).compareTo(_normalizarApellido(b.apellidos)),
    );

// ─────────────────────────────────────────────
// Formulario OPERARIO / ENCARGADO
// ─────────────────────────────────────────────

class _FormularioParteNormal extends ConsumerStatefulWidget {
  const _FormularioParteNormal({
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  final String? perfilIdPreseleccionado;
  final String? nombrePreseleccionado;
  final DateTime? fechaPreseleccionada;

  @override
  ConsumerState<_FormularioParteNormal> createState() =>
      _FormularioParteNormalState();
}

class _FormularioParteNormalState
    extends ConsumerState<_FormularioParteNormal> {
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();
  late DateTime _fecha;
  double _horasNormales = 0;
  String _descripcion = '';
  int? _idObraSeleccionada;
  String? _idPerfilSeleccionado;
  Perfil? _perfilOperarioSeleccionado;
  String? _especialidad;
  bool _enviando = false;
  String? _firmaBase64;
  String? _nombreFirma;

  List<Perfil> _perfilesOrdenados = [];
  List<DateTime> _fechasConParte = [];
  bool _cargandoFechas = false;
  List<DateTime> _fechasPermitidas = [];

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
            final ordenados = _ordenarPerfiles(perfiles);
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
      final fechas = await ref.read(apiServiceProvider).getMisFechasConParte();
      if (mounted) setState(() => _fechasConParte = fechas);
    } catch (e) {
      debugPrint('>>> error cargarMisFechas: $e');
    } finally {
      if (mounted) setState(() => _cargandoFechas = false);
    }
  }

  Future<void> _cargarFechasDeOperario(String id) async {
    setState(() => _cargandoFechas = true);
    try {
      final fechas = await ref.read(apiServiceProvider).getFechasConParte(id);
      if (mounted) setState(() => _fechasConParte = fechas);
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

  bool _fechaEstaPermitida(DateTime dia) => _fechasPermitidas.any(
    (f) => f.year == dia.year && f.month == dia.month && f.day == dia.day,
  );

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
          child: _CuerpoBuscadorOperarios(
            perfiles: _perfilesOrdenados,
            scrollController: scrollController,
            alSeleccionar: (p) {
              setState(() {
                _idPerfilSeleccionado = p.id;
                _perfilOperarioSeleccionado = p;
                _fecha = DateTime.now();
                _fechasConParte = [];
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
                                        _fechasConParte = [];
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
                onChanged: (v) => _horasNormales = double.tryParse(v) ?? 8.0,
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

              // ── Firma del cliente (opcional) ──
              const Divider(),
              const SizedBox(height: 16),
              _SeccionFirma(
                onFirmaChanged: (base64, nombre) => setState(() {
                  _firmaBase64 = base64;
                  _nombreFirma = nombre;
                }),
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

// ─────────────────────────────────────────────
// Formulario POST VENTA
// ─────────────────────────────────────────────

class _FormularioPostVenta extends ConsumerStatefulWidget {
  const _FormularioPostVenta({
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  final String? perfilIdPreseleccionado;
  final String? nombrePreseleccionado;
  final DateTime? fechaPreseleccionada;

  @override
  ConsumerState<_FormularioPostVenta> createState() =>
      _FormularioPostVentaState();
}

class _FormularioPostVentaState extends ConsumerState<_FormularioPostVenta> {
  final _formKey = GlobalKey<FormState>();
  final _obraSearchCtrl = TextEditingController();
  late DateTime _fecha;
  double _horasNormales = 0;
  String _descripcion = '';
  int? _idObraSeleccionada;
  String? _especialidad;
  String? _idPerfilSeleccionado;
  Perfil? _perfilOperarioSeleccionado;
  bool _enviando = false;
  String? _firmaBase64;
  String? _nombreFirma;

  List<Perfil> _perfilesOrdenados = [];
  List<DateTime> _fechasConParte = [];
  bool _cargandoFechas = false;
  List<DateTime> _fechasPermitidas = [];

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
            final ordenados = _ordenarPerfiles(perfiles);
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
      final fechas = await ref.read(apiServiceProvider).getMisFechasConParte();
      if (mounted) setState(() => _fechasConParte = fechas);
    } catch (e) {
      debugPrint('>>> error cargarMisFechas: $e');
    } finally {
      if (mounted) setState(() => _cargandoFechas = false);
    }
  }

  Future<void> _cargarFechasDeOperario(String id) async {
    setState(() => _cargandoFechas = true);
    try {
      final fechas = await ref.read(apiServiceProvider).getFechasConParte(id);
      if (mounted) setState(() => _fechasConParte = fechas);
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

  bool _fechaEstaPermitida(DateTime dia) => _fechasPermitidas.any(
    (f) => f.year == dia.year && f.month == dia.month && f.day == dia.day,
  );

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
      helpText: 'Selecciona un día',
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
          child: _CuerpoBuscadorOperarios(
            perfiles: _perfilesOrdenados,
            scrollController: scrollController,
            alSeleccionar: (p) {
              setState(() {
                _idPerfilSeleccionado = p.id;
                _perfilOperarioSeleccionado = p;
                _fecha = DateTime.now();
                _fechasConParte = [];
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
              // ── Selector de operario ──
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
                                        _fechasConParte = [];
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
                        ? 'Cargando días disponibles...'
                        : widget.fechaPreseleccionada != null
                        ? 'Fecha preseleccionada desde el panel'
                        : _fechasPermitidas.isNotEmpty
                        ? 'Tienes ${_fechasPermitidas.length} día(s) extra habilitados'
                        : 'Los partes son únicamente del dia de hoy',
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

              // ── Especialidad (operario no gestor) ──
              if (!esGestor) ...[
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
                        onTap: () =>
                            setState(() => _especialidad = 'FONTANERIA'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
              ],

              // ── Especialidad (gestor con operario seleccionado) ──
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
                            ? 'Fontanería (del operario)'
                            : 'Sin especialidad asignada',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
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

              // ── Firma del cliente (opcional) ──
              const Divider(),
              const SizedBox(height: 16),
              _SeccionFirma(
                onFirmaChanged: (base64, nombre) => setState(() {
                  _firmaBase64 = base64;
                  _nombreFirma = nombre;
                }),
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

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;
    setState(() => _enviando = true);

    final esGestor = perfil.esAdmin || perfil.esGestion;

    final String? especialidadFinal = esGestor
        ? (_perfilOperarioSeleccionado?.especialidad?.isNotEmpty == true
              ? _perfilOperarioSeleccionado!.especialidad
              : null)
        : _especialidad;

    final data = <String, dynamic>{
      'id_obra': _idObraSeleccionada,
      'id_perfil': esGestor ? _idPerfilSeleccionado : perfil.id,
      'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
      'horas_normales': _horasNormales,
      'descripcion': _descripcion,
      'es_post_venta': true,
      if (especialidadFinal != null) 'especialidad': especialidadFinal,
      if (_firmaBase64 != null) 'firma_base64': _firmaBase64,
      if (_nombreFirma != null) 'nombre_firmado': _nombreFirma,
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

// ─────────────────────────────────────────────
// Formulario JEFE DE OBRA
// ─────────────────────────────────────────────

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

    final data = <String, dynamic>{
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

// ─────────────────────────────────────────────
// Buscador general de obras
// ─────────────────────────────────────────────

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
              (o.nombre ?? '').toLowerCase().contains(_filtro.toLowerCase()) ||
              (o.municipio ?? '').toLowerCase().contains(
                _filtro.toLowerCase(),
              ) ||
              (o.ubicacion ?? '').toLowerCase().contains(_filtro.toLowerCase()),
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
              hintText: 'Nombre, municipio o calle...',
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
                        o.nombre ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          o.ubicacion,
                          o.municipio,
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                      ),
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

// ─────────────────────────────────────────────
// Buscador de operarios
// ─────────────────────────────────────────────

class _CuerpoBuscadorOperarios extends StatefulWidget {
  final List<Perfil> perfiles;
  final Function(Perfil) alSeleccionar;
  final ScrollController scrollController;

  const _CuerpoBuscadorOperarios({
    required this.perfiles,
    required this.alSeleccionar,
    required this.scrollController,
  });

  @override
  State<_CuerpoBuscadorOperarios> createState() =>
      _CuerpoBuscadorOperariosState();
}

class _CuerpoBuscadorOperariosState extends State<_CuerpoBuscadorOperarios> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.perfiles
        .where(
          (p) =>
              p.apellidos.toLowerCase().contains(_filtro.toLowerCase()) ||
              p.nombre.toLowerCase().contains(_filtro.toLowerCase()) ||
              p.email.toLowerCase().contains(_filtro.toLowerCase()),
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
              hintText: 'Buscar por nombre o apellido...',
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
          child: filtrados.isEmpty
              ? const Center(child: Text('No se han encontrado operarios'))
              : ListView.separated(
                  controller: widget.scrollController,
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = filtrados[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Text(
                          p.apellidos.isNotEmpty
                              ? p.apellidos[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        p.nombreApellidoCompleto,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(p.email),
                      onTap: () {
                        widget.alSeleccionar(p);
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

// ─────────────────────────────────────────────
// Botón de especialidad
// ─────────────────────────────────────────────

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
