// capture_helper_web.dart
// Implementación WEB: genera el PDF con el paquete `pdf` y lo descarga
// directamente en el navegador mediante dart:html, sin path_provider.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  final pdf = pw.Document();

  // Número de columnas de fechas (todo excepto Codigo, Operario, Grupo, Obra, Total)
  final int colsFijas = 4; // Codigo | Operario | Grupo | Obra
  final int colsFechas = columnas.length - colsFijas - 1; // sin Total

  // Anchos relativos: fijas más anchas, fechas estrechas, total medio
  List<pw.FlexColumnWidth> _anchos() {
    return [
      const pw.FlexColumnWidth(2.0), // Codigo
      const pw.FlexColumnWidth(4.0), // Operario
      const pw.FlexColumnWidth(2.5), // Grupo
      const pw.FlexColumnWidth(4.0), // Obra
      ...List.filled(colsFechas, const pw.FlexColumnWidth(1.0)), // fechas
      const pw.FlexColumnWidth(1.5), // Total
    ];
  }

  pw.Widget _celda(
    String texto, {
    bool bold = false,
    bool esSubtotal = false,
    pw.Alignment alineacion = pw.Alignment.centerLeft,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: pw.Align(
        alignment: alineacion,
        child: pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: esSubtotal ? 6.5 : 6,
            fontWeight: bold || esSubtotal
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo700,
            ),
          ),
          pw.Text(
            'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
        ],
      ),
      build: (context) => [
        pw.Table(
          columnWidths: {
            for (int i = 0; i < _anchos().length; i++) i: _anchos()[i],
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            // ── Fila de cabecera ──────────────────────────────────
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
              children: columnas.map((c) {
                final esFecha =
                    columnas.indexOf(c) >= colsFijas &&
                    columnas.indexOf(c) < columnas.length - 1;
                return _celda(
                  c,
                  bold: true,
                  alineacion: esFecha
                      ? pw.Alignment.center
                      : pw.Alignment.centerLeft,
                );
              }).toList(),
            ),

            // ── Filas de datos ────────────────────────────────────
            ...filas.asMap().entries.map((entry) {
              final idx = entry.key;
              final fila = entry.value;
              final esSubtotal = subtotales.contains(idx);

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: esSubtotal
                      ? PdfColors.teal50
                      : idx.isEven
                      ? PdfColors.white
                      : PdfColors.grey50,
                ),
                children: fila.asMap().entries.map((e) {
                  final col = e.key;
                  final texto = e.value;
                  final esFecha = col >= colsFijas && col < fila.length - 1;
                  final esTotal = col == fila.length - 1;

                  PdfColor? colorTexto;
                  if (esSubtotal) {
                    colorTexto = esTotal
                        ? PdfColors.teal800
                        : PdfColors.teal700;
                  } else if (esTotal) {
                    colorTexto = PdfColors.indigo700;
                  }

                  return _celda(
                    texto,
                    bold: esSubtotal || esTotal,
                    esSubtotal: esSubtotal,
                    alineacion: esFecha || esTotal
                        ? pw.Alignment.center
                        : pw.Alignment.centerLeft,
                    color: colorTexto,
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ],
    ),
  );

  // ── Descargar en el navegador ─────────────────────────────────────
  final bytes = await pdf.save();
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', '$titulo.pdf')
    ..click();

  html.Url.revokeObjectUrl(url);
}
