import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/record_diff.dart';
import 'supabase_service.dart';

class DuplicateDetectionService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Analyze incoming records against existing database records to detect duplicates and field differences
  static Future<DuplicateAnalysisResult> analyzeDuplicates(
    List<ConsumerRecord> incomingRecords,
  ) async {
    if (incomingRecords.isEmpty) {
      return DuplicateAnalysisResult(
        newRecords: [],
        identicalRecords: [],
        conflictRecords: [],
      );
    }

    // 1. Gather all unique consumer numbers
    final consumerNos = incomingRecords
        .map((r) => r.consumerNo.trim())
        .where((no) => no.isNotEmpty)
        .toSet()
        .toList();

    // 2. Fetch existing records in chunks of 100
    final existingRecordsMap = <String, ConsumerRecord>{};
    const chunkSize = 100;

    for (int i = 0; i < consumerNos.length; i += chunkSize) {
      final end = (i + chunkSize < consumerNos.length) ? i + chunkSize : consumerNos.length;
      final chunk = consumerNos.sublist(i, end);

      try {
        final response = await _client
            .from('consumer_records')
            .select('*')
            .inFilter('consumer_no', chunk);

        final List<dynamic> data = response as List<dynamic>;
        for (final item in data) {
          final record = ConsumerRecord.fromJson(item as Map<String, dynamic>);
          existingRecordsMap[record.consumerNo.trim().toUpperCase()] = record;
        }
      } catch (e) {
        // Fallback or handle offline
      }
    }

    // 3. Classify records and calculate field diffs
    final newRecords = <ConsumerRecord>[];
    final identicalRecords = <ConsumerRecord>[];
    final conflictRecords = <RecordDiff>[];

    for (final incoming in incomingRecords) {
      final normalizedNo = incoming.consumerNo.trim().toUpperCase();
      final existing = existingRecordsMap[normalizedNo];

      if (existing == null) {
        newRecords.add(incoming);
      } else {
        final diffs = computeFieldDiffs(existing, incoming);
        if (diffs.isEmpty) {
          identicalRecords.add(existing);
        } else {
          conflictRecords.add(
            RecordDiff(
              existingRecord: existing,
              incomingRecord: incoming,
              changedFields: diffs,
              shouldUpdate: true,
            ),
          );
        }
      }
    }

    return DuplicateAnalysisResult(
      newRecords: newRecords,
      identicalRecords: identicalRecords,
      conflictRecords: conflictRecords,
    );
  }

  /// Compute field-level differences between existing and incoming record
  static List<FieldDiff> computeFieldDiffs(
    ConsumerRecord existing,
    ConsumerRecord incoming,
  ) {
    final diffs = <FieldDiff>[];

    _checkField(diffs, 'name', 'Consumer Name', existing.name, incoming.name);
    _checkField(diffs, 'mobile', 'Mobile Number', existing.mobile, incoming.mobile);
    _checkField(diffs, 'address', 'Address', existing.address, incoming.address);
    _checkField(diffs, 'application_id', 'Application ID', existing.applicationId, incoming.applicationId);
    _checkField(diffs, 'status', 'Status', existing.status, incoming.status);
    _checkField(diffs, 'remarks', 'Remarks', existing.remarks, incoming.remarks);

    return diffs;
  }

  static void _checkField(
    List<FieldDiff> diffs,
    String key,
    String label,
    String? oldVal,
    String? newVal,
  ) {
    final cleanOld = oldVal?.trim() ?? '';
    final cleanNew = newVal?.trim() ?? '';

    // If both are empty, no change
    if (cleanOld.isEmpty && cleanNew.isEmpty) return;

    if (cleanOld != cleanNew) {
      diffs.add(
        FieldDiff(
          fieldKey: key,
          fieldLabel: label,
          oldValue: oldVal?.trim(),
          newValue: newVal?.trim(),
        ),
      );
    }
  }
}
