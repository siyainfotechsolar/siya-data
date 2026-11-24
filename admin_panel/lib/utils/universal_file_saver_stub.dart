import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<String?> saveFileUniversal({
  required Uint8List bytes,
  required String fileName,
  String? dialogTitle,
}) async {
  if (kIsWeb) {
    return null;
  }
  try {
    final lower = fileName.toLowerCase();
    final List<String> ext;
    if (lower.endsWith('.pdf')) {
      ext = ['pdf'];
    } else if (lower.endsWith('.xlsx')) {
      ext = ['xlsx'];
    } else if (lower.endsWith('.csv')) {
      ext = ['csv'];
    } else {
      ext = ['xlsx', 'csv', 'pdf'];
    }
    final result = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle ?? 'Save File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ext,
      bytes: bytes,
    );
    if (result != null) {
      final file = File(result);
      await file.writeAsBytes(bytes);
      return result;
    }
  } catch (e) {
    debugPrint('saveFileUniversal desktop error: $e');
  }
  return null;
}
