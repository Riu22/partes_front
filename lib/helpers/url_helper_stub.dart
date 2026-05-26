// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart';

String getCurrentUrl(Uri fallback) {
  if (kIsWeb) {
    // ignore: avoid_web_libraries_in_flutter
    return _getWebUrl();
  }
  return fallback.toString();
}

String _getWebUrl() {
  // Esta función solo se llama en web, pero para que compile en Android
  // necesitamos el stub. Ver url_helper_web.dart y url_helper_stub.dart
  throw UnsupportedError('No implementado');
}