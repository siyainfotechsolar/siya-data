class SharedDocument {
  final String filePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String fileHash;
  final String source;
  final DateTime receivedAt;
  final String? extraText;
  final String? extraSubject;

  const SharedDocument({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.fileHash,
    this.source = 'WhatsApp Share',
    required this.receivedAt,
    this.extraText,
    this.extraSubject,
  });

  bool get isPdf =>
      mimeType.toLowerCase().contains('pdf') ||
      fileName.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      mimeType.toLowerCase().contains('image') ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.webp');

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileNameWithoutExtension {
    final idx = fileName.lastIndexOf('.');
    if (idx == -1) return fileName;
    return fileName.substring(0, idx);
  }

  factory SharedDocument.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['receivedAt'] as String? ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return SharedDocument(
      filePath: map['filePath'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'document',
      mimeType: map['mimeType'] as String? ?? 'application/pdf',
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      fileHash: map['fileHash'] as String? ?? '',
      source: map['source'] as String? ?? 'WhatsApp Share',
      receivedAt: parsedDate,
      extraText: map['extraText'] as String?,
      extraSubject: map['extraSubject'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'fileHash': fileHash,
      'source': source,
      'receivedAt': receivedAt.toIso8601String(),
      'extraText': extraText,
      'extraSubject': extraSubject,
    };
  }
}
