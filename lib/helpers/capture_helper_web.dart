// capture_helper_web.dart
// Implementación WEB: genera el PDF con el paquete `pdf` y lo descarga
// directamente en el navegador mediante dart:html, sin path_provider.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
//  Paleta de colores
// ─────────────────────────────────────────────────────────────────────────────

const _kIndigoDark  = PdfColor.fromInt(0xFF283593); // indigo[800]
const _kIndigo      = PdfColor.fromInt(0xFF3949AB); // indigo[600]
const _kIndigoLight = PdfColor.fromInt(0xFFE8EAF6); // indigo[50]
const _kRedDark     = PdfColor.fromInt(0xFFC62828); // red[800]
const _kRedLight    = PdfColor.fromInt(0xFFFFEBEE); // red[50]
const _kRedMid      = PdfColor.fromInt(0xFFFFCDD2); // red[100]
const _kBajaFg      = PdfColor.fromInt(0xFFB71C1C); // red[900]
const _kBajaBg      = PdfColor.fromInt(0xFFFFCDD2); // red[100]
const _kVacFg       = PdfColor.fromInt(0xFFF57F17); // amber[900]
const _kVacBg       = PdfColor.fromInt(0xFFFFF8E1); // amber[50]
const _kPatFg       = PdfColor.fromInt(0xFF0D47A1); // blue[900]
const _kPatBg       = PdfColor.fromInt(0xFFE3F2FD); // blue[50]
const _kSubtotalBg  = PdfColor.fromInt(0xFFE0F2F1); // teal[50]
const _kSubtotalFg  = PdfColor.fromInt(0xFF00695C); // teal[800]
const _kCabeceraBg  = PdfColor.fromInt(0xFF3949AB); // indigo[600]
const _kGrey50      = PdfColor.fromInt(0xFFFAFAFA);
const _kGrey200     = PdfColor.fromInt(0xFFEEEEEE);
const _kGrey400     = PdfColor.fromInt(0xFFBDBDBD);
const _kGrey600     = PdfColor.fromInt(0xFF757575);

// ─────────────────────────────────────────────────────────────────────────────
//  Festivos nacionales fijos (mes, dia)
// ─────────────────────────────────────────────────────────────────────────────

const Set<(int, int)> _festivosFijos = {
  (1, 1),   // Año Nuevo
  (1, 6),   // Reyes
  (5, 1),   // Dia del Trabajo
  (8, 15),  // Asuncion
  (10, 12), // Fiesta Nacional
  (11, 1),  // Todos los Santos
  (12, 6),  // Constitucion
  (12, 8),  // Inmaculada
  (12, 25), // Navidad
};

bool _esDiaRojo(DateTime d) =>
    d.weekday >= 6 || _festivosFijos.contains((d.month, d.day));

const _letrasDia = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

// ─────────────────────────────────────────────────────────────────────────────
//  Parsear fecha desde texto de cabecera
//
//  El formato que envian las pantallas es  "L\n1/5"  (letra + \n + dia/mes).
//  Tambien soportamos el formato antiguo   "1/5".
//  Necesitamos el año del rango (no el año actual) para detectar festivos
//  correctamente cuando el PDF se genera en un año distinto al del rango.
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _parsearCabecera(String texto, int anioRango) {
  final limpio = texto.contains('\n') ? texto.split('\n').last : texto;
  final partes = limpio.trim().split('/');
  if (partes.length != 2) return null;
  final dia = int.tryParse(partes[0].trim());
  final mes = int.tryParse(partes[1].trim());
  if (dia == null || mes == null) return null;
  return DateTime(anioRango, mes, dia);
}

/// Extrae el año del rango leyendo la primera columna de fecha que pueda
/// parsearse. Si no encuentra ninguna devuelve el año actual como fallback.
int _extraerAnioRango(List<String> columnas, int colsFijas) {
  // El titulo suele tener "dd/MM/yy" pero es mas fiable leer las columnas.
  // Buscamos la primera columna de fecha (indice >= colsFijas, < last).
  for (int i = colsFijas; i < columnas.length - 1; i++) {
    final texto = columnas[i];
    final limpio = texto.contains('\n') ? texto.split('\n').last : texto;
    final partes = limpio.trim().split('/');
    if (partes.length == 2) {
      // Solo tenemos dia/mes; deducimos el año del titulo o usamos el actual.
      // Como no tenemos año en las columnas, usamos DateTime.now().year.
      // Si el rango cruza fin de año habria que afinar, pero es caso marginal.
      return DateTime.now().year;
    }
  }
  return DateTime.now().year;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Funcion principal
// ─────────────────────────────────────────────────────────────────────────────

Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  final pdf = pw.Document();
  final ahora = DateTime.now();

  // ── Layout ────────────────────────────────────────────────────────
  const int colsFijas = 4; // Codigo | Operario | Categoria | Obra
  final int colsFechas = columnas.length - colsFijas - 1;

  // Año del rango (para detectar festivos correctamente)
  final int anioRango = _extraerAnioRango(columnas, colsFijas);

  // Para cada columna pre-calculamos: es dia rojo + letra dia + numero
  // Esto evita re-parsear en cada celda.
  final List<bool>   esDiaRojoCol = List.filled(columnas.length, false);
  final List<String> letraCol     = List.filled(columnas.length, '');
  final List<String> numeroCol    = List.filled(columnas.length, '');

  for (int i = colsFijas; i < columnas.length - 1; i++) {
    final texto = columnas[i];
    if (texto.contains('\n')) {
      final partes = texto.split('\n');
      letraCol[i]  = partes[0].trim();
      numeroCol[i] = partes[1].trim();
    } else {
      numeroCol[i] = texto.trim();
    }
    final d = _parsearCabecera(texto, anioRango);
    if (d != null) {
      esDiaRojoCol[i] = _esDiaRojo(d);
      if (letraCol[i].isEmpty) letraCol[i] = _letrasDia[d.weekday - 1];
    }
  }

  // ── Anchos de columna ─────────────────────────────────────────────
  // CORRECCIÓN: ampliados Operario (4.5→5.5) y Obra (5.0→6.0) para evitar
  // que nombres largos como "PAN MATOS, Miguel Angel" o
  // "OFICINA LUM/ALMACÉN LUM" queden cortados.
  Map<int, pw.TableColumnWidth> anchos() => {
        0: const pw.FlexColumnWidth(1.6),  // Codigo
        1: const pw.FlexColumnWidth(5.5),  // Operario  ← ampliado de 4.5
        2: const pw.FlexColumnWidth(2.4),  // Categoria
        3: const pw.FlexColumnWidth(6.0),  // Obra      ← ampliado de 5.0
        for (int i = colsFijas; i < colsFijas + colsFechas; i++)
          i: const pw.FlexColumnWidth(1.0),
        colsFijas + colsFechas: const pw.FlexColumnWidth(1.5), // Total
      };

  // ── Ausencias ─────────────────────────────────────────────────────
  (PdfColor, PdfColor)? colorAusencia(String texto) {
    switch (texto.trim()) {
      case 'B': return (_kBajaBg, _kBajaFg);
      case 'V': return (_kVacBg,  _kVacFg);
      case 'P': return (_kPatBg,  _kPatFg);
      default:  return null;
    }
  }

  // ── Builder celda genérica ────────────────────────────────────────
  // CORRECCIÓN: añadidos softWrap: true y overflow: pw.TextOverflow.span
  // para que el texto fluya a múltiples líneas en lugar de quedar cortado.
  pw.Widget celda(
    String texto, {
    bool bold = false,
    pw.Alignment alineacion = pw.Alignment.centerLeft,
    PdfColor? fgColor,
    PdfColor? bgColor,
    double fontSize = 6.0,
  }) {
    final child = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Align(
        alignment: alineacion,
        child: pw.Text(
          texto,
          softWrap: true,                      // ← CORRECCIÓN
          overflow: pw.TextOverflow.span,      // ← CORRECCIÓN
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: fgColor,
          ),
        ),
      ),
    );
    return bgColor != null
        ? pw.Container(color: bgColor, child: child)
        : child;
  }

  // ── Cabecera de columna de fecha: letra arriba, número abajo ──────
  pw.Widget celdaFechaCab(int col) {
    final esDR   = esDiaRojoCol[col];
    final letra  = letraCol[col];
    final numero = numeroCol[col];
    return pw.Container(
      color: esDR ? _kRedMid : _kIndigoLight,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (letra.isNotEmpty)
              pw.Text(
                letra,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 5.5,
                  fontWeight: pw.FontWeight.bold,
                  color: esDR ? _kRedDark : _kIndigo,
                ),
              ),
            pw.Text(
              numero.isNotEmpty ? numero : columnas[col],
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 6.0,
                fontWeight: pw.FontWeight.bold,
                color: esDR ? _kRedDark : _kIndigoDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fila de cabecera de columnas ──────────────────────────────────
  pw.TableRow filaColumnas() => pw.TableRow(
        decoration: const pw.BoxDecoration(color: _kIndigoLight),
        children: List.generate(columnas.length, (i) {
          final esFecha = i >= colsFijas && i < columnas.length - 1;
          if (esFecha) return celdaFechaCab(i);
          return celda(
            columnas[i],
            bold: true,
            fgColor: _kIndigoDark,
            fontSize: 6.5,
            alineacion: i == columnas.length - 1
                ? pw.Alignment.center
                : pw.Alignment.centerLeft,
          );
        }),
      );

  // ── Fila de datos (operario o subtotal) ───────────────────────────
  pw.TableRow buildFila(List<String> fila, int idxLocal, {required bool esSubtotal}) {
    final rowBg = esSubtotal
        ? _kSubtotalBg
        : (idxLocal.isEven ? PdfColors.white : _kGrey50);

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: rowBg),
      children: fila.asMap().entries.map((e) {
        final col   = e.key;
        final texto = e.value;
        final esFecha = col >= colsFijas && col < fila.length - 1;
        final esTotal = col == fila.length - 1;
        final esDR    = esDiaRojoCol[col];

        // Subtotal
        if (esSubtotal) {
          final cellBg = (esFecha && esDR) ? _kRedLight : null;
          return celda(
            texto,
            bold: true,
            fgColor: _kSubtotalFg,
            bgColor: cellBg,
            fontSize: 6.5,
            alineacion: (esFecha || esTotal)
                ? pw.Alignment.center
                : pw.Alignment.centerLeft,
          );
        }

        // Celda de fecha
        if (esFecha) {
          final aus = colorAusencia(texto);
          if (aus != null) {
            return celda(texto, bold: true, fgColor: aus.$2, bgColor: aus.$1,
                fontSize: 6.0, alineacion: pw.Alignment.center);
          }
          if (esDR) {
            final tieneHoras = texto != '-' && texto.isNotEmpty;
            return celda(
              texto,
              bold: tieneHoras,
              fgColor: tieneHoras ? _kRedDark : _kRedMid,
              bgColor: _kRedLight,
              fontSize: 6.0,
              alineacion: pw.Alignment.center,
            );
          }
          return celda(
            texto,
            bold: texto != '-' && texto.isNotEmpty,
            fgColor: (texto == '-' || texto.isEmpty) ? _kGrey400 : PdfColors.black,
            fontSize: 6.0,
            alineacion: pw.Alignment.center,
          );
        }

        // Total
        if (esTotal) {
          return celda(texto, bold: true, fgColor: _kIndigo,
              fontSize: 6.5, alineacion: pw.Alignment.center);
        }

        // Celdas fijas
        return celda(texto,
            fgColor: col == 2 ? _kGrey600 : PdfColors.black, fontSize: 6.0);
      }).toList(),
    );
  }

  // ── Agrupar filas en bloques por obra ─────────────────────────────
  // Cada bloque = cabecera obra (opcional) + operarios + subtotal.
  // MultiPage trata cada bloque como widget atomico → nunca lo parte.

  List<List<({List<String> fila, bool esSubtotal, bool esCabecera})>> agruparBloques() {
    final bloques = <List<({List<String> fila, bool esSubtotal, bool esCabecera})>>[];
    List<({List<String> fila, bool esSubtotal, bool esCabecera})>? bloque;

    for (int i = 0; i < filas.length; i++) {
      final fila        = filas[i];
      final esSubtotal  = subtotales.contains(i);
      final esCabecera  = !esSubtotal &&
          fila[0].isNotEmpty &&
          fila.skip(1).every((c) => c.isEmpty);

      if (esCabecera) {
        if (bloque != null) bloques.add(bloque);
        bloque = [(fila: fila, esSubtotal: false, esCabecera: true)];
      } else {
        bloque ??= [];
        bloque.add((fila: fila, esSubtotal: esSubtotal, esCabecera: false));
        if (esSubtotal) {
          bloques.add(bloque);
          bloque = null;
        }
      }
    }
    if (bloque != null && bloque.isNotEmpty) bloques.add(bloque);
    return bloques;
  }

  // ── Widget de un bloque (tabla de una obra) ───────────────────────
  pw.Widget buildBloqueObra(
    List<({List<String> fila, bool esSubtotal, bool esCabecera})> bloque,
  ) {
    final rows = <pw.TableRow>[];
    int idxLocal = 0;

    for (final item in bloque) {
      if (item.esCabecera) {
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kCabeceraBg),
          children: item.fila.asMap().entries.map((e) => celda(
            e.value,
            bold: true,
            fgColor: PdfColors.white,
            fontSize: 7.0,
          )).toList(),
        ));
      } else {
        rows.add(buildFila(item.fila, idxLocal, esSubtotal: item.esSubtotal));
        if (!item.esSubtotal) idxLocal++;
      }
    }

  // CORRECCIÓN: pw.Inseparable evita que el bloque se parta entre páginas
  return pw.Inseparable(
    child: pw.Table(
      columnWidths: anchos(),
      border: pw.TableBorder.all(color: _kGrey200, width: 0.4),
      children: rows,
    ),
  );
  }

  // ── Leyenda ───────────────────────────────────────────────────────
  pw.Widget leyendaItem(String letra, PdfColor bg, PdfColor fg, String label) =>
      pw.Row(children: [
        pw.Container(
          width: 14, height: 10,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            border: pw.Border.all(color: _kGrey200, width: 0.5),
          ),
          child: pw.Text(letra,
              style: pw.TextStyle(
                fontSize: letra.length > 1 ? 4.5 : 6.0,
                fontWeight: pw.FontWeight.bold,
                color: fg,
              )),
        ),
        pw.SizedBox(width: 3),
        pw.Text(label, style: const pw.TextStyle(fontSize: 6, color: _kGrey600)),
      ]);

  pw.Widget leyenda() => pw.Row(children: [
        leyendaItem('B',   _kBajaBg,   _kBajaFg,  'Baja'),
        pw.SizedBox(width: 10),
        leyendaItem('V',   _kVacBg,    _kVacFg,   'Vacaciones'),
        pw.SizedBox(width: 10),
        leyendaItem('P',   _kPatBg,    _kPatFg,   'Paternidad'),
        pw.SizedBox(width: 10),
        leyendaItem('S/D', _kRedLight, _kRedDark, 'Fin de semana / Festivo'),
      ]);

  // ── Montar pagina ─────────────────────────────────────────────────
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(titulo,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: _kIndigoDark)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(ahora)}',
                      style: const pw.TextStyle(fontSize: 7, color: _kGrey600),
                    ),
                  ],
                ),
              ),
              leyenda(),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _kIndigo, thickness: 1),
          pw.SizedBox(height: 4),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(titulo,
              style: const pw.TextStyle(fontSize: 6, color: _kGrey600)),
          pw.Text('Pag. ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6, color: _kGrey600)),
        ],
      ),
      build: (context) {
        final bloques = agruparBloques();
        return [
          // Cabecera de columnas sticky al inicio del contenido
          pw.Table(
            columnWidths: anchos(),
            border: pw.TableBorder.all(color: _kGrey200, width: 0.4),
            children: [filaColumnas()],
          ),
          // Un bloque por obra: nunca se parte entre paginas
          for (final bloque in bloques) buildBloqueObra(bloque),
        ];
      },
    ),
  );

  // ── Descargar en el navegador ─────────────────────────────────────
  final bytes = await pdf.save();
  final blob  = html.Blob([bytes], 'application/pdf');
  final url   = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', '$titulo.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
}