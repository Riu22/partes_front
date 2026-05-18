import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  DateTimeRange? _rangoSeleccionado;
  bool _cargando = false;
  bool _exportandoPdf = false;
  List<dynamic> _datosPrevia = [];

  // ADMINISTRACION: filtro por operario
  List<String> _operariosDisponibles = [];
  Set<String> _operariosSeleccionados = {};

  // JEFE DE OBRA: filtro por obra
  List<String> _obrasDisponibles = [];
  Set<String> _obrasSeleccionadas = {};

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  bool get _esJefeObra =>
      ref.read(authProvider).valueOrNull?.esJefeObra == true;

  // ── Helper ausencias ──────────────────────────────────────────────

  /// Devuelve null si no hay ausencia en esa fecha,
  /// o un record con color de fondo, color de texto y letra (B/V).
  ({Color bg, Color fg, String letra})? _infoAusencia(
    Map<String, dynamic> fila,
    String isoFecha,
  ) {
    final ausencias = fila['ausencias_por_dia'] as Map<String, dynamic>? ?? {};
    final tipo = ausencias[isoFecha]?.toString();
    if (tipo == null) return null;
    if (tipo == 'BAJA') {
      return (bg: Colors.red.shade100, fg: Colors.red.shade800, letra: 'B');
    }
    // VACACIONES
    return (bg: Colors.amber.shade100, fg: Colors.amber.shade800, letra: 'V');
  }

  // ── Celda de horas con soporte ausencia ───────────────────────────

  DataCell _celdaH(double v, String isoFecha, Map<String, dynamic> f) {
    final aus = _infoAusencia(f, isoFecha);
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

  // ── Seleccion de fechas ───────────────────────────────────────────

  Future<void> _seleccionarFechas(BuildContext context) async {
    final DateTimeRange? nuevoRango = await showDateRangePicker(
      context: context,
      initialDateRange:
          _rangoSeleccionado ??
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
    _datosPrevia = [];
    _operariosDisponibles = [];
    _operariosSeleccionados = {};
    _obrasDisponibles = [];
    _obrasSeleccionadas = {};
  }

  // ── Carga de datos ────────────────────────────────────────────────

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
        final obras =
            data
                .map((f) => f['obra']?.toString() ?? '')
                .where((o) => o.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _datosPrevia = data;
          _obrasDisponibles = obras;
          _obrasSeleccionadas = obras.toSet();
        });
      } else {
        final operarios =
            data
                .map((f) => f['operario']?.toString() ?? '')
                .where((o) => o.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _datosPrevia = data;
          _operariosDisponibles = operarios;
          _operariosSeleccionados = operarios.toSet();
        });
      }
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  // ── Exportar CSV ──────────────────────────────────────────────────

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

  // ── Exportar PDF ──────────────────────────────────────────────────

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
                .where(
                  (f) =>
                      _obrasSeleccionadas.contains(f['obra']?.toString() ?? ''),
                )
                .toList()
          : _datosPrevia
                .where(
                  (f) => _operariosSeleccionados.contains(
                    f['operario']?.toString() ?? '',
                  ),
                )
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
        ...dias.map((d) => '${d.day}/${d.month}'),
        'Total',
      ];

      final List<List<String>> filas = [];
      final Set<int> indicesSubtotal = {};

      if (_esJefeObra) {
        final Map<String, List<dynamic>> porObra = {};
        for (final f in datosFiltrados) {
          porObra.putIfAbsent(f['obra']?.toString() ?? '', () => []).add(f);
        }
        final obras = _obrasDisponibles
            .where((o) => porObra.containsKey(o))
            .toList();

        for (final obra in obras) {
          final filasObra = porObra[obra]!;
          for (final f in filasObra) {
            final hpd = f['horas_por_dia'] as Map<String, dynamic>;
            final aus = f['ausencias_por_dia'] as Map<String, dynamic>? ?? {};
            filas.add([
              f['codigo']?.toString() ?? '',
              f['operario'] ?? '',
              f['categoria_profesional'] ?? '-',
              f['obra'] ?? '',
              ...dias.map((d) {
                final iso = DateFormat('yyyy-MM-dd').format(d);
                if (aus[iso] == 'BAJA') return 'B';
                if (aus[iso] == 'VACACIONES') return 'V';
                final h = hpd[iso];
                if (h == null) return '-';
                final double v = h is int ? h.toDouble() : h as double;
                return v > 0 ? v.toStringAsFixed(1) : '-';
              }),
              f['total_horas'].toStringAsFixed(1),
            ]);
          }
          final Map<String, double> totDia = {};
          double totGen = 0;
          for (final f in filasObra) {
            final hpd = f['horas_por_dia'] as Map<String, dynamic>;
            for (final d in dias) {
              final iso = DateFormat('yyyy-MM-dd').format(d);
              final h = hpd[iso];
              if (h != null) {
                final double v = h is int ? h.toDouble() : h as double;
                totDia[iso] = (totDia[iso] ?? 0) + v;
                totGen += v;
              }
            }
          }
          indicesSubtotal.add(filas.length);
          filas.add([
            '',
            '',
            '',
            'Total $obra',
            ...dias.map((d) {
              final iso = DateFormat('yyyy-MM-dd').format(d);
              final t = totDia[iso] ?? 0;
              return t > 0 ? t.toStringAsFixed(1) : '-';
            }),
            totGen.toStringAsFixed(1),
          ]);
        }
      } else {
        final Map<String, List<dynamic>> porOp = {};
        for (final f in datosFiltrados) {
          porOp.putIfAbsent(f['operario']?.toString() ?? '', () => []).add(f);
        }
        final ops = _operariosDisponibles
            .where((o) => porOp.containsKey(o))
            .toList();

        for (final op in ops) {
          final filasOp = porOp[op]!;
          for (final f in filasOp) {
            final hpd = f['horas_por_dia'] as Map<String, dynamic>;
            final aus = f['ausencias_por_dia'] as Map<String, dynamic>? ?? {};
            filas.add([
              f['codigo']?.toString() ?? '',
              f['operario'] ?? '',
              f['categoria_profesional'] ?? '-',
              f['obra'] ?? '',
              ...dias.map((d) {
                final iso = DateFormat('yyyy-MM-dd').format(d);
                if (aus[iso] == 'BAJA') return 'B';
                if (aus[iso] == 'VACACIONES') return 'V';
                final h = hpd[iso];
                if (h == null) return '-';
                final double v = h is int ? h.toDouble() : h as double;
                return v > 0 ? v.toStringAsFixed(1) : '-';
              }),
              f['total_horas'].toStringAsFixed(1),
            ]);
          }
          final Map<String, double> totDia = {};
          double totGen = 0;
          for (final f in filasOp) {
            final hpd = f['horas_por_dia'] as Map<String, dynamic>;
            for (final d in dias) {
              final iso = DateFormat('yyyy-MM-dd').format(d);
              final h = hpd[iso];
              if (h != null) {
                final double v = h is int ? h.toDouble() : h as double;
                totDia[iso] = (totDia[iso] ?? 0) + v;
                totGen += v;
              }
            }
          }
          indicesSubtotal.add(filas.length);
          filas.add([
            '',
            'Total $op',
            '',
            '',
            ...dias.map((d) {
              final iso = DateFormat('yyyy-MM-dd').format(d);
              final t = totDia[iso] ?? 0;
              return t > 0 ? t.toStringAsFixed(1) : '-';
            }),
            totGen.toStringAsFixed(1),
          ]);
        }
      }

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msj), backgroundColor: Colors.red));
  }

  // ── Filtros ───────────────────────────────────────────────────────

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
    final hayDatos = _datosPrevia.isNotEmpty;
    final int seleccionados = esJefe
        ? _obrasSeleccionadas.length
        : _operariosSeleccionados.length;
    final int total = esJefe
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
                  onPressed: (_exportandoPdf || _cargando)
                      ? null
                      : _exportarPdf,
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
            // ── Leyenda ausencias ──
            Row(
              children: [
                _LeyendaCelda(
                  color: Colors.red.shade100,
                  letra: 'B',
                  label: 'Baja',
                ),
                const SizedBox(width: 12),
                _LeyendaCelda(
                  color: Colors.amber.shade100,
                  letra: 'V',
                  label: 'Vacaciones',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: esJefe
                    ? _mostrarFiltroObras
                    : _mostrarFiltroOperarios,
                icon: Icon(
                  esJefe ? Icons.business_outlined : Icons.people_outline,
                  color: Colors.indigo,
                ),
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(esJefe ? 'Obras' : 'Operarios'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                    horizontal: 16,
                    vertical: 10,
                  ),
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
          final sel =
              _rangoSeleccionado != null &&
              _rangoSeleccionado!.start == q.inicio &&
              _rangoSeleccionado!.end == q.fin;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(q.label, style: const TextStyle(fontSize: 11)),
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
        const Text('Selecciona un periodo para ver la tabla de horas'),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────
  //  TABLA
  // ─────────────────────────────────────────────────────────────────

  Widget _buildTablaDetalle(bool esJefe) {
    final datosFiltrados = esJefe
        ? _datosPrevia
              .where(
                (f) =>
                    _obrasSeleccionadas.contains(f['obra']?.toString() ?? ''),
              )
              .toList()
        : _datosPrevia
              .where(
                (f) => _operariosSeleccionados.contains(
                  f['operario']?.toString() ?? '',
                ),
              )
              .toList();

    if (datosFiltrados.isEmpty) {
      return Center(
        child: Text(
          esJefe ? 'Ninguna obra seleccionada' : 'Ningun operario seleccionado',
        ),
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

  Widget _buildTablaAgrupadaPorObra(List<dynamic> datos, List<DateTime> dias) {
    final Map<String, List<dynamic>> porObra = {};
    for (final f in datos) {
      porObra.putIfAbsent(f['obra']?.toString() ?? '', () => []).add(f);
    }
    final obrasOrdenadas = _obrasDisponibles
        .where((o) => porObra.containsKey(o))
        .toList();

    DataRow subtotalObra(String nombre, List<dynamic> filas) {
      final Map<String, double> totDia = {};
      double tot = 0;
      for (final f in filas) {
        final hpd = f['horas_por_dia'] as Map<String, dynamic>;
        for (final d in dias) {
          final iso = DateFormat('yyyy-MM-dd').format(d);
          final h = hpd[iso];
          if (h != null) {
            final double v = h is int ? h.toDouble() : h as double;
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
            Text(
              'Total $nombre',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Colors.teal[800],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          ...dias.map((d) {
            final iso = DateFormat('yyyy-MM-dd').format(d);
            final t = totDia[iso] ?? 0;
            return DataCell(
              Container(
                width: 35,
                alignment: Alignment.center,
                child: Text(
                  t > 0 ? t.toStringAsFixed(1) : '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: t == 0
                        ? Colors.grey[500]!
                        : t < 8
                        ? Colors.orange[700]!
                        : t > 8
                        ? Colors.blue[700]!
                        : Colors.green[700]!,
                  ),
                ),
              ),
            );
          }),
          DataCell(
            Container(
              alignment: Alignment.center,
              child: Text(
                tot.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final List<DataRow> filas = [];
    for (final obra in obrasOrdenadas) {
      final fo = porObra[obra]!;
      for (final f in fo) {
        final hpd = f['horas_por_dia'] as Map<String, dynamic>;
        filas.add(
          DataRow(
            cells: [
              DataCell(
                Text(
                  f['codigo']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              DataCell(
                Text(f['operario'] ?? '', style: const TextStyle(fontSize: 11)),
              ),
              DataCell(
                Text(
                  f['categoria_profesional'] ?? '-',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey[700]),
                ),
              ),
              DataCell(
                Text(f['obra'] ?? '', style: const TextStyle(fontSize: 11)),
              ),
              ...dias.map((d) {
                final iso = DateFormat('yyyy-MM-dd').format(d);
                final h = hpd[iso];
                final double v = h != null
                    ? (h is int ? h.toDouble() : h as double)
                    : 0;
                return _celdaH(v, iso, f as Map<String, dynamic>);
              }),
              DataCell(
                Container(
                  alignment: Alignment.center,
                  child: Text(
                    f['total_horas'].toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      filas.add(subtotalObra(obra, fo));
    }
    return _wrapTabla(dias, filas);
  }

  Widget _buildTablaAgrupadaPorOperario(
    List<dynamic> datos,
    List<DateTime> dias,
  ) {
    final Map<String, List<dynamic>> porOp = {};
    for (final f in datos) {
      porOp.putIfAbsent(f['operario']?.toString() ?? '', () => []).add(f);
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
          final h = hpd[iso];
          if (h != null) {
            final double v = h is int ? h.toDouble() : h as double;
            totDia[iso] = (totDia[iso] ?? 0) + v;
            tot += v;
          }
        }
      }
      return DataRow(
        color: WidgetStateProperty.all(Colors.indigo.withOpacity(0.08)),
        cells: [
          const DataCell(SizedBox.shrink()),
          DataCell(
            Text(
              'Total $nombre',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Colors.indigo[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const DataCell(SizedBox.shrink()),
          const DataCell(SizedBox.shrink()),
          ...dias.map((d) {
            final iso = DateFormat('yyyy-MM-dd').format(d);
            final t = totDia[iso] ?? 0;
            return DataCell(
              Container(
                width: 35,
                alignment: Alignment.center,
                child: Text(
                  t > 0 ? t.toStringAsFixed(1) : '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: t == 0
                        ? Colors.grey[500]!
                        : t < 8
                        ? Colors.orange[700]!
                        : t > 8
                        ? Colors.blue[700]!
                        : Colors.green[700]!,
                  ),
                ),
              ),
            );
          }),
          DataCell(
            Container(
              alignment: Alignment.center,
              child: Text(
                tot.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[700],
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final List<DataRow> filas = [];
    for (final op in opsOrdenados) {
      final fo = porOp[op]!;
      for (final f in fo) {
        final hpd = f['horas_por_dia'] as Map<String, dynamic>;
        filas.add(
          DataRow(
            cells: [
              DataCell(
                Text(
                  f['codigo']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              DataCell(
                Text(f['operario'] ?? '', style: const TextStyle(fontSize: 11)),
              ),
              DataCell(
                Text(
                  f['categoria_profesional'] ?? '-',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey[700]),
                ),
              ),
              DataCell(
                Text(f['obra'] ?? '', style: const TextStyle(fontSize: 11)),
              ),
              ...dias.map((d) {
                final iso = DateFormat('yyyy-MM-dd').format(d);
                final h = hpd[iso];
                final double v = h != null
                    ? (h is int ? h.toDouble() : h as double)
                    : 0;
                return _celdaH(v, iso, f as Map<String, dynamic>);
              }),
              DataCell(
                Container(
                  alignment: Alignment.center,
                  child: Text(
                    f['total_horas'].toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      filas.add(subtotalOp(op, fo));
    }
    return _wrapTabla(dias, filas);
  }

  Widget _wrapTabla(List<DateTime> dias, List<DataRow> filas) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
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
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 16),
                child: DataTable(
                  columnSpacing: 15,
                  horizontalMargin: 12,
                  headingRowHeight: 45,
                  headingRowColor: WidgetStateProperty.all(Colors.indigo[50]),
                  columns: [
                    const DataColumn(
                      label: Text(
                        'Codigo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Operario',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Categoria',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Obra',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...dias.map(
                      (d) => DataColumn(
                        label: Container(
                          width: 35,
                          alignment: Alignment.center,
                          child: Text(
                            '${d.day}/${d.month}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: filas,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Leyenda de ausencias
// ─────────────────────────────────────────────────────────────────────────────

class _LeyendaCelda extends StatelessWidget {
  final Color color;
  final String letra;
  final String label;

  const _LeyendaCelda({
    required this.color,
    required this.letra,
    required this.label,
  });

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
          child: Text(
            letra,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom sheet reutilizable (obras u operarios)
// ─────────────────────────────────────────────────────────────────────────────

class _FiltroBottomSheet extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final List<String> disponibles;
  final Set<String> seleccionados;
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

  @override
  void initState() {
    super.initState();
    _sel = Set.from(widget.seleccionados);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(widget.icono, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  widget.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: widget.disponibles.length,
              itemBuilder: (context, i) {
                final item = widget.disponibles[i];
                return CheckboxListTile(
                  value: _sel.contains(item),
                  activeColor: Colors.indigo,
                  title: Text(item, style: const TextStyle(fontSize: 14)),
                  onChanged: (v) {
                    setState(
                      () => v == true ? _sel.add(item) : _sel.remove(item),
                    );
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
  final String label;
  final DateTime inicio;
  final DateTime fin;
  const _Quincena({
    required this.label,
    required this.inicio,
    required this.fin,
  });
}
