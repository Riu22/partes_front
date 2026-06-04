// =============================================================================
//  url_helper_stub.dart  -  HELPER DE URL (VERSION STUB / RELLENO)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona una implementacion de "relleno" (stub) del helper que
//  obtiene la URL actual. En plataformas que no son web (movil,
//  escritorio), no existe el concepto de "URL actual" porque la app
//  no se ejecuta en un navegador. En su lugar, se devuelve una URL
//  de fallback proporcionada por quien llama a la funcion.
//
//  POR QUE ES NECESARIO UN STUB?
//  En Dart, cuando se usa export condicional (ver url_helper.dart),
//  T O D A S las plataformas deben tener una implementacion disponible
//  en tiempo de compilacion. El stub sirve como "plan B" para las
//  plataformas que no sean web.
//
//  COMPORTAMIENTO ESPECIAL:
//  Aunque esta es la version "stub" (para no-web), contiene una
//  verificacion de kIsWeb por si alguien la ejecuta accidentalmente
//  en web. En ese caso, intenta llamar a una funcion interna que
//  lanza un error, dejando claro que la implementacion real esta
//  en url_helper_web.dart.
//
//  CONTRATO:
//  Sigue la misma firma que la version web para mantener la interfaz
//  unificada. El resto de la aplicacion no nota la diferencia porque
//  ambas usan el mismo nombre de funcion: getCurrentUrl.
// =============================================================================

// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart'; // kIsWeb para detectar si es web

/// Obtiene la URL actual de la aplicacion.
///
/// En plataformas que no son web, no existe una "URL actual" real,
/// por lo que se devuelve el valor de [fallback] (generalmente la
/// URL base de la API o un valor configurado en el entorno).
///
/// Si por error se ejecuta esta funcion en un navegador web (kIsWeb
/// es true), intenta delegar en [_getWebUrl], que lanza un error
/// indicando que la implementacion web real no esta disponible.
/// Esto no deberia ocurrir si el export condicional funciona bien.
///
/// Parametros:
///   [fallback] - Una URL que se devuelve si no se puede obtener
///                la URL real desde el navegador.
///
/// Devuelve la URL actual como String.
String getCurrentUrl(Uri fallback) {
  if (kIsWeb) {
    // Si alguien ejecuta esta funcion en web (por error de
    // compilacion o configuracion), intentamos la version web.
    return _getWebUrl();
  }

  // En movil/escritorio, devolvemos la URL de fallback.
  // Esta URL suele ser la direccion del servidor de la API.
  return fallback.toString();
}

/// Intenta obtener la URL desde el navegador usando dart:html.
///
/// Esta funcion esta declarada aqui solo para que la aplicacion
/// compile y para que el analizador de Dart no se queje de que
/// falta la funcion. La implementacion REAL esta en el archivo
/// url_helper_web.dart, que es el que se exporta cuando se compila
/// para web.
///
/// Si se llama a esta funcion directamente (sin pasar por la
/// export condicional), lanza un [UnsupportedError].
String _getWebUrl() {
  throw UnsupportedError(
    'La implementacion web de getCurrentUrl no esta disponible en este archivo. '
    'Usa url_helper_web.dart o el export condicional de url_helper.dart.',
  );
}
