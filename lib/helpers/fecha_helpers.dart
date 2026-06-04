/// Funciones útiles para convertir fechas (DateTime) a texto
/// en diferentes formatos.

/// Convierte una fecha al formato día/mes/año (ej. "03/02/2026").
///
/// - [d]: la fecha a convertir
/// Devuelve un texto con el formato DD/MM/AAAA
String fmtDMY(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Convierte una fecha al formato año-mes-día (ej. "2026-02-03").
///
/// - [d]: la fecha a convertir
/// Devuelve un texto con el formato AAAA-MM-DD
String fmtYMD(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
