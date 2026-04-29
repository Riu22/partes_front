import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});

  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen> {
  final ApiService _apiService = ApiService();

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  DateTimeRange? _rangoSeleccionado;
  bool _cargando = false;
  List<dynamic> _datosPrevia = [];

  List<String> _operariosDisponibles = [];
  Set<String> _operariosSeleccionados = {};

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

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
        _datosPrevia = [];
        _operariosDisponibles = [];
        _operariosSeleccionados = {};
      });
      _cargarVistaPrevia();
    }
  }

  Future<void> _cargarVistaPrevia() async {
    if (_rangoSeleccionado == null) return;
    setState(() => _cargando = true);
    try {
      final data = await _apiService.getContabilidadDetalleJson(
        _rangoSeleccionado!.start,
        _rangoSeleccionado!.end,
      );

      final operarios =
          data
              .map((fila) => fila['operario']?.toString() ?? '')
              .where((o) => o.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _datosPrevia = data;
        _operariosDisponibles = operarios;
        _operariosSeleccionados = operarios.toSet();
      });
    } catch (e) {
      _mostrarError("Error al cargar datos: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _ejecutarDescarga() async {
    if (_rangoSeleccionado == null) return;
    setState(() => _cargando = true);
    try {
      await _apiService.exportarContabilidadDetalleCsv(
        _rangoSeleccionado!.start,
        _rangoSeleccionado!.end,
      );
    } catch (e) {
      _mostrarError("Error en la descarga: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msj) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msj), backgroundColor: Colors.red));
  }

  void _mostrarFiltroOperarios() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final todosSeleccionados =
                _operariosSeleccionados.length == _operariosDisponibles.length;

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return Column(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.indigo),
                          const SizedBox(width: 8),
                          const Text(
                            'Filtrar operarios',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                if (todosSeleccionados) {
                                  _operariosSeleccionados = {};
                                } else {
                                  _operariosSeleccionados =
                                      _operariosDisponibles.toSet();
                                }
                              });
                              setState(() {});
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
                        itemCount: _operariosDisponibles.length,
                        itemBuilder: (context, index) {
                          final operario = _operariosDisponibles[index];
                          final seleccionado = _operariosSeleccionados.contains(
                            operario,
                          );
                          return CheckboxListTile(
                            value: seleccionado,
                            activeColor: Colors.indigo,
                            title: Text(
                              operario,
                              style: const TextStyle(fontSize: 14),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  _operariosSeleccionados.add(operario);
                                } else {
                                  _operariosSeleccionados.remove(operario);
                                }
                              });
                              setState(() {});
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
                            'Ver ${_operariosSeleccionados.length} operario${_operariosSeleccionados.length == 1 ? '' : 's'}',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportación Contable'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSelectorHeader(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _datosPrevia.isEmpty
                ? _buildEmptyState()
                : _buildTablaDetalle(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorHeader() {
    final hayDatos = _datosPrevia.isNotEmpty;
    final seleccionados = _operariosSeleccionados.length;
    final total = _operariosDisponibles.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _seleccionarFechas(context),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _rangoSeleccionado == null
                        ? "Seleccionar Rango"
                        : "${DateFormat('dd/MM/yy').format(_rangoSeleccionado!.start)} - ${DateFormat('dd/MM/yy').format(_rangoSeleccionado!.end)}",
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (hayDatos)
                ElevatedButton.icon(
                  onPressed: _cargando ? null : _ejecutarDescarga,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text("CSV"),
                ),
            ],
          ),
          if (hayDatos) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _mostrarFiltroOperarios,
                icon: const Icon(Icons.people_outline, color: Colors.indigo),
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Operarios'),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_view_rounded, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Carga un periodo para ver la tabla de horas"),
        ],
      ),
    );
  }

  Widget _buildTablaDetalle() {
    final datosFiltrados = _datosPrevia
        .where(
          (fila) => _operariosSeleccionados.contains(
            fila['operario']?.toString() ?? '',
          ),
        )
        .toList();

    if (datosFiltrados.isEmpty) {
      return const Center(child: Text('Ningún operario seleccionado'));
    }

    // Lista de días del rango
    List<DateTime> dias = [];
    DateTime temp = _rangoSeleccionado!.start;
    while (temp.isBefore(
      _rangoSeleccionado!.end.add(const Duration(days: 1)),
    )) {
      dias.add(temp);
      temp = temp.add(const Duration(days: 1));
    }

    // Agrupar filas por operario manteniendo el orden de _operariosDisponibles
    final Map<String, List<dynamic>> porOperario = {};
    for (final fila in datosFiltrados) {
      final op = fila['operario']?.toString() ?? '';
      porOperario.putIfAbsent(op, () => []).add(fila);
    }
    // Ordenar por el orden alfabético ya establecido en _operariosDisponibles
    final operariosOrdenados = _operariosDisponibles
        .where((op) => porOperario.containsKey(op))
        .toList();

    // Celda de horas de datos normales
    DataCell celdaHoras(double valor) {
      return DataCell(
        Container(
          width: 35,
          alignment: Alignment.center,
          child: Text(
            valor > 0 ? valor.toStringAsFixed(1) : '-',
            style: TextStyle(
              fontSize: 11,
              color: valor > 0 ? Colors.black87 : Colors.grey[600],
              fontWeight: valor > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    // Fila de subtotal por operario
    DataRow buildFilaSubtotalOperario(
      String nombreOperario,
      List<dynamic> filasOperario,
    ) {
      // Sumar horas por día de todas las obras de este operario
      final Map<String, double> totalesDia = {};
      double totalGeneral = 0.0;

      for (final fila in filasOperario) {
        final horasPorDia = fila['horas_por_dia'] as Map<String, dynamic>;
        for (final d in dias) {
          final isoFecha = DateFormat('yyyy-MM-dd').format(d);
          final h = horasPorDia[isoFecha];
          if (h != null) {
            final double valor = h is int ? h.toDouble() : h as double;
            totalesDia[isoFecha] = (totalesDia[isoFecha] ?? 0.0) + valor;
            totalGeneral += valor;
          }
        }
      }

      return DataRow(
        color: WidgetStateProperty.all(Colors.indigo.withOpacity(0.08)),
        cells: [
          const DataCell(SizedBox.shrink()),
          DataCell(
            Text(
              'Total $nombreOperario',
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
            final isoFecha = DateFormat('yyyy-MM-dd').format(d);
            final total = totalesDia[isoFecha] ?? 0.0;

            // Color según si se hicieron 8h, más o menos
            final Color color;
            if (total == 0) {
              color = Colors.grey[500]!;
            } else if (total < 8.0) {
              color = Colors.orange[700]!;
            } else if (total > 8.0) {
              color = Colors.blue[700]!;
            } else {
              color = Colors.green[700]!;
            }

            return DataCell(
              Container(
                width: 35,
                alignment: Alignment.center,
                child: Text(
                  total > 0 ? total.toStringAsFixed(1) : '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            );
          }),
          // Total general del operario
          DataCell(
            Container(
              alignment: Alignment.center,
              child: Text(
                totalGeneral.toStringAsFixed(1),
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

    // Construir todas las filas: datos + subtotal por cada operario
    final List<DataRow> todasLasFilas = [];
    for (final operario in operariosOrdenados) {
      final filasOp = porOperario[operario]!;
      // Filas de obras del operario
      for (final fila in filasOp) {
        final horasPorDia = fila['horas_por_dia'] as Map<String, dynamic>;
        todasLasFilas.add(
          DataRow(
            cells: [
              DataCell(
                Text(
                  fila['codigo']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              DataCell(
                Text(
                  fila['operario'] ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              DataCell(
                Text(
                  fila['grupo_profesional'] ?? '-',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey[700]),
                ),
              ),
              DataCell(
                Text(fila['obra'] ?? '', style: const TextStyle(fontSize: 11)),
              ),
              ...dias.map((d) {
                final isoFecha = DateFormat('yyyy-MM-dd').format(d);
                final h = horasPorDia[isoFecha];
                final double valor = h != null
                    ? (h is int ? h.toDouble() : h as double)
                    : 0.0;
                return celdaHoras(valor);
              }),
              DataCell(
                Container(
                  alignment: Alignment.center,
                  child: Text(
                    fila['total_horas'].toStringAsFixed(1),
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
      // Fila de subtotal justo después de las obras del operario
      todasLasFilas.add(buildFilaSubtotalOperario(operario, filasOp));
    }

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
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            controller: _verticalController,
            scrollDirection: Axis.vertical,
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
                        'Código',
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
                        'Grupo',
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
                  rows: todasLasFilas,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
