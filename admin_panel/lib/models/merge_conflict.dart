enum MergeFieldState {
  match, // Master & Duplicate values are identical
  empty, // Master or Duplicate is empty (auto-resolvable)
  conflict, // Both records have different non-empty values
}

enum MergeStrategy {
  keepMaster,
  useDuplicate,
  custom,
}

class MergeConflictField {
  final String fieldKey;
  final String fieldLabel;
  final String masterValue;
  final String duplicateValue;
  final MergeFieldState state;

  MergeStrategy strategy;
  String customValue;

  MergeConflictField({
    required this.fieldKey,
    required this.fieldLabel,
    required this.masterValue,
    required this.duplicateValue,
    required this.state,
    MergeStrategy? initialStrategy,
    String? initialCustomValue,
  })  : strategy = initialStrategy ?? (masterValue.trim().isNotEmpty ? MergeStrategy.keepMaster : MergeStrategy.useDuplicate),
        customValue = initialCustomValue ?? masterValue;

  String get resolvedValue {
    switch (strategy) {
      case MergeStrategy.keepMaster:
        return masterValue.trim().isEmpty ? duplicateValue.trim() : masterValue.trim();
      case MergeStrategy.useDuplicate:
        return duplicateValue.trim().isEmpty ? masterValue.trim() : duplicateValue.trim();
      case MergeStrategy.custom:
        return customValue.trim();
    }
  }

  factory MergeConflictField.compare({
    required String fieldKey,
    required String fieldLabel,
    required String? masterVal,
    required String? duplicateVal,
  }) {
    final m = masterVal?.trim() ?? '';
    final d = duplicateVal?.trim() ?? '';

    MergeFieldState state;
    if (m == d) {
      state = MergeFieldState.match;
    } else if (m.isEmpty || d.isEmpty) {
      state = MergeFieldState.empty;
    } else {
      state = MergeFieldState.conflict;
    }

    final initialStrategy = m.isNotEmpty ? MergeStrategy.keepMaster : MergeStrategy.useDuplicate;

    return MergeConflictField(
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      masterValue: m,
      duplicateValue: d,
      state: state,
      initialStrategy: initialStrategy,
      initialCustomValue: m.isNotEmpty ? m : d,
    );
  }
}
