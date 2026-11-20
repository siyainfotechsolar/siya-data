import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> saveFileUniversal({
  required Uint8List bytes,
  required String fileName,
  String? dialogTitle,
}) async {
  final result = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle ?? 'Save File',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    bytes: bytes,
  );
  if (result != null) {
    final file = File(result);
    await file.writeAsBytes(bytes);
    return result;
  }
  return null;
}
