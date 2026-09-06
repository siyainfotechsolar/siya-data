import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class FileDownloadUtils {
  /// Triggers browser/system download for a CSV string using data URI
  static Future<bool> downloadCsv({
    required String fileName,
    required String csvContent,
  }) async {
    try {
      final uri = Uri.dataFromString(
        csvContent,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
