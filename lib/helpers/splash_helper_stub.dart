// =============================================================================
//  splash_helper_stub.dart  -  HELPER DE SPLASH (VERSION STUB / RELLENO)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona una implementacion de "relleno" (stub) del helper que
//  oculta la pantalla de bienvenida (splash). En plataformas que no
//  son web (movil, escritorio), el splash lo maneja el sistema
//  operativo o el motor de Flutter de forma nativa, por lo que no
//  es necesario hacer nada desde Dart.
//
//  POR QUE ES NECESARIO UN STUB?
//  En Dart, cuando se usa export condicional (ver splash_helper.dart),
//  T O D A S las plataformas deben tener una implementacion disponible
//  en tiempo de compilacion. El stub sirve como "plan B" para las
//  plataformas que no sean web.
//
//  CONTRATO:
//  Sigue la misma firma que la version web para mantener la interfaz
//  unificada. El resto de la aplicacion no nota la diferencia porque
//  ambas usan el mismo nombre de funcion: ocultarSplash.
// =============================================================================

/// Intenta ocultar la pantalla de bienvenida (splash screen).
///
/// En plataformas que no son web (Android, iOS, Windows, Linux, macOS),
/// esta funcion no hace nada porque el splash lo maneja el sistema
/// operativo de forma nativa y Flutter no necesita intervenir.
///
/// Esta implementacion existe solo para cumplir con el contrato de
/// la interfaz y permitir que la aplicacion compile en todas las
/// plataformas.
void ocultarSplash() {
  // En movil y escritorio, no hay nada que ocultar desde Dart.
  // El splash se oculta automaticamente cuando Flutter termina
  // de cargar. Esta funcion se deja intencionadamente vacia.
}
