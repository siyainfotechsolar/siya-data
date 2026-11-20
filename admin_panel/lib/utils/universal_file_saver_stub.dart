import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<String?> saveFileUniversal({
  required Uint8List bytes,
  required String fileName,
  String? dialogTitle,
  String? mimeType,
}) async {
  List<String>? allowedExtensions;
  FileType fileType = FileType.any;
  if (fileName.contains('.')) {
    final ext = fileName.split('.').last.toLowerCase();
    allowedExtensions = [ext];
    fileType = FileType.custom;
  }

  final result = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle ?? 'Save File',
    fileName: fileName,
    type: fileType,
    allowedExtensions: allowedExtensions,
    bytes: bytes,
  );
  if (result != null) {
    final file = File(result);
    await file.writeAsBytes(bytes);
    return result;
  }
  return null;
}
