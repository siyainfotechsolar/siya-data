import 'consumer_record.dart';

enum DuplicateMatchType {
  exactMatch('EXACT MATCH', 'Identical Consumer Numbers'),
  formattingVariation('FORMATTING VARIATION', 'Leading quotes/spaces/hyphens match'),
  possibleMatch('POSSIBLE MATCH', 'Matching normalized attributes');

  final String label;
  final String description;

  const DuplicateMatchType(this.label, this.description);
}

class DuplicateGroup {
  final String normalizedConsumerNo;
  final List<ConsumerRecord> records;
  final DuplicateMatchType matchType;

  DuplicateGroup({
    required this.normalizedConsumerNo,
    required this.records,
    required this.matchType,
  });

  int get recordCount => records.length;

  /// Returns the oldest application date/submit date among members
  DateTime? get oldestSubmitDate {
    DateTime? oldest;
    for (final r in records) {
      final date = r.submitDate ?? r.createdAt;
      if (date != null) {
        if (oldest == null || date.isBefore(oldest)) {
          oldest = date;
        }
      }
    }
    return oldest;
  }

  /// Calculates max application days in group
  int get maxApplicationDays {
    int maxDays = 0;
    for (final r in records) {
      if (r.applicationDays > maxDays) {
        maxDays = r.applicationDays;
      }
    }
    return maxDays;
  }
}
