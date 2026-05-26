// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String getCurrentUrl(Uri fallback) {
  return html.window.location.href;
}