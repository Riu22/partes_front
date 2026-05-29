import 'dart:js_interop';

void ocultarSplash() {
  final g = globalThis;
  if (g != null) {
    (g as JSObject).callMethod('hideSplash'.toJS);
  }
}
