// =============================================================================
// informe_jefe_screen.dart
// =============================================================================
// QUE ES:       Pantalla de informe de dedicacion horaria del jefe de obra.
// PARA QUE:     Ver desglose de horas electricas y mecanicas por obra en un
//               rango de fechas, con exportacion a PDF.
// QUIEN LO USA: Jefes de obra, administradores y gestion.
// COMO SE LLEGA: Desde el AppDrawer o menu de navegacion.
// A DONDE VA:   GET /api/informe-parte-jefe/rango (servidor).
// QUE DATOS USA: auth_provider, apiServiceProvider, tema_constants,
//                pdf, printing, intl.
// OFFLINE:      No aplica (datos siempre en linea).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../helpers/tema_constants.dart';

/// Muestra una tabla con las horas electricas y mecanicas agrupadas
/// por obra para un rango de fechas. Permite exportar a PDF.
class InformeJefeScreen extends ConsumerStatefulWidget {
  const InformeJefeScreen({super.key});

  @override
  ConsumerState<InformeJefeScreen> createState() => _InformeJefeScreenState();
}

/// Estado del informe: gestiona rango de fechas, carga de datos,
/// construccion de la tabla y exportacion a PDF.
class _InformeJefeScreenState extends ConsumerState<InformeJefeScreen> {
  DateTime? _fechaInicio; // Fecha de inicio del rango
  DateTime? _fechaFin; // Fecha de fin del rango
  List<dynamic> _obras = []; // Lista de obras con sus horas
  num _totalHoras = 0; // Total de horas laborables en el periodo
  bool _cargando = false; // Indica si esta cargando datos
  String? _error; // Mensaje de error si ocurre

  /// Formatea una fecha a dd/MM/yyyy o muestra "--" si es nula.
  String _fmt(DateTime? d) =>
      d == null ? '--' : DateFormat('dd/MM/yyyy').format(d);

  /// Abre un selector de rango de fechas y carga los datos.
  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: _fechaInicio != null && _fechaFin != null
          ? DateTimeRange(start: _fechaInicio!, end: _fechaFin!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: blue,
            onPrimary: Colors.white,
            surface: bgCard,
            onSurface: textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _fechaInicio = picked.start;
      _fechaFin = picked.end;
      _obras = [];
      _error = null;
    });
    await _cargar();
  }

  /// Carga los datos del informe desde el servidor.
  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await ref
          .read(apiServiceProvider)
          .getInformeParteJefePorRango(
            fechaInicio: _fechaInicio!,
            fechaFin: _fechaFin!,
          );
      setState(() {
        _obras = (data['obras'] as List?) ?? [];
        _totalHoras = (data['total_horas_laborables'] as num?) ?? 0;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  /// Genera y muestra un PDF con el informe de dedicacion.
  Future<void> _exportarPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Titulo del informe
            pw.Text(
              'Informe de dedicacion horaria',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            // Subtitulo con rango y total
            pw.Text(
              '${_fmt(_fechaInicio)}  ->  ${_fmt(_fechaFin)}   .   Total: ${_totalHoras.toStringAsFixed(2)} h',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 16),
            // Tabla con columnas: Obra, H. Elec., H. Mec., % Elec., % Mec.
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                // Cabecera
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Obra', bold: true),
                    _pdfCell('H. Elec.', bold: true),
                    _pdfCell('H. Mec.', bold: true),
                    _pdfCell('% Elec.', bold: true),
                    _pdfCell('% Mec.', bold: true),
                  ],
                ),
                // Filas de datos
                ..._obras.map(
                  (o) => pw.TableRow(
                    children: [
                      _pdfCell(o['nombre_obra'] ?? '--'),
                      _pdfCell(
                        '${(o['horas_electricas'] as num?)?.toStringAsFixed(2) ?? '0.00'} h',
                      ),
                      _pdfCell(
                        '${(o['horas_mecanicas'] as num?)?.toStringAsFixed(2) ?? '0.00'} h',
                      ),
                      _pdfCell(
                        '${(o['porcentaje_electrico'] as num?)?.toStringAsFixed(2) ?? '0.00'}%',
                      ),
                      _pdfCell(
                        '${(o['porcentaje_mecanico'] as num?)?.toStringAsFixed(2) ?? '0.00'}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    // Envia el PDF al servicio de impresion/visualizacion
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name:
          'informe_${DateFormat('yyyyMMdd').format(_fechaInicio!)}_'
          '${DateFormat('yyyyMMdd').format(_fechaFin!)}.pdf',
    );
  }

  /// Construye una celda de texto para el PDF.
  pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: bgCard,
        elevation: 0,
        title: const Text(
          'Informe de dedicacion',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
          // Boton de exportar PDF (solo visible con datos)
          if (_obras.isNotEmpty)
            IconButton(
              tooltip: 'Exportar PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined, color: blue),
              onPressed: _exportarPdf,
            ),
        ],
      ),
      body: Column(
        children: [
          // ---- Selector de rango ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _seleccionarRango,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range_outlined,
                      size: 18,
                      color: blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fechaInicio == null
                            ? 'Seleccionar rango de fechas'
                            : '${_fmt(_fechaInicio)}  ->  ${_fmt(_fechaFin)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _fechaInicio == null
                              ? textSecondary
                              : textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- Tabla de datos ----
          Expanded(child: _buildCuerpo()),
        ],
      ),
    );
  }

  /// Construye el cuerpo de la pantalla: estado vacio, carga, error o tabla.
  Widget _buildCuerpo() {
    if (_fechaInicio == null) {
      return const Center(
        child: Text(
          'Selecciona un rango para ver\nla dedicacion por obra',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.6),
        ),
      );
    }
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_obras.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos para el rango seleccionado',
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
      );
    }

    // ---- Tabla con datos ----
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen total
          Text(
            'Total del periodo: ${_totalHoras.toStringAsFixed(2)} h',
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 10),

          // Cabecera de la tabla
          Container(
            decoration: BoxDecoration(
              color: bgStat,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                _thCell('Obra', flex: 4),
                _thCell('H. Elec.'),
                _thCell('H. Mec.'),
                _thCell('% Elec.'),
                _thCell('% Mec.'),
              ],
            ),
          ),

          // Filas de datos
          Container(
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
              border: const Border(
                left: BorderSide(color: cardBorder),
                right: BorderSide(color: cardBorder),
                bottom: BorderSide(color: cardBorder),
              ),
            ),
            child: Column(
              children: _obras.asMap().entries.map((e) {
                final o = e.value as Map<String, dynamic>;
                final esUltimo = e.key == _obras.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    border: esUltimo
                        ? null
                        : const Border(bottom: BorderSide(color: cardBorder)),
                  ),
                  child: Row(
                    children: [
                      _tdCell(o['nombre_obra'] ?? '--', flex: 4, bold: true),
                      _tdCell(
                        '${(o['horas_electricas'] as num?)?.toStringAsFixed(2) ?? '0.00'} h',
                      ),
                      _tdCell(
                        '${(o['horas_mecanicas'] as num?)?.toStringAsFixed(2) ?? '0.00'} h',
                      ),
                      _tdCell(
                        '${(o['porcentaje_electrico'] as num?)?.toStringAsFixed(2) ?? '0.00'}%',
                        color: blue,
                      ),
                      _tdCell(
                        '${(o['porcentaje_mecanico'] as num?)?.toStringAsFixed(2) ?? '0.00'}%',
                        color: orange,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Celda de cabecera de tabla.
  Widget _thCell(String text, {int flex = 2}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );

  /// Celda de datos de tabla.
  Widget _tdCell(
    String text, {
    int flex = 2,
    bool bold = false,
    Color? color,
  }) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color ?? textPrimary,
        ),
      ),
    ),
  );
}
