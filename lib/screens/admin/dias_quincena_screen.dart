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

  // Controladores para manejar el scroll vertical y horizontal sin conflictos
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  DateTimeRange? _rangoSeleccionado;
  bool _cargando = false;
  List<dynamic> _datosPrevia = [];

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
      setState(() => _datosPrevia = data);
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
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
          if (_datosPrevia.isNotEmpty)
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
    List<DateTime> dias = [];
    DateTime temp = _rangoSeleccionado!.start;
    while (temp.isBefore(
      _rangoSeleccionado!.end.add(const Duration(days: 1)),
    )) {
      dias.add(temp);
      temp = temp.add(const Duration(days: 1));
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
                  rows: _datosPrevia.map((fila) {
                    final horasPorDia =
                        fila['horas_por_dia'] as Map<String, dynamic>;

                    return DataRow(
                      cells: [
                        // 1. Código
                        DataCell(
                          Text(
                            fila['codigo']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        // 2. Operario
                        DataCell(
                          Text(
                            fila['operario'] ?? '',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        // 3. Grupo
                        DataCell(
                          Text(
                            fila['grupo_profesional'] ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey[700],
                            ),
                          ),
                        ),
                        // 4. Obra
                        DataCell(
                          Text(
                            fila['obra'] ?? '',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),

                        // Celdas de fechas
                        ...dias.map((d) {
                          final isoFecha = DateFormat('yyyy-MM-dd').format(d);
                          final h = horasPorDia[isoFecha];
                          final double valor = h != null
                              ? (h is int ? h.toDouble() : h)
                              : 0.0;

                          return DataCell(
                            Container(
                              width: 35,
                              alignment: Alignment.center,
                              child: Text(
                                valor > 0 ? valor.toStringAsFixed(1) : '-',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: valor > 0
                                      ? Colors.black
                                      : Colors.grey[350],
                                  fontWeight: valor > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                        // Total
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
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
