import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../helpers/tema_constants.dart';

class InformeJefeScreen extends ConsumerStatefulWidget {
  const InformeJefeScreen({super.key});

  @override
  ConsumerState<InformeJefeScreen> createState() => _InformeJefeScreenState();
}

class _InformeJefeScreenState extends ConsumerState<InformeJefeScreen> {
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  List<dynamic> _obras = [];
  num _totalHoras = 0;
  bool _cargando = false;
  String? _error;

  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

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

  Future<void> _exportarPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Informe de dedicación horaria',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${_fmt(_fechaInicio)}  →  ${_fmt(_fechaFin)}   ·   Total: ${_totalHoras.toStringAsFixed(2)} h',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 16),
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
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Obra', bold: true),
                    _pdfCell('H. Eléc.', bold: true),
                    _pdfCell('H. Mec.', bold: true),
                    _pdfCell('% Eléc.', bold: true),
                    _pdfCell('% Mec.', bold: true),
                  ],
                ),
                ..._obras.map(
                  (o) => pw.TableRow(
                    children: [
                      _pdfCell(o['nombre_obra'] ?? '—'),
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
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name:
          'informe_${DateFormat('yyyyMMdd').format(_fechaInicio!)}_'
          '${DateFormat('yyyyMMdd').format(_fechaFin!)}.pdf',
    );
  }

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
          'Informe de dedicación',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
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
          // ── Selector de rango ──────────────────────────────
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
                            : '${_fmt(_fechaInicio)}  →  ${_fmt(_fechaFin)}',
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

          // ── Tabla ──────────────────────────────────────────
          Expanded(child: _buildCuerpo()),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_fechaInicio == null) {
      return const Center(
        child: Text(
          'Selecciona un rango para ver\nla dedicación por obra',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // resumen total
          Text(
            'Total del período: ${_totalHoras.toStringAsFixed(2)} h',
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 10),

          // cabecera tabla
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
                _thCell('H. Eléc.'),
                _thCell('H. Mec.'),
                _thCell('% Eléc.'),
                _thCell('% Mec.'),
              ],
            ),
          ),

          // filas
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
                      _tdCell(o['nombre_obra'] ?? '—', flex: 4, bold: true),
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
