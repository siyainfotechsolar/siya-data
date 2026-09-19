class ConsumerNoNormalizer {
  /// Normalize a Consumer Number for accurate duplicate detection and matching.
  ///
  /// Normalization rules:
  /// 1. Convert to string and handle nulls.
  /// 2. Trim leading/trailing whitespace.
  /// 3. Strip trailing '.0' from numeric floating-point Excel cells.
  /// 4. Remove quotes, apostrophes, backticks, spaces, hyphens, and non-alphanumeric punctuation.
  /// 5. Convert to uppercase for case-insensitive matching.
  static String normalize(String? raw) {
    if (raw == null) return '';
    String s = raw.trim();
    if (s.isEmpty) return '';

    // Strip trailing .0 if numeric float string from Excel (e.g., "110014099875.0")
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }

    // Remove all quotes, apostrophes, spaces, hyphens, and non-word characters
    s = s.replaceAll(RegExp(r'[^\w]+'), '');

    // Convert to uppercase for normalized comparison
    return s.toUpperCase();
  }

  /// Check if two raw Consumer Numbers are normalized duplicates
  static bool isDuplicate(String? a, String? b) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA.isEmpty || normB.isEmpty) return false;
    return normA == normB;
  }
}
