import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String?> saveFileUniversal({
  required Uint8List bytes,
  required String fileName,
  String? dialogTitle,
}) async {
  try {
    String mimeType = 'application/octet-stream';
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      mimeType = 'application/pdf';
    } else if (lower.endsWith('.xlsx')) {
      mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (lower.endsWith('.csv')) {
      mimeType = 'text/csv;charset=utf-8';
    }
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return fileName;
  } catch (e) {
    return null;
  }
}
