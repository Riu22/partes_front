/// Versión para web del helper de splash.
/// Oculta la pantalla de bienvenida llamando a una función JavaScript.

import 'dart:js' as js;

/// Oculta la pantalla de bienvenida (splash) en la web.
/// Llama a la función `hideSplash()` que debe existir en el código JavaScript
/// de la página. Si no existe, no hace nada.
void ocultarSplash() {
  if (js.context.hasProperty('hideSplash')) {
    js.context.callMethod('hideSplash');
  }
}
