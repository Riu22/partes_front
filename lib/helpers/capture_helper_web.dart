/// Versión para web del helper de captura.
/// Genera un PDF con los datos de una tabla de partes (operarios, fechas, horas)
/// y lo descarga directamente en el navegador.
/// Usa el paquete `pdf` para crear el documento y `dart:html` para la descarga.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
//  Colores del PDF
// ─────────────────────────────────────────────────────────────────────────────

/// Azul oscuro para títulos y cabeceras
const _kIndigoDark  = PdfColor.fromInt(0xFF283593);
/// Azul medio para textos importantes
const _kIndigo      = PdfColor.fromInt(0xFF3949AB);
/// Azul claro para fondos de cabecera
const _kIndigoLight = PdfColor.fromInt(0xFFE8EAF6);
/// Rojo oscuro para días festivos
const _kRedDark     = PdfColor.fromInt(0xFFC62828);
/// Rojo claro para fondo de días rojos
const _kRedLight    = PdfColor.fromInt(0xFFFFEBEE);
/// Rojo medio para fondo de cabeceras de día rojo
const _kRedMid      = PdfColor.fromInt(0xFFFFCDD2);
/// Color de texto para bajas
const _kBajaFg      = PdfColor.fromInt(0xFFB71C1C);
/// Color de fondo para bajas
const _kBajaBg      = PdfColor.fromInt(0xFFFFCDD2);
/// Color de texto para vacaciones
const _kVacFg       = PdfColor.fromInt(0xFFF57F17);
/// Color de fondo para vacaciones
const _kVacBg       = PdfColor.fromInt(0xFFFFF8E1);
/// Color de texto para paternidad
const _kPatFg       = PdfColor.fromInt(0xFF0D47A1);
/// Color de fondo para paternidad
const _kPatBg       = PdfColor.fromInt(0xFFE3F2FD);
/// Fondo de las filas de subtotal
const _kSubtotalBg  = PdfColor.fromInt(0xFFE0F2F1);
/// Color de texto del subtotal
const _kSubtotalFg  = PdfColor.fromInt(0xFF00695C);
/// Fondo de la cabecera de obra
const _kCabeceraBg  = PdfColor.fromInt(0xFF3949AB);
/// Gris muy claro para fondos alternos
const _kGrey50      = PdfColor.fromInt(0xFFFAFAFA);
/// Gris claro para bordes
const _kGrey200     = PdfColor.fromInt(0xFFEEEEEE);
/// Gris medio para textos secundarios
const _kGrey400     = PdfColor.fromInt(0xFFBDBDBD);
/// Gris oscuro para textos de categoría
const _kGrey600     = PdfColor.fromInt(0xFF757575);

// ─────────────────────────────────────────────────────────────────────────────
//  Festivos nacionales fijos (mes, día)
// ─────────────────────────────────────────────────────────────────────────────

/// Días festivos fijos del año (sin contar los que cambian cada año).
/// Cada tupla es (mes, día).
const Set<(int, int)> _festivosFijos = {
  (1, 1),   // Año Nuevo
  (1, 6),   // Reyes
  (5, 1),   // Día del Trabajo
  (8, 15),  // Asunción
  (10, 12), // Fiesta Nacional
  (11, 1),  // Todos los Santos
  (12, 6),  // Constitución
  (12, 8),  // Inmaculada
  (12, 25), // Navidad
};

/// Dice si una fecha es "día rojo" (fin de semana o festivo fijo).
bool _esDiaRojo(DateTime d) =>
    d.weekday >= 6 || _festivosFijos.contains((d.month, d.day));

/// Letras de los días de la semana (L=lunes, M=martes, ..., D=domingo)
const _letrasDia = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

// ─────────────────────────────────────────────────────────────────────────────
//  Interpretar fecha desde el texto de cabecera
// ─────────────────────────────────────────────────────────────────────────────

/// Convierte el texto de una cabecera de columna (ej. "L\n1/5") en un objeto
/// DateTime. Si el texto no tiene el formato esperado, devuelve null.
///
/// - [texto]: el texto de la cabecera, puede ser "L\n1/5" o solo "1/5"
/// - [anioRango]: el año al que pertenecen las fechas del PDF
DateTime? _parsearCabecera(String texto, int anioRango) {
  final limpio = texto.contains('\n') ? texto.split('\n').last : texto;
  final partes = limpio.trim().split('/');
  if (partes.length != 2) return null;
  final dia = int.tryParse(partes[0].trim());
  final mes = int.tryParse(partes[1].trim());
  if (dia == null || mes == null) return null;
  return DateTime(anioRango, mes, dia);
}

/// Obtiene el año del rango de fechas mirando la primera columna de fecha
/// que pueda interpretarse. Si no encuentra ninguna, usa el año actual.
///
/// - [columnas]: la lista de títulos de columna
/// - [colsFijas]: número de columnas fijas (Código, Operario, Categoría, Obra)
int _extraerAnioRango(List<String> columnas, int colsFijas) {
  for (int i = colsFijas; i < columnas.length - 1; i++) {
    final texto = columnas[i];
    final limpio = texto.contains('\n') ? texto.split('\n').last : texto;
    final partes = limpio.trim().split('/');
    if (partes.length == 2) {
      return DateTime.now().year;
    }
  }
  return DateTime.now().year;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Función principal
// ─────────────────────────────────────────────────────────────────────────────

/// Genera un PDF con los datos de una tabla de partes y lo descarga
/// en el navegador automáticamente.
///
/// El PDF incluye:
///   - Cabecera con título, fecha de generación y leyenda de colores
///   - Tabla con columnas fijas (Código, Operario, Categoría, Obra)
///   - Columnas de fechas con letra del día y número
///   - Colores según ausencias (Baja, Vacaciones, Paternidad)
///   - Días rojos (fin de semana/festivos) resaltados
///   - Subtotales por obra
///   - Número de página en el pie
///
/// - [columnas]: títulos de todas las columnas
/// - [filas]: datos de cada fila
/// - [subtotales]: conjunto de índices de fila que son subtotales
/// - [titulo]: título del documento
Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  final pdf = pw.Document();
  final ahora = DateTime.now();

  // ── Distribución de columnas ────────────────────────────────────────
  const int colsFijas = 4; // Código | Operario | Categoría | Obra
  final int colsFechas = columnas.length - colsFijas - 1;

  // Año del rango (para detectar festivos correctamente)
  final int anioRango = _extraerAnioRango(columnas, colsFijas);

  // Para cada columna de fecha pre-calculamos:
  // si es día rojo, la letra del día y el número.
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

  // ── Anchos de cada columna ──────────────────────────────────────────
  Map<int, pw.TableColumnWidth> anchos() => {
        0: const pw.FlexColumnWidth(1.6),  // Código
        1: const pw.FlexColumnWidth(5.5),  // Operario
        2: const pw.FlexColumnWidth(2.4),  // Categoría
        3: const pw.FlexColumnWidth(6.0),  // Obra
        for (int i = colsFijas; i < colsFijas + colsFechas; i++)
          i: const pw.FlexColumnWidth(1.0),
        colsFijas + colsFechas: const pw.FlexColumnWidth(1.5), // Total
      };

  // ── Colores según tipo de ausencia ──────────────────────────────────
  /// Devuelve los colores (fondo, texto) según el código de ausencia:
  ///   'B' = Baja (rojo)
  ///   'V' = Vacaciones (ámbar)
  ///   'P' = Paternidad (azul)
  ///   Otros = null (sin color especial)
  (PdfColor, PdfColor)? colorAusencia(String texto) {
    switch (texto.trim()) {
      case 'B': return (_kBajaBg, _kBajaFg);
      case 'V': return (_kVacBg,  _kVacFg);
      case 'P': return (_kPatBg,  _kPatFg);
      default:  return null;
    }
  }

  // ── Creador de celdas ──────────────────────────────────────────────
  /// Crea una celda de tabla con el texto y estilo indicados.
  /// Permite poner texto en negrita, elegir alineación y colores.
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
          softWrap: true,
          overflow: pw.TextOverflow.span,
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

  // ── Cabecera de columna de fecha ───────────────────────────────────
  /// Dibuja la cabecera de una columna de fecha: letra del día arriba
  /// y número (día/mes) abajo. Si es día rojo usa fondo rojo.
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

  // ── Fila de cabecera ──────────────────────────────────────────────
  /// Crea la fila superior de la tabla con los títulos de cada columna.
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

  // ── Fila de datos ─────────────────────────────────────────────────
  /// Crea una fila de datos (un operario) o una fila de subtotal.
  /// Aplica colores según el tipo de ausencia y si es día rojo.
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

        // Columnas fijas
        return celda(texto,
            fgColor: col == 2 ? _kGrey600 : PdfColors.black, fontSize: 6.0);
      }).toList(),
    );
  }

  // ── Agrupar filas en bloques por obra ─────────────────────────────
  /// Agrupa las filas en bloques, donde cada bloque es una obra:
  /// cabecera de obra (opcional) + operarios + subtotal.
  /// Esto evita que una obra se parta entre dos páginas.
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
  /// Crea el widget visual de un bloque de obra completo.
  /// No se puede partir entre páginas gracias a pw.Inseparable.
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

  return pw.Inseparable(
    child: pw.Table(
      columnWidths: anchos(),
      border: pw.TableBorder.all(color: _kGrey200, width: 0.4),
      children: rows,
    ),
  );
  }

  // ── Leyenda ───────────────────────────────────────────────────────
  /// Crea un elemento de la leyenda: un recuadro de color con la letra
  /// y una etiqueta explicativa.
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

  /// Crea la leyenda completa con los significados de B, V, P y S/D.
  pw.Widget leyenda() => pw.Row(children: [
        leyendaItem('B',   _kBajaBg,   _kBajaFg,  'Baja'),
        pw.SizedBox(width: 10),
        leyendaItem('V',   _kVacBg,    _kVacFg,   'Vacaciones'),
        pw.SizedBox(width: 10),
        leyendaItem('P',   _kPatBg,    _kPatFg,   'Paternidad'),
        pw.SizedBox(width: 10),
        leyendaItem('S/D', _kRedLight, _kRedDark, 'Fin de semana / Festivo'),
      ]);

  // ── Montar página ─────────────────────────────────────────────────
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
          // Cabecera de columnas al inicio del contenido
          pw.Table(
            columnWidths: anchos(),
            border: pw.TableBorder.all(color: _kGrey200, width: 0.4),
            children: [filaColumnas()],
          ),
          // Un bloque por obra (nunca se parte entre páginas)
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
