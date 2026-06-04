// =============================================================================
//  capture_helper_web.dart  -  HELPER DE CAPTURA (VERSION WEB)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Implementa la generacion de un PDF con los datos de una tabla de
//  partes (operarios, fechas, horas trabajadas, ausencias, etc.)
//  y lo descarga directamente en el navegador del usuario.
//
//  El PDF incluye:
//    - Cabecera con el titulo del documento, la fecha de generacion
//      y una leyenda explicativa de los codigos de ausencia.
//    - Tabla con columnas fijas (Codigo, Operario, Categoria, Obra)
//      y columnas variables para cada dia del periodo seleccionado.
//    - Colores especiales para "dias rojos" (findes de semana y
//      festivos nacionales fijos).
//    - Codigos de ausencia: B (Baja), V (Vacaciones), P (Paternidad),
//      cada uno con su propio color de fondo y texto.
//    - Subtotales por obra con estilo diferenciado.
//    - Numeracion de paginas en el pie.
//    - Bloques de obra que nunca se parten entre dos paginas.
//
//  POR QUE LA WEB NECESITA SU PROPIA VERSION?
//  - La web dispone de dart:html, que permite crear objetos Blob,
//    generar URLs de objeto y simular un clic en un enlace para
//    descargar el archivo. Esto no existe en movil ni escritorio.
//  - El paquete 'pdf' se usa para construir el documento.
//  - El navegador maneja automaticamente el dialogo de descarga.
//
//  DEPENDENCIAS:
//    - dart:html       (solo disponible en navegador web)
//    - package:intl    (formateo de fechas)
//    - package:pdf     (generacion de documentos PDF)
// =============================================================================

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // API del navegador para blobs y descargas

import 'package:intl/intl.dart';        // Formateo de fechas (DateFormat)
import 'package:pdf/pdf.dart';           // Colores y formato del PDF
import 'package:pdf/widgets.dart' as pw; // Widgets para construir el PDF

// =============================================================================
//  PALETA DE COLORES DEL PDF
// =============================================================================
//  Colores fijos usados en todo el documento. Se definen como constantes
//  para mantener consistencia y facilitar cambios futuros.
//  Los valores son enteros hexadecimales de 32 bits (0xAARRGGBB).
// =============================================================================

/// Azul oscuro para titulos principales y cabeceras de tabla.
/// Se usa en el titulo del documento y en el texto de las cabeceras
/// de columna para dar contraste.
const _kIndigoDark  = PdfColor.fromInt(0xFF283593);

/// Azul medio para textos importantes, como los totales de cada fila
/// y los divisores.
const _kIndigo      = PdfColor.fromInt(0xFF3949AB);

/// Azul muy claro para el fondo de las cabeceras de columna.
/// Proporciona un fondo suave que no compite con el texto.
const _kIndigoLight = PdfColor.fromInt(0xFFE8EAF6);

/// Rojo oscuro para el texto de los "dias rojos" (fin de semana
/// o festivos) y para los codigos de ausencia tipo Baja.
const _kRedDark     = PdfColor.fromInt(0xFFC62828);

/// Rojo claro para el fondo de las celdas de dias rojos y para
/// el fondo de las celdas de ausencia tipo Baja.
const _kRedLight    = PdfColor.fromInt(0xFFFFEBEE);

/// Rojo medio para el fondo de las cabeceras de columna cuando
/// el dia correspondiente es un dia rojo.
const _kRedMid      = PdfColor.fromInt(0xFFFFCDD2);

/// Color del texto para las celdas de tipo Baja (B).
/// Rojo muy oscuro, casi granate, para indicar gravedad.
const _kBajaFg      = PdfColor.fromInt(0xFFB71C1C);

/// Color de fondo para las celdas de tipo Baja (B).
/// Rojo claro pastel para que el texto rojo destaque.
const _kBajaBg      = PdfColor.fromInt(0xFFFFCDD2);

/// Color del texto para las celdas de tipo Vacaciones (V).
/// Naranja/ambar para diferenciarlo de otros tipos de ausencia.
const _kVacFg       = PdfColor.fromInt(0xFFF57F17);

/// Color de fondo para las celdas de tipo Vacaciones (V).
/// Amarillo/crema claro.
const _kVacBg       = PdfColor.fromInt(0xFFFFF8E1);

/// Color del texto para las celdas de tipo Paternidad (P).
/// Azul oscuro para diferenciarlo de Baja y Vacaciones.
const _kPatFg       = PdfColor.fromInt(0xFF0D47A1);

/// Color de fondo para las celdas de tipo Paternidad (P).
/// Azul muy claro.
const _kPatBg       = PdfColor.fromInt(0xFFE3F2FD);

/// Fondo de las filas de subtotal (verde claro).
/// Se usa para destacar visualmente las filas que resumen una obra.
const _kSubtotalBg  = PdfColor.fromInt(0xFFE0F2F1);

/// Color del texto de las filas de subtotal (verde oscuro).
const _kSubtotalFg  = PdfColor.fromInt(0xFF00695C);

/// Fondo de la cabecera de obra (azul oscuro).
/// Las cabeceras de obra son filas especiales que agrupan a los
/// operarios de una misma obra.
const _kCabeceraBg  = PdfColor.fromInt(0xFF3949AB);

/// Gris muy claro para el fondo de las filas pares en la tabla.
/// Alterna con blanco para mejorar la legibilidad (efecto cebra).
const _kGrey50      = PdfColor.fromInt(0xFFFAFAFA);

/// Gris claro para los bordes de la tabla y de las celdas.
const _kGrey200     = PdfColor.fromInt(0xFFEEEEEE);

/// Gris medio para textos secundarios o de baja prioridad,
/// como la fecha de generacion o las etiquetas de la leyenda.
const _kGrey400     = PdfColor.fromInt(0xFFBDBDBD);

/// Gris oscuro para el texto de la columna "Categoria".
/// Se usa para dar menos enfasis a esta columna frente a otras.
const _kGrey600     = PdfColor.fromInt(0xFF757575);

// =============================================================================
//  FESTIVOS NACIONALES FIJOS
// =============================================================================
//  Conjunto de festivos que caen siempre en la misma fecha cada ano.
//  Los festivos que cambian de fecha (como la Semana Santa) no estan
//  incluidos; se deberian anadir dinamicamente si hicieran falta.
//  Cada elemento es una tupla (mes, dia).
// =============================================================================

/// Conjunto de dias festivos fijos del calendario espanol.
/// Se usa para detectar "dias rojos" junto con los fines de semana.
/// Formato: cada entrada es (mes, dia).
const Set<(int, int)> _festivosFijos = {
  (1, 1),   // 1 de enero: Ano Nuevo
  (1, 6),   // 6 de enero: Reyes (Epifania del Senor)
  (5, 1),   // 1 de mayo: Dia del Trabajo
  (8, 15),  // 15 de agosto: Asuncion de la Virgen
  (10, 12), // 12 de octubre: Fiesta Nacional de Espana
  (11, 1),  // 1 de noviembre: Todos los Santos
  (12, 6),  // 6 de diciembre: Dia de la Constitucion Espanola
  (12, 8),  // 8 de diciembre: Inmaculada Concepcion
  (12, 25), // 25 de diciembre: Navidad
};

/// Determina si una fecha es un "dia rojo".
/// Se considera dia rojo si:
///   - Es sabado (weekday == 6) o domingo (weekday == 7)
///   - O esta en el conjunto de festivos fijos [_festivosFijos]
///
/// [d] - La fecha a evaluar.
/// Devuelve true si es dia rojo, false en caso contrario.
bool _esDiaRojo(DateTime d) =>
    d.weekday >= 6 || _festivosFijos.contains((d.month, d.day));

/// Letras de los dias de la semana, comenzando por lunes.
/// Se usan para mostrar la inicial del dia en la cabecera de cada
/// columna de fecha (L=lunes, M=martes, ..., D=domingo).
const _letrasDia = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

// =============================================================================
//  INTERPRETACION DE FECHAS DESDE CABECERAS
// =============================================================================

/// Convierte el texto de una cabecera de columna de fecha en un
/// objeto [DateTime]. El formato esperado es "LETRA\nDIA/MES" o
/// simplemente "DIA/MES". Por ejemplo: "L\n1/5" o "1/5".
///
/// Si el texto no tiene el formato esperado (no contiene dos partes
/// separadas por '/'), devuelve null.
///
/// [texto]      - El texto de la cabecera, tal como aparece en la
///                columna correspondiente.
/// [anioRango]  - El ano al que pertenece la fecha (se asume que
///                todas las fechas del PDF son del mismo ano).
/// Devuelve un [DateTime] si se pudo interpretar, o null si no.
DateTime? _parsearCabecera(String texto, int anioRango) {
  // Si el texto contiene un salto de linea (separando la letra del dia
  // y el mes), nos quedamos con la parte despues del salto.
  // Ejemplo: "L\n1/5" -> "1/5"
  final limpio = texto.contains('\n') ? texto.split('\n').last : texto;

  // Dividimos por '/' para obtener dia y mes.
  // Ejemplo: "1/5" -> ["1", "5"]
  final partes = limpio.trim().split('/');

  // Si no hay exactamente dos partes, el formato no es valido.
  if (partes.length != 2) return null;

  // Intentamos convertir las partes a enteros.
  final dia = int.tryParse(partes[0].trim());
  final mes = int.tryParse(partes[1].trim());

  // Si alguna conversion fallo (null), devolvemos null.
  if (dia == null || mes == null) return null;

  // Construimos la fecha con el ano recibido.
  return DateTime(anioRango, mes, dia);
}

/// Obtiene el ano del rango de fechas analizando la primera columna
/// de fecha que pueda interpretarse. Si no encuentra ninguna fecha
/// valida, usa el ano actual.
///
/// Esto es necesario para detectar correctamente los festivos fijos,
/// ya que necesitamos un ano concreto para construir los DateTime.
///
/// [columnas]  - Lista de titulos de columna.
/// [colsFijas] - Numero de columnas fijas al inicio (Codigo, Operario,
///               Categoria, Obra). Las columnas de fecha empiezan
///               despues de estas.
/// Devuelve el ano que se usara para todas las fechas del PDF.
int _extraerAnioRango(List<String> columnas, int colsFijas) {
  // Recorremos las columnas de fecha (saltandonos las fijas y la
  // columna de total al final).
  for (int i = colsFijas; i < columnas.length - 1; i++) {
    final texto = columnas[i];

    // Extraemos la parte numerica (dia/mes) si hay salto de linea.
    final limpio = texto.contains('\n') ? texto.split('\n').last : texto;

    // Si tiene formato "dia/mes", asumimos que el ano es el actual.
    // No intentamos extraer el ano del texto porque las cabeceras
    // solo contienen dia y mes.
    final partes = limpio.trim().split('/');
    if (partes.length == 2) {
      return DateTime.now().year;
    }
  }

  // Si no encontramos ninguna fecha, usamos el ano actual como fallback.
  return DateTime.now().year;
}

// =============================================================================
//  FUNCION PRINCIPAL: generarYMostrarPdf
// =============================================================================

/// Genera un documento PDF con una tabla de partes y lo descarga
/// automaticamente en el navegador del usuario.
///
/// El PDF se construye con el paquete 'pdf' y se descarga usando
/// la API de dart:html (Blob, URL.createObjectUrl, etc.).
///
/// La estructura del documento es:
///   1. Cabecera de pagina: titulo, fecha de generacion y leyenda
///      de colores (B, V, P, S/D).
///   2. Tabla principal con:
///      - Columnas fijas: Codigo, Operario, Categoria, Obra.
///      - Columnas variables: una por cada dia del periodo, con la
///        letra del dia y el numero (dia/mes). Los dias rojos
///        (festivos/finde) se marcan en rojo.
///      - Columna de total al final.
///   3. Filas agrupadas por obra, con cabecera de obra, operarios
///      y subtotal. Cada obra es un bloque inseparable que no se
///      parte entre paginas.
///   4. Pie de pagina: titulo y numero de pagina.
///
/// Parametros:
///   [columnas]   - Titulos de todas las columnas de la tabla.
///   [filas]      - Datos de cada fila. Cada fila es una lista de
///                  strings con el mismo orden que [columnas].
///   [subtotales] - Conjunto de indices de fila (dentro de [filas])
///                  que corresponden a subtotales de obra.
///   [titulo]     - Titulo que aparecera en la cabecera del PDF y
///                  como nombre del archivo descargado.
Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  // Creamos el documento PDF vacio.
  final pdf = pw.Document();

  // Obtenemos la fecha y hora actual para mostrarla en la cabecera.
  final ahora = DateTime.now();

  // ===========================================================================
  //  DISTRIBUCION DE COLUMNAS
  // ===========================================================================
  //  Las primeras 4 columnas son fijas: Codigo, Operario, Categoria, Obra.
  //  Luego vienen N columnas de fecha (una por dia).
  //  La ultima columna es el total de horas del operario.
  // ===========================================================================

  // Numero de columnas fijas al inicio de la tabla.
  const int colsFijas = 4; // Codigo | Operario | Categoria | Obra

  // Numero de columnas de fecha (totales menos fijas menos la de total).
  final int colsFechas = columnas.length - colsFijas - 1;

  // Determinamos el ano del rango para poder construir fechas
  // correctamente y detectar festivos.
  final int anioRango = _extraerAnioRango(columnas, colsFijas);

  // ===========================================================================
  //  PRECALCULO DE DATOS POR COLUMNA DE FECHA
  // ===========================================================================
  //  Para cada columna de fecha pre-calculamos:
  //    - Si es dia rojo (bool)
  //    - La letra del dia (L, M, X, ...)
  //    - El numero (dia/mes)
  //  Esto evita tener que recalcularlo para cada fila y mejora el
  //  rendimiento.
  // ===========================================================================

  // Lista de booleanos: true si la columna i es un dia rojo.
  final List<bool> esDiaRojoCol = List.filled(columnas.length, false);

  // Lista de letras del dia para cada columna.
  final List<String> letraCol = List.filled(columnas.length, '');

  // Lista de numeros (dia/mes) para cada columna.
  final List<String> numeroCol = List.filled(columnas.length, '');

  // Recorremos solo las columnas de fecha (despues de las fijas y
  // antes de la columna de total).
  for (int i = colsFijas; i < columnas.length - 1; i++) {
    final texto = columnas[i];

    if (texto.contains('\n')) {
      // El texto tiene formato "LETRA\nNUMERO" (ej. "L\n1/5").
      final partes = texto.split('\n');
      letraCol[i]  = partes[0].trim();   // "L"
      numeroCol[i] = partes[1].trim();    // "1/5"
    } else {
      // El texto solo tiene el numero (ej. "1/5").
      numeroCol[i] = texto.trim();
    }

    // Intentamos interpretar la fecha de la cabecera.
    final d = _parsearCabecera(texto, anioRango);
    if (d != null) {
      // Si se pudo interpretar, marcamos si es dia rojo.
      esDiaRojoCol[i] = _esDiaRojo(d);

      // Si no teniamos letra del dia, la calculamos a partir del
      // DateTime (d.weekday va de 1=lunes a 7=domingo).
      if (letraCol[i].isEmpty) {
        letraCol[i] = _letrasDia[d.weekday - 1];
      }
    }
  }

  // ===========================================================================
  //  ANCHOS DE COLUMNA
  // ===========================================================================
  //  Define el ancho relativo de cada columna usando FlexColumnWidth.
  //  Los valores son proporcionales: una columna con ancho 5.5 ocupara
  //  mas espacio que una con ancho 1.0.
  // ===========================================================================

  /// Devuelve un mapa que asigna a cada indice de columna su ancho
  /// dentro de la tabla. Se usa en [pw.Table] para distribuir el
  /// espacio horizontal.
  Map<int, pw.TableColumnWidth> anchos() => {
        // Columna 0: Codigo (estrecha, solo 3-4 digitos)
        0: const pw.FlexColumnWidth(1.6),

        // Columna 1: Operario (ancha, nombre completo)
        1: const pw.FlexColumnWidth(5.5),

        // Columna 2: Categoria (mediana)
        2: const pw.FlexColumnWidth(2.4),

        // Columna 3: Obra (ancha, nombre de obra)
        3: const pw.FlexColumnWidth(6.0),

        // Columnas de fecha: todas con el mismo ancho (1.0)
        for (int i = colsFijas; i < colsFijas + colsFechas; i++)
          i: const pw.FlexColumnWidth(1.0),

        // Ultima columna: Total (mediana-estrecha)
        colsFijas + colsFechas: const pw.FlexColumnWidth(1.5),
      };

  // ===========================================================================
  //  COLORES SEGUN TIPO DE AUSENCIA
  // ===========================================================================

  /// Determina los colores (fondo, texto) para una celda segun el
  /// codigo de ausencia que contenga.
  ///
  /// Los codigos reconocidos son:
  ///   'B' (Baja)       -> fondo rojo claro, texto rojo oscuro
  ///   'V' (Vacaciones) -> fondo amarillo, texto naranja
  ///   'P' (Paternidad) -> fondo azul claro, texto azul oscuro
  ///
  /// Cualquier otro texto (incluyendo horas, guiones, etc.) devuelve
  /// null, indicando que no hay color de ausencia especial.
  ///
  /// [texto] - El contenido de la celda (generalmente 1 caracter).
  /// Devuelve una tupla (colorFondo, colorTexto) o null.
  (PdfColor, PdfColor)? colorAusencia(String texto) {
    switch (texto.trim()) {
      case 'B':
        return (_kBajaBg, _kBajaFg); // Baja: rojo
      case 'V':
        return (_kVacBg, _kVacFg);   // Vacaciones: ambar
      case 'P':
        return (_kPatBg, _kPatFg);   // Paternidad: azul
      default:
        return null;                  // Sin color especial
    }
  }

  // ===========================================================================
  //  CONSTRUCTOR DE CELDAS
  // ===========================================================================

  /// Crea un widget de celda para la tabla del PDF.
  ///
  /// Una celda es un contenedor con texto, opcionalmente en negrita,
  /// con alineacion configurable y colores de fondo y texto.
  ///
  /// [texto]      - El contenido textual de la celda.
  /// [bold]       - Si el texto debe mostrarse en negrita.
  /// [alineacion] - Alineacion horizontal del texto dentro de la celda.
  /// [fgColor]    - Color del texto (si es null, usa el color por
  ///                defecto del tema, que es negro).
  /// [bgColor]    - Color de fondo de la celda (si es null, sin fondo).
  /// [fontSize]   - Tamano de la fuente en puntos.
  /// Devuelve un [pw.Widget] que representa la celda.
  pw.Widget celda(
    String texto, {
    bool bold = false,
    pw.Alignment alineacion = pw.Alignment.centerLeft,
    PdfColor? fgColor,
    PdfColor? bgColor,
    double fontSize = 6.0,
  }) {
    // Construimos el contenido interno: texto con padding, alineacion
    // y estilo (fuente, negrita, color).
    final child = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Align(
        alignment: alineacion,
        child: pw.Text(
          texto,
          softWrap: true,                    // Permitir saltos de linea
          overflow: pw.TextOverflow.span,    // No recortar, solo expandir
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: fgColor,
          ),
        ),
      ),
    );

    // Si hay color de fondo, envolvemos el contenido en un Container
    // con ese color. Si no, devolvemos solo el contenido.
    return bgColor != null
        ? pw.Container(color: bgColor, child: child)
        : child;
  }

  // ===========================================================================
  //  CABECERA DE COLUMNA DE FECHA
  // ===========================================================================

  /// Dibuja la cabecera de una columna de fecha: la letra del dia
  /// arriba y el numero (dia/mes) abajo, centrados verticalmente.
  ///
  /// Si el dia correspondiente es un "dia rojo" (festivo o fin de
  /// semana), el fondo se muestra en rojo medio y el texto en rojo
  /// oscuro. En caso contrario, el fondo es azul claro y el texto
  /// azul oscuro.
  ///
  /// [col] - Indice de la columna dentro de [columnas].
  /// Devuelve un [pw.Widget] con la cabecera de fecha.
  pw.Widget celdaFechaCab(int col) {
    final esDR   = esDiaRojoCol[col];  // Es dia rojo?
    final letra  = letraCol[col];       // Letra del dia (L, M, X, ...)
    final numero = numeroCol[col];      // Numero (dia/mes)

    return pw.Container(
      // Color de fondo segun si es dia rojo o no.
      color: esDR ? _kRedMid : _kIndigoLight,

      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: pw.Column(
          // Centramos el contenido vertical y horizontalmente.
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Letra del dia (si no esta vacia).
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

            // Numero (dia/mes), o el texto original si no hay numero.
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

  // ===========================================================================
  //  FILA DE CABECERA (TITULOS DE COLUMNA)
  // ===========================================================================

  /// Crea la fila superior de la tabla con los titulos de cada columna.
  ///
  /// Las columnas de fecha usan [celdaFechaCab] para mostrar la letra
  /// del dia y el numero. Las columnas fijas y la de total usan
  /// [celda] con el texto del titulo en negrita y color azul oscuro.
  ///
  /// Devuelve un [pw.TableRow] que sirve como cabecera de la tabla.
  pw.TableRow filaColumnas() => pw.TableRow(
        // Fondo azul claro para toda la fila de cabecera.
        decoration: const pw.BoxDecoration(color: _kIndigoLight),

        // Generamos una celda por cada columna.
        children: List.generate(columnas.length, (i) {
          // Las columnas de fecha estan entre colsFijas y la ultima
          // (que es Total).
          final esFecha = i >= colsFijas && i < columnas.length - 1;

          if (esFecha) {
            // Celda especial de fecha con letra y numero.
            return celdaFechaCab(i);
          }

          // Celda normal de texto para columnas fijas y Total.
          return celda(
            columnas[i],
            bold: true,
            fgColor: _kIndigoDark,
            fontSize: 6.5,
            alineacion: i == columnas.length - 1
                ? pw.Alignment.center   // Total centrado
                : pw.Alignment.centerLeft, // Demas alineadas a la izquierda
          );
        }),
      );

  // ===========================================================================
  //  FILA DE DATOS
  // ===========================================================================

  /// Crea una fila de datos de la tabla, que puede ser un operario
  /// normal o una fila de subtotal de obra.
  ///
  /// Aplica colores especiales segun:
  ///   - Si la fila es subtotal: fondo verde claro, texto verde oscuro.
  ///   - Si la celda es de fecha y contiene un codigo de ausencia:
  ///     color especifico (B, V, P).
  ///   - Si la celda es de fecha y es dia rojo: fondo rojo claro,
  ///     texto rojo (oscuro si tiene horas, claro si es solo '-').
  ///   - Si la celda es de fecha y no tiene horas: texto gris claro.
  ///   - Columnas fijas: la categoria se muestra en gris oscuro.
  ///
  /// [fila]       - Los datos de la fila como lista de strings.
  /// [idxLocal]   - Indice local de la fila dentro de su bloque
  ///                (se usa para el efecto cebra).
  /// [esSubtotal] - true si esta fila es un subtotal de obra.
  /// Devuelve un [pw.TableRow] listo para anadir a la tabla.
  pw.TableRow buildFila(List<String> fila, int idxLocal, {required bool esSubtotal}) {
    // Color de fondo de la fila: verde para subtotales, blanco/gris
    // claro alternado para filas normales (efecto cebra).
    final rowBg = esSubtotal
        ? _kSubtotalBg
        : (idxLocal.isEven ? PdfColors.white : _kGrey50);

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: rowBg),

      // Convertimos cada elemento de la fila en una celda.
      children: fila.asMap().entries.map((e) {
        final col   = e.key;    // Indice de columna
        final texto = e.value;  // Contenido de la celda

        // Determinamos el tipo de columna.
        final esFecha = col >= colsFijas && col < fila.length - 1;
        final esTotal = col == fila.length - 1;
        final esDR    = esDiaRojoCol[col];

        // ------------------------------------------------------------------
        //  CASO 1: Fila de subtotal
        // ------------------------------------------------------------------
        if (esSubtotal) {
          // Si la celda es de fecha y ademas es dia rojo, fondo rojo claro.
          final cellBg = (esFecha && esDR) ? _kRedLight : null;

          return celda(
            texto,
            bold: true,
            fgColor: _kSubtotalFg,       // Texto verde oscuro
            bgColor: cellBg,
            fontSize: 6.5,
            alineacion: (esFecha || esTotal)
                ? pw.Alignment.center     // Fechas y Total centrados
                : pw.Alignment.centerLeft, // Demas a la izquierda
          );
        }

        // ------------------------------------------------------------------
        //  CASO 2: Celda de fecha en fila normal
        // ------------------------------------------------------------------
        if (esFecha) {
          // Verificamos si hay un codigo de ausencia (B, V, P).
          final aus = colorAusencia(texto);

          if (aus != null) {
            // Celda con codigo de ausencia: colores especificos.
            return celda(
              texto,
              bold: true,
              fgColor: aus.$2,            // Color de texto de la ausencia
              bgColor: aus.$1,            // Color de fondo de la ausencia
              fontSize: 6.0,
              alineacion: pw.Alignment.center,
            );
          }

          if (esDR) {
            // Dia rojo sin ausencia.
            // Si tiene contenido (no es '-'), mostramos las horas en
            // rojo oscuro y negrita. Si es '-', lo mostramos en rojo
            // claro (menos enfasis).
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

          // Dia normal (no rojo, no ausencia).
          return celda(
            texto,
            bold: texto != '-' && texto.isNotEmpty,
            fgColor: (texto == '-' || texto.isEmpty) ? _kGrey400 : PdfColors.black,
            fontSize: 6.0,
            alineacion: pw.Alignment.center,
          );
        }

        // ------------------------------------------------------------------
        //  CASO 3: Celda de Total (ultima columna)
        // ------------------------------------------------------------------
        if (esTotal) {
          return celda(
            texto,
            bold: true,
            fgColor: _kIndigo,           // Azul medio
            fontSize: 6.5,
            alineacion: pw.Alignment.center,
          );
        }

        // ------------------------------------------------------------------
        //  CASO 4: Columnas fijas (Codigo, Operario, Categoria, Obra)
        // ------------------------------------------------------------------
        return celda(
          texto,
          fgColor: col == 2 ? _kGrey600 : PdfColors.black, // Categoria en gris
          fontSize: 6.0,
        );
      }).toList(),
    );
  }

  // ===========================================================================
  //  AGRUPACION DE FILAS EN BLOQUES POR OBRA
  // ===========================================================================

  /// Agrupa las filas de la tabla en bloques, donde cada bloque
  /// representa una obra completa: cabecera de obra (opcional),
  /// operarios de esa obra y subtotal.
  ///
  /// Esta agrupacion es necesaria para que cada obra se renderice
  /// como un bloque inseparable ([pw.Inseparable]) y no se parta
  /// entre dos paginas del PDF.
  ///
  /// Una fila se considera cabecera de obra si:
  ///   - No es subtotal.
  ///   - Su primera columna no esta vacia.
  ///   - Todas las demas columnas estan vacias.
  ///
  /// Una fila es subtotal si su indice esta en el conjunto [subtotales].
  ///
  /// Devuelve una lista de bloques, donde cada bloque es una lista
  /// de mapas con los campos: fila (List<String>), esSubtotal (bool)
  /// y esCabecera (bool).
  List<List<({List<String> fila, bool esSubtotal, bool esCabecera})>> agruparBloques() {
    // Lista de todos los bloques.
    final bloques = <List<({List<String> fila, bool esSubtotal, bool esCabecera})>>[];

    // Bloque actual que estamos construyendo (puede ser null).
    List<({List<String> fila, bool esSubtotal, bool esCabecera})>? bloque;

    for (int i = 0; i < filas.length; i++) {
      final fila = filas[i];
      final esSubtotal = subtotales.contains(i);

      // Determinamos si esta fila es una cabecera de obra.
      // Una cabecera tiene la primera columna con texto y todas las
      // demas columnas vacias. Ademas, no debe ser subtotal.
      final esCabecera = !esSubtotal &&
          fila[0].isNotEmpty &&
          fila.skip(1).every((c) => c.isEmpty);

      if (esCabecera) {
        // Si encontramos una nueva cabecera, cerramos el bloque
        // anterior (si existe) y empezamos uno nuevo.
        if (bloque != null) bloques.add(bloque);
        bloque = [(fila: fila, esSubtotal: false, esCabecera: true)];
      } else {
        // Fila normal o subtotal: la anyadimos al bloque actual.
        bloque ??= []; // Si no hay bloque, creamos uno nuevo.
        bloque.add((fila: fila, esSubtotal: esSubtotal, esCabecera: false));

        // Si es subtotal, cerramos el bloque (el subtotal es siempre
        // la ultima fila de una obra).
        if (esSubtotal) {
          bloques.add(bloque);
          bloque = null;
        }
      }
    }

    // Anyadimos el ultimo bloque si quedo abierto.
    if (bloque != null && bloque.isNotEmpty) bloques.add(bloque);

    return bloques;
  }

  // ===========================================================================
  //  CONSTRUCCION DE BLOQUE DE OBRA
  // ===========================================================================

  /// Crea un widget visual para un bloque de obra completo.
  ///
  /// Un bloque incluye:
  ///   - La cabecera de obra (opcional, fondo azul oscuro con texto blanco).
  ///   - Las filas de operarios de esa obra.
  ///   - La fila de subtotal (si existe).
  ///
  /// El bloque entero se envuelve en un [pw.Inseparable] para que
  /// no se divida entre dos paginas del PDF.
  ///
  /// [bloque] - Lista de elementos del bloque, donde cada elemento
  ///            tiene la fila, si es subtotal y si es cabecera.
  /// Devuelve un [pw.Widget] con la tabla completa del bloque.
  pw.Widget buildBloqueObra(
    List<({List<String> fila, bool esSubtotal, bool esCabecera})> bloque,
  ) {
    final rows = <pw.TableRow>[];
    int idxLocal = 0; // Contador local de filas (para efecto cebra)

    for (final item in bloque) {
      if (item.esCabecera) {
        // Fila de cabecera de obra: fondo azul oscuro, texto blanco,
        // todas las celdas en negrita y fuente un poco mas grande.
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
        // Fila normal o subtotal: usamos buildFila.
        rows.add(buildFila(item.fila, idxLocal, esSubtotal: item.esSubtotal));

        // Solo incrementamos el contador si no es subtotal (para que
        // el efecto cebra sea consistente entre obras).
        if (!item.esSubtotal) idxLocal++;
      }
    }

    // Envolvemos todo el bloque en Inseparable para que no se parta
    // entre paginas. Si el bloque es mas alto que una pagina, se
    // partira igualmente (Inseparable solo asegura que no se parta
    // si cabe en una pagina).
    return pw.Inseparable(
      child: pw.Table(
        columnWidths: anchos(),
        border: pw.TableBorder.all(color: _kGrey200, width: 0.4),
        children: rows,
      ),
    );
  }

  // ===========================================================================
  //  LEYENDA
  // ===========================================================================

  /// Crea un elemento individual de la leyenda.
  ///
  /// Cada elemento es una fila horizontal con:
  ///   - Un recuadro pequeno del color de fondo, con una letra o
  ///     texto corto (B, V, P, S/D) en el color de texto correspondiente.
  ///   - Una etiqueta explicativa al lado.
  ///
  /// [letra] - Texto corto que identifica el codigo (ej. "B", "V").
  /// [bg]    - Color de fondo del recuadro.
  /// [fg]    - Color del texto dentro del recuadro.
  /// [label] - Texto explicativo (ej. "Baja", "Vacaciones").
  /// Devuelve un [pw.Widget] con el elemento de leyenda.
  pw.Widget leyendaItem(String letra, PdfColor bg, PdfColor fg, String label) =>
      pw.Row(children: [
        // Recuadro de color con la letra.
        pw.Container(
          width: 14,
          height: 10,
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
        // Espacio entre recuadro y etiqueta.
        pw.SizedBox(width: 3),
        // Etiqueta explicativa.
        pw.Text(label, style: const pw.TextStyle(fontSize: 6, color: _kGrey600)),
      ]);

  /// Crea la leyenda completa con los significados de los codigos
  /// de ausencia y del marcador de dias festivos/fin de semana.
  ///
  /// La leyenda se muestra en la cabecera del PDF, a la derecha
  /// del titulo, y contiene:
  ///   - B: Baja laboral
  ///   - V: Vacaciones
  ///   - P: Paternidad
  ///   - S/D: Fin de semana / Festivo (Sabado o Domingo)
  ///
  /// Devuelve un [pw.Widget] con todos los elementos en horizontal.
  pw.Widget leyenda() => pw.Row(children: [
        leyendaItem('B',   _kBajaBg,   _kBajaFg,  'Baja'),
        pw.SizedBox(width: 10),
        leyendaItem('V',   _kVacBg,    _kVacFg,   'Vacaciones'),
        pw.SizedBox(width: 10),
        leyendaItem('P',   _kPatBg,    _kPatFg,   'Paternidad'),
        pw.SizedBox(width: 10),
        leyendaItem('S/D', _kRedLight, _kRedDark, 'Fin de semana / Festivo'),
      ]);

  // ===========================================================================
  //  MONTAR LA PAGINA Y GENERAR EL PDF
  // ===========================================================================

  // Anyadimos una pagina al documento usando MultiPage, que maneja
  // automaticamente el salto de pagina cuando el contenido excede
  // el espacio disponible. El formato es A4 apaisado (landscape)
  // para que la tabla quepa correctamente.
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 24),

      // ------------------------------------------------------------------
      //  CABECERA DE PAGINA
      // ------------------------------------------------------------------
      //  Se repite en todas las paginas. Incluye:
      //    - Titulo del documento (izquierda)
      //    - Fecha de generacion (izquierda, debajo del titulo)
      //    - Leyenda de colores (derecha)
      //    - Linea divisoria
      // ------------------------------------------------------------------
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Fila superior: titulo (izquierda) + leyenda (derecha).
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Columna izquierda: titulo y fecha.
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Titulo del documento en grande y negrita.
                    pw.Text(titulo,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: _kIndigoDark)),
                    pw.SizedBox(height: 2),
                    // Fecha y hora de generacion.
                    pw.Text(
                      'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(ahora)}',
                      style: const pw.TextStyle(fontSize: 7, color: _kGrey600),
                    ),
                  ],
                ),
              ),
              // Columna derecha: leyenda de codigos.
              leyenda(),
            ],
          ),
          pw.SizedBox(height: 4),
          // Linea divisoria entre cabecera y contenido.
          pw.Divider(color: _kIndigo, thickness: 1),
          pw.SizedBox(height: 4),
        ],
      ),

      // ------------------------------------------------------------------
      //  PIE DE PAGINA
      // ------------------------------------------------------------------
      //  Se repite en todas las paginas. Incluye:
      //    - Titulo del documento (izquierda)
      //    - Numeracion de pagina (derecha): "Pag. X / Y"
      // ------------------------------------------------------------------
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(titulo,
              style: const pw.TextStyle(fontSize: 6, color: _kGrey600)),
          pw.Text('Pag. ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6, color: _kGrey600)),
        ],
      ),

      // ------------------------------------------------------------------
      //  CONTENIDO DE LA PAGINA
      // ------------------------------------------------------------------
      build: (context) {
        // Agrupamos las filas en bloques de obra.
        final bloques = agruparBloques();

        return [
          // Primero, la fila de cabecera de columnas (titulos).
          // Se muestra una sola vez al inicio del contenido.
          pw.Table(
            columnWidths: anchos(),
            border: pw.TableBorder.all(color: _kGrey200, width: 0.4),
            children: [filaColumnas()],
          ),

          // Luego, un bloque por cada obra. Cada bloque es
          // inseparable, por lo que no se partira entre paginas
          // (a menos que sea mas alto que una pagina completa).
          for (final bloque in bloques) buildBloqueObra(bloque),
        ];
      },
    ),
  );

  // ===========================================================================
  //  DESCARGA DEL PDF EN EL NAVEGADOR
  // ===========================================================================
  //  Convertimos el documento PDF en un array de bytes, creamos un
  //  objeto Blob en el navegador, generamos una URL temporal y
  //  simulamos un clic en un enlace para iniciar la descarga.
  //  Finalmente, liberamos la URL temporal para evitar fugas de memoria.
  // ===========================================================================

  // Obtenemos los bytes del PDF generado.
  final bytes = await pdf.save();

  // Creamos un Blob con los bytes, indicando que es un PDF.
  final blob = html.Blob([bytes], 'application/pdf');

  // Generamos una URL temporal que apunta al Blob.
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Creamos un elemento <a> invisible, le asignamos la URL y el
  // nombre de archivo, y simulamos un clic para iniciar la descarga.
  html.AnchorElement(href: url)
    ..setAttribute('download', '$titulo.pdf')
    ..click();

  // Liberamos la URL temporal para que el recolector de basura
  // del navegador pueda limpiar el Blob de memoria.
  html.Url.revokeObjectUrl(url);
}
