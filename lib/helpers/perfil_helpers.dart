// =============================================================================
//  perfil_helpers.dart  -  HELPER DE ORDENACION Y FILTRO DE PERFILES
// =============================================================================
//  QUE ES UN HELPER?
//  En esta aplicacion, un "helper" es una herramienta o modulo ligero que
//  encapsula una funcionalidad especifica y la expone mediante funciones
//  simples. Los helpers se encargan de los detalles de implementacion
//  para que el resto de la aplicacion no tenga que repetir codigo.
//
//  QUE HACE ESTE ARCHIVO?
//  Proporciona funciones para ordenar y filtrar la lista de perfiles
//  de trabajadores (operarios). La funcionalidad principal es:
//    1. Normalizar apellidos: eliminar tildes y convertir la letra 'n'
//       con virgulilla ('n') a 'n' para que la ordenacion alfabetica
//       sea correcta en espanol.
//    2. Ordenar perfiles: filtrar solo los activos y ordenarlos por
//       apellido alfabeticamente usando la normalizacion.
//
//  POR QUE ES NECESARIA LA NORMALIZACION?
//  En espanol, las vocales con tilde (a, e, i, o, u) y la 'n' tienen
//  codigos Unicode diferentes a sus versiones sin tilde o con 'n'.
//  Si se ordena directamente con compareTo de String, "Alvarez"
//  apareceria antes que "Alvarez" (con tilde) porque 'a' (Unicode 225)
//  va despues de 'z' (Unicode 122). La normalizacion resuelve esto.
//
//  DEPENDENCIAS:
//    - ../models/perfil.dart (clase Perfil con campos como apellidos, activo)
// =============================================================================

import '../models/perfil.dart'; // Modelo de datos de perfil de trabajador

/// Normaliza un texto (tipicamente un apellido) eliminando tildes
/// y convirtiendo la 'n' en 'n', y pasandolo a minusculas.
///
/// Esto permite ordenar alfabeticamente de forma correcta en espanol,
/// donde "Alvarez" y "Alvarez" deben intercalarse correctamente y
/// "Munoz" debe tratarse como "Munoz".
///
/// Transformaciones que aplica:
///   - a, e, i, o, u con tilde -> a, e, i, o, u sin tilde
///   - u con dieresis (u) -> u
///   - n (n con virgulilla) -> n
///   - Todo el texto se pasa a minusculas
///
/// Parametros:
///   [s] - El texto a normalizar (generalmente el apellido completo).
///
/// Devuelve el texto normalizado, en minusculas y sin caracteres
/// especiales del espanol.
///
/// EJEMPLOS:
///   "Alvarez"     -> "alvarez"
///   "Alvarez"     -> "alvarez"  (se ordena junto al anterior)
///   "Nunez"       -> "nunez"
///   "Munoz"       -> "munoz"
///   "Garcia"      -> "garcia"
///   "Perez"       -> "perez"
///   "Benitez"     -> "benitez"
String normalizarApellido(String s) => s
    .toLowerCase()                         // Todo a minusculas
    .replaceAll('á', 'a')                  // a con tilde -> a
    .replaceAll('é', 'e')                  // e con tilde -> e
    .replaceAll('í', 'i')                  // i con tilde -> i
    .replaceAll('ó', 'o')                  // o con tilde -> o
    .replaceAll('ú', 'u')                  // u con tilde -> u
    .replaceAll('ü', 'u')                  // u con dieresis -> u
    .replaceAll('ñ', 'n');                 // n con virgulilla -> n

/// Filtra los perfiles de trabajadores dejando solo aquellos que
/// estan activos, y los ordena alfabeticamente por apellido usando
/// la funcion [normalizarApellido] para garantizar un orden correcto
/// en espanol.
///
/// Parametros:
///   [perfiles] - Lista completa de perfiles (activos e inactivos).
///
/// Devuelve una nueva lista (no modifica la original) con solo los
/// perfiles activos, ordenados alfabeticamente por apellido.
///
/// NOTA:
///   - Se usa el operador spread (...) para crear una copia de la
///     lista filtrada antes de ordenarla. Esto evita modificar la
///     lista original.
///   - La ordenacion se hace in-situ con .sort() sobre la nueva lista.
List<Perfil> ordenarPerfiles(List<Perfil> perfiles) =>
    // Creamos una nueva lista con solo los perfiles activos.
    [...perfiles.where((p) => p.activo)]

      // Ordenamos la nueva lista comparando los apellidos normalizados.
      // El metodo sort modifica la lista in-situ (no crea una nueva).
      ..sort(
        (a, b) => normalizarApellido(
          a.apellidos,
        ).compareTo(normalizarApellido(b.apellidos)),
      );
