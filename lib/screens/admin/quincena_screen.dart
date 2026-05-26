import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../helpers/capture_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';

class QuincenaScreen extends ConsumerStatefulWidget {
  const QuincenaScreen({super.key});

  @override
  ConsumerState<QuincenaScreen> createState() => _QuincenaScreenState();
}

class _QuincenaScreenState extends ConsumerState<QuincenaScreen> {
  final ApiService _apiService = ApiService();

  final ScrollController _verticalController   = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  DateTimeRange? _rangoSeleccionado;
  bool _cargando      = false;
  bool _exportandoPdf = false;
  List<dynamic> _datosPrevia = [];

  List<String> _operariosDisponibles = [];
  Set<String>  _operariosSeleccionados = {};
  List<String> _obrasDisponibles = [];
  Set<String>  _obrasSeleccionadas = {};

  // ── Festivos nacionales fijos ─────────────────────────────────────
  static const Set<(int, int)> _festivosFijos = {
    (1,  1), (1,  6), (5,  1), (8, 15),
    (10,12), (11, 1), (12, 6), (12, 8), (12,25),
  };

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  bool get _esJefeObra =>
      ref.read(authProvider).valueOrNull?.esJefeObra == true;

  // ── Helpers ───────────────────────────────────────────────────────

  String _letraDia(DateTime d) {
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return letras[d.weekday - 1];
  }

  bool _esFinDeSemana(DateTime d) => d.weekday >= 6;

  bool _esFestivo(DateTime d) => _festivosFijos.contains((d.month, d.day));

  bool _esDiaRojo(DateTime d) => _esFinDeSemana(d) || _esFestivo(d);

  ({Color bg, Color fg, String letra})? _infoAusencia(
    Map<String, dynamic> fila,
    String isoFecha,
  ) {
    final ausencias =
        fila['ausencias_por_dia'] as Map<String, dynamic>? ?? {};
    final tipo = ausencias[isoFecha]?.toString();
    if (tipo == null) return null;
    if (tipo == 'BAJA') {
      return (bg: Colors.red.shade100, fg: Colors.red.shade800, letra: 'B');
    }
    return (
      bg: Colors.amber.shade100,
      fg: Colors.amber.shade800,
      letra: 'V',
    );
  }

  // ── Celda de horas ────────────────────────────────────────────────

  static double _extractHoras(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    if (raw is Map) return ((raw['horas'] as num?) ?? 0).toDouble();
    return 0;
  }

  static int? _extractParteId(dynamic raw) {
    if (raw is Map) return raw['parte_id'] as int?;
    return null;
  }

  DataCell _celdaH(
    dynamic raw,
    String isoFecha,
    Map<String, dynamic> fila,
    bool esDiaRojo,
    BuildContext context,
  ) {
    final aus      = _infoAusencia(fila, isoFecha);
    final double v = _extractHoras(raw);
    final int? parteId = _extractParteId(raw);

    if (aus != null) {
      return DataCell(
        Container(
          width: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aus.bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            aus.letra,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: aus.fg,
            ),
          ),
        ),
      );
    }

    // ── Día rojo (finde o festivo) ───────────────────────────────────
    if (esDiaRojo) {
      if (parteId != null && v > 0) {
        return DataCell(
          Tooltip(
            message: 'Ver parte #$parteId',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => context.push('/partes/$parteId'),
              child: Container(
                width: 35,
                height: double.infinity,
                alignment: Alignment.center,
                color: Colors.red.shade50,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      v.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(width: 1),
                    Icon(Icons.open_in_new_rounded,
                        size: 8, color: Colors.red.shade700),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return DataCell(
        Container(
          width: 35,
          height: double.infinity,
          alignment: Alignment.center,
          color: Colors.red.shade50,
          child: v > 0
              ? Text(
                  v.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700),
                )
              : Text('-',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade200)),
        ),
      );
    }

    // ── Día normal con parte ─────────────────────────────────────────
    if (parteId != null && v > 0) {
      return DataCell(
        Tooltip(
          message: 'Ver parte #$parteId',
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => context.push('/partes/$parteId'),
            child: Container(
              width: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.07),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    v.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 1),
                  const Icon(Icons.open_in_new_rounded,
                      size: 8, color: Colors.indigo),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Día normal sin parte ─────────────────────────────────────────
    return DataCell(
      Container(
        width: 35,
        alignment: Alignment.center,
        child: Text(
          v > 0 ? v.toStringAsFixed(1) : '-',
          style: TextStyle(
            fontSize: 11,
            color: v > 0 ? Colors.black87 : Colors.grey[600],
            fontWeight: v > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Fechas ────────────────────────────────────────────────────────

  Future<void> _seleccionarFechas(BuildContext context) async {
    final DateTimeRange? nuevoRango = await showDateRangePicker(
      context: context,
      initialDateRange: _rangoSeleccionado ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'SELECCIONE EL PERIODO',
    );
    if (nuevoRango != null) {
      setState(() {
        _rangoSeleccionado = nuevoRango;
        _resetDatos();
      });
      _cargarVistaPrevia();
    }
  }

  void _resetDatos() {
    _datosPrevia             = [];
    _operariosDisponibles    = [];
    _operariosSeleccionados  = {};
    _obrasDisponibles        = [];
    _obrasSeleccionadas      = {};
  }

  // ── Carga ─────────────────────────────────────────────────────────

  Future<void> _cargarVistaPrevia() async {
    if (_rangoSeleccionado == null) return;
    setState(() => _cargando = true);
    try {
      final data = _esJefeObra
          ? await _apiService.getContabilidadDetalleJsonJefe(
              _rangoSeleccionado!.start,
              _rangoSeleccionado!.end,
            )
          : await _apiService.getContabilidadDetalleJson(
              _rangoSeleccionado!.start,
              _rangoSeleccionado!.end,
            );

      if (_esJefeObra) {
        final obras = data
            .map((f) => f['obra']?.toString() ?? '')
            .where((o) => o.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _datosPrevia        = data;
          _obrasDisponibles   = obras;
          _obrasSeleccionadas = obras.toSet();
        });
      } else {
        final operarios = data
            .map((f) => f['operario']?.toString() ?? '')
            .where((o) => o.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _datosPrevia            = data;
          _operariosDisponibles   = operarios;
          _operariosSeleccionados = operarios.toSet();
        });
      }
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  // ── CSV ───────────────────────────────────────────────────────────

  Future<void> _ejecutarDescarga() async {
    if (_rangoSeleccionado == null) return;
    setState(() => _cargando = true);
    try {
      if (_esJefeObra) {
        await _apiService.exportarContabilidadDetalleCsvJefe(
          _rangoSeleccionado!.start,
          _rangoSeleccionado!.end,
        );
      } else {
        await _apiService.exportarContabilidadDetalleCsv(
          _rangoSeleccionado!.start,
          _rangoSeleccionado!.end,
        );
      }
    } catch (e) {
      _mostrarError('Error en la descarga: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  // ── PDF ───────────────────────────────────────────────────────────

  Future<void> _exportarPdf() async {
    if (_rangoSeleccionado == null || _datosPrevia.isEmpty) return;
    setState(() => _exportandoPdf = true);
    try {
      final List<DateTime> dias = [];
      DateTime temp = _rangoSeleccionado!.start;
      while (!temp.isAfter(_rangoSeleccionado!.end)) {
        dias.add(temp);
        temp = temp.add(const Duration(days: 1));
      }

      final datosFiltrados = _esJefeObra
          ? _datosPrevia
              .where((f) =>
                  _obrasSeleccionadas.contains(f['obra']?.toString() ?? ''))
              .toList()
          : _datosPrevia
              .where((f) => _operariosSeleccionados
                  .contains(f['operario']?.toString() ?? ''))
              .toList();

      if (datosFiltrados.isEmpty) {
        _mostrarError('No hay datos para exportar');
        return;
      }

      final List<String> columnas = [
        'Codigo',
        'Operario',
        'Categoria',
        'Obra',
        ...dias.map((d) => '${_letraDia(d)}\n${d.day}/${d.month}'),
        'Total',
      ];

      final List<List<String>> filas           = [];
      final Set<int>           indicesSubtotal = {};

      String _horaStr(dynamic raw) {
        final v = _extractHoras(raw);
        return v > 0 ? v.toStringAsFixed(1) : '-';
      }

      void _procesarFilas(List<dynamic> grupo, String agrupador) {
        final Map<String, List<dynamic>> porGrupo = {};
        for (final f in grupo) {
          porGrupo
              .putIfAbsent(f[agrupador]?.toString() ?? '', () => [])
              .add(f);
        }
        final claves =
            (_esJefeObra ? _obrasDisponibles : _operariosDisponibles)
                .where((k) => porGrupo.containsKey(k))
                .toList();

        for (final clave in claves) {
          final fg = porGrupo[clave]!;
          for (final f in fg) {
            final hpd = f['horas_por_dia'] as Map<String, dynamic>;
            final aus =
                f['ausencias_por_dia'] as Map<String, dynamic>? ?? {};
            filas.add([
              f['codigo']?.toString() ?? '',
              f['operario'] ?? '',
              f['categoria_profesional'] ?? '-',
              f['obra'] ?? '',
              ...dias.map((d) {
                final iso = DateFormat('yyyy-MM-dd').format(d);
                if (aus[iso] == 'BAJA') return 'B';
                if (aus[iso] == 'VACACIONES') return 'V';
                return _horaStr(hpd[iso]);
              }),
              (f['total_horas'] as num).toStringAsFixed(1),
            ]);
          }
          final Map<String, double> totDia = {};
          double totGen = 0;
          for (final f in fg) {
            final hpd = f['horas_por_dia'] as Map<String, dynamic>;
            for (final d in dias) {
              final iso = DateFormat('yyyy-MM-dd').format(d);
              final v   = _extractHoras(hpd[iso]);
              if (v > 0) {
                totDia[iso] = (totDia[iso] ?? 0) + v;
                totGen += v;
              }
            }
          }
          indicesSubtotal.add(filas.length);
          filas.add([
            '',
            _esJefeObra ? '' : 'Total $clave',
            '',
            _esJefeObra ? 'Total $clave' : '',
            ...dias.map((d) {
              final iso = DateFormat('yyyy-MM-dd').format(d);
              final t   = totDia[iso] ?? 0;
              return t > 0 ? t.toStringAsFixed(1) : '-';
            }),
            totGen.toStringAsFixed(1),
          ]);
        }
      }

      _procesarFilas(datosFiltrados, _esJefeObra ? 'obra' : 'operario');

      await generarYMostrarPdf(
        columnas: columnas,
        filas: filas,
        subtotales: indicesSubtotal,
        titulo:
            '${_esJefeObra ? 'Mis obras' : 'Exportacion Contable'} — ${_labelRango()}',
      );
    } catch (e) {
      _mostrarError('Error al generar PDF: $e');
    } finally {
      setState(() => _exportandoPdf = false);
    }
  }

  // ── Utilidades ────────────────────────────────────────────────────

  String _labelRango() {
    if (_rangoSeleccionado == null) return '';
    return '${DateFormat('dd/MM/yy').format(_rangoSeleccionado!.start)} '
        '- ${DateFormat('dd/MM/yy').format(_rangoSeleccionado!.end)}';
  }

  void _mostrarError(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msj), backgroundColor: Colors.red));
  }

  void _mostrarFiltroOperarios() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _FiltroBottomSheet(
          titulo: 'Filtrar operarios',
          icono: Icons.people,
          disponibles: _operariosDisponibles,
          seleccionados: _operariosSeleccionados,
          onChanged: (v) => setState(() => _operariosSeleccionados = v),
        ),
      );

  void _mostrarFiltroObras() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _FiltroBottomSheet(
          titulo: 'Filtrar obras',
          icono: Icons.business,
          disponibles: _obrasDisponibles,
          seleccionados: _obrasSeleccionadas,
          onChanged: (v) => setState(() => _obrasSeleccionadas = v),
        ),
      );

  // ─────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(authProvider).valueOrNull;
    final esJefe = perfil?.esJefeObra == true;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(esJefe ? 'Mis obras' : 'Exportación Contable'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSelectorHeader(esJefe),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _datosPrevia.isEmpty
                    ? _buildEmptyState()
                    : _buildTablaDetalle(esJefe),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildSelectorHeader(bool esJefe) {
    final hayDatos      = _datosPrevia.isNotEmpty;
    final seleccionados = esJefe
        ? _obrasSeleccionadas.length
        : _operariosSeleccionados.length;
    final total = esJefe
        ? _obrasDisponibles.length
        : _operariosDisponibles.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          _buildBotonesQuincena(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _seleccionarFechas(context),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _rangoSeleccionado == null
                        ? 'Seleccionar Rango'
                        : _labelRango(),
                  ),
                ),
              ),
              if (hayDatos) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _cargando ? null : _ejecutarDescarga,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('CSV'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (_exportandoPdf || _cargando) ? null : _exportarPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: _exportandoPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
              ],
            ],
          ),
          if (hayDatos) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _LeyendaCelda(
                    color: Colors.red.shade100, letra: 'B', label: 'Baja'),
                const SizedBox(width: 12),
                _LeyendaCelda(
                    color: Colors.amber.shade100,
                    letra: 'V',
                    label: 'Vacaciones'),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(Icons.open_in_new_rounded,
                          size: 10, color: Colors.indigo),
                    ),
                    const SizedBox(width: 4),
                    const Text('Abrir parte',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    esJefe ? _mostrarFiltroObras : _mostrarFiltroOperarios,
                icon: Icon(
                  esJefe
                      ? Icons.business_outlined
                      : Icons.people_outline,
                  color: Colors.indigo,
                ),
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(esJefe ? 'Obras' : 'Operarios'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: seleccionados == total
                            ? Colors.indigo
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$seleccionados / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Chips de quincena ─────────────────────────────────────────────

  Widget _buildBotonesQuincena() {
    final ahora = DateTime.now();
    final quincenas = [
      _Quincena(
        label: '1a Q mes actual',
        inicio: DateTime(ahora.year, ahora.month, 1),
        fin: DateTime(ahora.year, ahora.month, 15),
      ),
      _Quincena(
        label: '2a Q mes actual',
        inicio: DateTime(ahora.year, ahora.month, 16),
        fin: DateTime(ahora.year, ahora.month + 1, 0),
      ),
      _Quincena(
        label: '1a Q mes ant.',
        inicio: DateTime(ahora.year, ahora.month - 1, 1),
        fin: DateTime(ahora.year, ahora.month - 1, 15),
      ),
      _Quincena(
        label: '2a Q mes ant.',
        inicio: DateTime(ahora.year, ahora.month - 1, 16),
        fin: DateTime(ahora.year, ahora.month, 0),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: quincenas.map((q) {
          final sel = _rangoSeleccionado != null &&
              _rangoSeleccionado!.start == q.inicio &&
              _rangoSeleccionado!.end == q.fin;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label:
                  Text(q.label, style: const TextStyle(fontSize: 11)),
              selected: sel,
              selectedColor: Colors.indigo,
              labelStyle: TextStyle(
                color: sel ? Colors.white : Colors.indigo,
                fontWeight: FontWeight.w500,
              ),
              side: const BorderSide(color: Colors.indigo),
              onSelected: (_) {
                setState(() {
                  _rangoSeleccionado = DateTimeRange(
                    start: q.inicio,
                    end: q.fin,
                  );
                  _resetDatos();
                });
                _cargarVistaPrevia();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_view_rounded, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
                'Selecciona un periodo para ver la tabla de horas'),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────
  //  TABLA
  // ─────────────────────────────────────────────────────────────────

  Widget _buildTablaDetalle(bool esJefe) {
    final datosFiltrados = esJefe
        ? _datosPrevia
            .where((f) =>
                _obrasSeleccionadas.contains(f['obra']?.toString() ?? ''))
            .toList()
        : _datosPrevia
            .where((f) => _operariosSeleccionados
                .contains(f['operario']?.toString() ?? ''))
            .toList();

    if (datosFiltrados.isEmpty) {
      return Center(
        child: Text(esJefe
            ? 'Ninguna obra seleccionada'
            : 'Ningun operario seleccionado'),
      );
    }

    final List<DateTime> dias = [];
    DateTime temp = _rangoSeleccionado!.start;
    while (!temp.isAfter(_rangoSeleccionado!.end)) {
      dias.add(temp);
      temp = temp.add(const Duration(days: 1));
    }

    return esJefe
        ? _buildTablaAgrupadaPorObra(datosFiltrados, dias)
        : _buildTablaAgrupadaPorOperario(datosFiltrados, dias);
  }

  // ── Tabla agrupada por obra ───────────────────────────────────────

  Widget _buildTablaAgrupadaPorObra(
      List<dynamic> datos, List<DateTime> dias) {
    final Map<String, List<dynamic>> porObra = {};
    for (final f in datos) {
      porObra
          .putIfAbsent(f['obra']?.toString() ?? '', () => [])
          .add(f);
    }
    final obrasOrdenadas =
        _obrasDisponibles.where((o) => porObra.containsKey(o)).toList();

    DataRow subtotalObra(String nombre, List<dynamic> filas) {
      final Map<String, double> totDia = {};
      double tot = 0;
      for (final f in filas) {
        final hpd = f['horas_por_dia'] as Map<String, dynamic>;
        for (final d in dias) {
          final iso = DateFormat('yyyy-MM-dd').format(d);
          final v   = _extractHoras(hpd[iso]);
          if (v > 0) {
            totDia[iso] = (totDia[iso] ?? 0) + v;
            tot += v;
          }
        }
      }
      return DataRow(
        color: WidgetStateProperty.all(Colors.teal.withOpacity(0.10)),
        cells: [
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          DataCell(
            Text('Total $nombre',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.teal[800],
                    fontStyle: FontStyle.italic)),
          ),
          ...dias.map((d) {
            final iso  = DateFormat('yyyy-MM-dd').format(d);
            final t    = totDia[iso] ?? 0;
            final esDR = _esDiaRojo(d);
            return DataCell(Container(
              width: 35,
              height: double.infinity,
              alignment: Alignment.center,
              color: esDR ? Colors.red.shade50 : null,
              child: Text(
                t > 0 ? t.toStringAsFixed(1) : '-',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: esDR
                      ? Colors.red.shade300
                      : t == 0
                          ? Colors.grey[500]!
                          : t < 8
                              ? Colors.orange[700]!
                              : t > 8
                                  ? Colors.blue[700]!
                                  : Colors.green[700]!,
                ),
              ),
            ));
          }),
          DataCell(Container(
            alignment: Alignment.center,
            child: Text(
              tot.toStringAsFixed(1),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                  fontSize: 12),
            ),
          )),
        ],
      );
    }

    final List<DataRow> filas = [];
    for (final obra in obrasOrdenadas) {
      final fo = porObra[obra]!;
      for (final f in fo) {
        final hpd = f['horas_por_dia'] as Map<String, dynamic>;
        filas.add(DataRow(cells: [
          DataCell(Text(f['codigo']?.toString() ?? '',
              style: const TextStyle(fontSize: 11))),
          DataCell(Text(f['operario'] ?? '',
              style: const TextStyle(fontSize: 11))),
          DataCell(Text(f['categoria_profesional'] ?? '-',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey[700]))),
          DataCell(Text(
            (f['obra'] as String?)?.isNotEmpty == true ? f['obra'] : '-',
            style: const TextStyle(fontSize: 11),
          )),
          ...dias.map((d) {
            final iso = DateFormat('yyyy-MM-dd').format(d);
            return _celdaH(hpd[iso], iso, f as Map<String, dynamic>,
                _esDiaRojo(d), context);
          }),
          DataCell(Container(
            alignment: Alignment.center,
            child: Text(
              (f['total_horas'] as num).toStringAsFixed(1),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 12),
            ),
          )),
        ]));
      }
      filas.add(subtotalObra(obra, fo));
    }
    return _wrapTabla(dias, filas);
  }

  // ── Tabla agrupada por operario ───────────────────────────────────

  Widget _buildTablaAgrupadaPorOperario(
      List<dynamic> datos, List<DateTime> dias) {
    final Map<String, List<dynamic>> porOp = {};
    for (final f in datos) {
      porOp
          .putIfAbsent(f['operario']?.toString() ?? '', () => [])
          .add(f);
    }
    final opsOrdenados = _operariosDisponibles
        .where((o) => porOp.containsKey(o))
        .toList();

    DataRow subtotalOp(String nombre, List<dynamic> filas) {
      final Map<String, double> totDia = {};
      double tot = 0;
      for (final f in filas) {
        final hpd = f['horas_por_dia'] as Map<String, dynamic>;
        for (final d in dias) {
          final iso = DateFormat('yyyy-MM-dd').format(d);
          final v   = _extractHoras(hpd[iso]);
          if (v > 0) {
            totDia[iso] = (totDia[iso] ?? 0) + v;
            tot += v;
          }
        }
      }
      return DataRow(
        color:
            WidgetStateProperty.all(Colors.indigo.withOpacity(0.08)),
        cells: [
          const DataCell(SizedBox.shrink()),
          DataCell(Text('Total $nombre',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.indigo[700],
                  fontStyle: FontStyle.italic))),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          ...dias.map((d) {
            final iso  = DateFormat('yyyy-MM-dd').format(d);
            final t    = totDia[iso] ?? 0;
            final esDR = _esDiaRojo(d);
            return DataCell(Container(
              width: 35,
              height: double.infinity,
              alignment: Alignment.center,
              color: esDR ? Colors.red.shade50 : null,
              child: Text(
                t > 0 ? t.toStringAsFixed(1) : '-',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: esDR
                      ? Colors.red.shade300
                      : t == 0
                          ? Colors.grey[500]!
                          : t < 8
                              ? Colors.orange[700]!
                              : t > 8
                                  ? Colors.blue[700]!
                                  : Colors.green[700]!,
                ),
              ),
            ));
          }),
          DataCell(Container(
            alignment: Alignment.center,
            child: Text(
              tot.toStringAsFixed(1),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[700],
                  fontSize: 12),
            ),
          )),
        ],
      );
    }

    final List<DataRow> filas = [];
    for (final op in opsOrdenados) {
      final fo = porOp[op]!;
      for (final f in fo) {
        final hpd = f['horas_por_dia'] as Map<String, dynamic>;
        filas.add(DataRow(cells: [
          DataCell(Text(f['codigo']?.toString() ?? '',
              style: const TextStyle(fontSize: 11))),
          DataCell(Text(f['operario'] ?? '',
              style: const TextStyle(fontSize: 11))),
          DataCell(Text(f['categoria_profesional'] ?? '-',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey[700]))),
          DataCell(Text(
            (f['obra'] as String?)?.isNotEmpty == true ? f['obra'] : '-',
            style: const TextStyle(fontSize: 11),
          )),
          ...dias.map((d) {
            final iso = DateFormat('yyyy-MM-dd').format(d);
            return _celdaH(hpd[iso], iso, f as Map<String, dynamic>,
                _esDiaRojo(d), context);
          }),
          DataCell(Container(
            alignment: Alignment.center,
            child: Text(
              (f['total_horas'] as num).toStringAsFixed(1),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 12),
            ),
          )),
        ]));
      }
      filas.add(subtotalOp(op, fo));
    }
    return _wrapTabla(dias, filas);
  }

  // ── Wrapper tabla ─────────────────────────────────────────────────

  Widget _wrapTabla(List<DateTime> dias, List<DataRow> filas) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollConfiguration(
          behavior:
              ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            thickness: 8,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              thickness: 8,
              notificationPredicate: (n) => n.depth == 1,
              child: SingleChildScrollView(
                controller: _verticalController,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.only(bottom: 16, right: 16),
                      child: DataTable(
                        columnSpacing: 15,
                        horizontalMargin: 12,
                        headingRowHeight: 52,
                        headingRowColor:
                            WidgetStateProperty.all(Colors.indigo[50]),
                        columns: [
                          const DataColumn(
                              label: Text('Codigo',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                          const DataColumn(
                              label: Text('Operario',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                          const DataColumn(
                              label: Text('Categoria',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                          const DataColumn(
                              label: Text('Obra',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                          ...dias.map((d) {
                            final esDR = _esDiaRojo(d);
                            return DataColumn(
                              label: Container(
                                width: 35,
                                decoration: esDR
                                    ? BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      )
                                    : null,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _letraDia(d),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: esDR
                                            ? Colors.red.shade800
                                            : Colors.indigo[400],
                                      ),
                                    ),
                                    Text(
                                      '${d.day}/${d.month}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: esDR
                                            ? Colors.red.shade700
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const DataColumn(
                              label: Text('Total',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold))),
                        ],
                        rows: filas,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _LeyendaCelda extends StatelessWidget {
  final Color  color;
  final String letra;
  final String label;
  const _LeyendaCelda(
      {required this.color, required this.letra, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(letra,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _FiltroBottomSheet extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final List<String> disponibles;
  final Set<String>  seleccionados;
  final ValueChanged<Set<String>> onChanged;

  const _FiltroBottomSheet({
    required this.titulo,
    required this.icono,
    required this.disponibles,
    required this.seleccionados,
    required this.onChanged,
  });

  @override
  State<_FiltroBottomSheet> createState() => _FiltroBottomSheetState();
}

class _FiltroBottomSheetState extends State<_FiltroBottomSheet> {
  late Set<String> _sel;
  String _busqueda = '';
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sel = Set.from(widget.seleccionados);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<String> get _filtradas {
    if (_busqueda.isEmpty) return widget.disponibles;
    final q = _busqueda.toLowerCase();
    return widget.disponibles
        .where((s) => s.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final todosSeleccionados = _sel.length == widget.disponibles.length;
    final esObra = widget.titulo.toLowerCase().contains('obra');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(widget.icono, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(widget.titulo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sel = todosSeleccionados
                          ? {}
                          : widget.disponibles.toSet();
                    });
                    widget.onChanged(_sel);
                  },
                  child: Text(
                    todosSeleccionados
                        ? 'Deseleccionar todos'
                        : 'Seleccionar todos',
                    style: const TextStyle(color: Colors.indigo),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          Expanded(
            child: _filtradas.isEmpty
                ? const Center(child: Text('Sin resultados'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _filtradas.length,
                    itemBuilder: (context, i) {
                      final item = _filtradas[i];
                      return CheckboxListTile(
                        value: _sel.contains(item),
                        activeColor: Colors.indigo,
                        title: Text(item,
                            style: const TextStyle(fontSize: 14)),
                        onChanged: (v) {
                          setState(() => v == true
                              ? _sel.add(item)
                              : _sel.remove(item));
                          widget.onChanged(_sel);
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Ver ${_sel.length} '
                  '${esObra ? 'obra${_sel.length == 1 ? '' : 's'}' : 'operario${_sel.length == 1 ? '' : 's'}'}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Quincena {
  final String   label;
  final DateTime inicio;
  final DateTime fin;
  const _Quincena(
      {required this.label, required this.inicio, required this.fin});
}