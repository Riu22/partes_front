import 'dart:js' as js;

void ocultarSplash() {
  if (js.context.hasProperty('hideSplash')) {
    js.context.callMethod('hideSplash');
  }
}
