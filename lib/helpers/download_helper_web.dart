import 'dart:html' as html;
import 'dart:typed_data';

void saveAndLaunchFile(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
