import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser "Save As" download for the given bytes. Flutter-web only.
void saveFile(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}