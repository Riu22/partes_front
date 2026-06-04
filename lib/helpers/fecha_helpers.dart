// =============================================================================
//  fecha_helpers.dart  -  HELPER DE FORMATEO DE FECHAS
// =============================================================================
//  QUE ES UN HELPER?
//  En esta aplicacion, un "helper" es una herramienta o modulo ligero que
//  encapsula una funcionalidad especifica (descargar archivos, capturar
//  pantallas, obtener la URL, formatear fechas, etc.) y la expone
//  mediante funciones simples. Los helpers se encargan de los detalles
//  de implementacion para que el resto de la aplicacion no tenga que
//  repetir codigo.
//
//  QUE HACE ESTE ARCHIVO?
//  Proporciona funciones de utilidad para convertir objetos DateTime
//  a cadenas de texto en diferentes formatos. Es un helper puro
//  (no depende de la plataforma), por lo que tiene una unica
//  implementacion que funciona en web, movil y escritorio.
//
//  FORMATOS DISPONIBLES:
//    - fmtDMY:  dia/mes/ano (ej. "03/02/2026")
//    - fmtYMD:  ano-mes-dia (ej. "2026-02-03")
//
//  USO TIPICO:
//    - fmtDMY  se usa para mostrar fechas en la interfaz de usuario
//              (tablas, listados, PDFs).
//    - fmtYMD  se usa para nombres de archivo y ordenacion lexicografica
//              (porque al ordenar alfabeticamente, 2026-02-03 < 2026-03-01).
// =============================================================================

/// Convierte una fecha (DateTime) al formato dia/mes/ano.
///
/// El resultado siempre tiene dos digitos para el dia y el mes,
/// y cuatro digitos para el ano. Ejemplo: "03/02/2026".
///
/// Parametros:
///   [d] - El objeto DateTime que se quiere formatear.
///
/// Devuelve un String con el formato DD/MM/AAAA.
///
/// USO:
///   Se usa principalmente para mostrar fechas en la interfaz de
///   usuario (tablas, listados, PDFs), donde el formato europeo
///   es el estandar.
String fmtDMY(DateTime d) =>
    // Convertimos dia, mes y ano a string, rellenando con ceros
    // a la izquierda si es necesario (padLeft), y los separamos
    // con barras.
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Convierte una fecha (DateTime) al formato ano-mes-dia.
///
/// El resultado siempre tiene cuatro digitos para el ano y dos
/// digitos para el mes y el dia. Ejemplo: "2026-02-03".
///
/// Parametros:
///   [d] - El objeto DateTime que se quiere formatear.
///
/// Devuelve un String con el formato AAAA-MM-DD.
///
/// USO:
///   Este formato es ideal para:
///     - Nombres de archivo (ej. "partes_2026-02-03.csv")
///     - Ordenacion lexicografica (una cadena YYYY-MM-DD se ordena
///       correctamente como texto sin necesidad de convertir a fecha).
///     - Intercambio de datos con APIs y bases de datos (ISO 8601).
String fmtYMD(DateTime d) =>
    // Ano completo, luego mes con dos digitos, luego dia con dos
    // digitos, separados por guiones.
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
