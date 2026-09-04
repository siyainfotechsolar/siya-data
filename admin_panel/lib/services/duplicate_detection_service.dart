import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/record_diff.dart';
import '../utils/consumer_no_utils.dart';
import 'supabase_service.dart';

class DuplicateDetectionService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Analyze incoming records against existing database records using normalized Consumer No matching
  static Future<DuplicateAnalysisResult> analyzeDuplicates(
    List<ConsumerRecord> incomingRecords, {
    Set<String>? allowedFieldKeys,
    bool ignoreBlankValues = true,
  }) async {
    if (incomingRecords.isEmpty) {
      return DuplicateAnalysisResult(
        newRecords: [],
        identicalRecords: [],
        conflictRecords: [],
      );
    }

    // 1. Gather all unique normalized consumer numbers
    final normalizedNos = incomingRecords
        .map((r) => r.normalizedConsumerNo)
        .where((no) => no.isNotEmpty)
        .toSet()
        .toList();

    // 2. Fetch existing records using RPC with fallback
    final existingRecordsMap = <String, ConsumerRecord>{};
    const chunkSize = 100;

    for (int i = 0; i < normalizedNos.length; i += chunkSize) {
      final end = (i + chunkSize < normalizedNos.length) ? i + chunkSize : normalizedNos.length;
      final chunk = normalizedNos.sublist(i, end);

      try {
        // Primary strategy: Call Postgres RPC function for normalized matching
        final response = await _client.rpc(
          'match_consumer_records_by_normalized_no',
          params: {'normalized_nos': chunk},
        );

        final List<dynamic> data = response as List<dynamic>;
        for (final item in data) {
          final record = ConsumerRecord.fromJson(item as Map<String, dynamic>);
          existingRecordsMap[record.normalizedConsumerNo] = record;
        }
      } catch (_) {
        // Fallback strategy: Query by raw values and index by normalizedConsumerNo locally
        try {
          final rawResponse = await _client
              .from('consumer_records')
              .select('*')
              .eq('deleted', false);

          final List<dynamic> data = rawResponse as List<dynamic>;
          for (final item in data) {
            final record = ConsumerRecord.fromJson(item as Map<String, dynamic>);
            existingRecordsMap[record.normalizedConsumerNo] = record;
          }
        } catch (_) {}
      }
    }

    // 3. Classify records using normalized Consumer No matching
    final newRecords = <ConsumerRecord>[];
    final identicalRecords = <ConsumerRecord>[];
    final conflictRecords = <RecordDiff>[];

    for (final incoming in incomingRecords) {
      final normNo = incoming.normalizedConsumerNo;
      final existing = normNo.isEmpty ? null : existingRecordsMap[normNo];

      if (existing == null) {
        newRecords.add(incoming);
      } else {
        final diffs = computeFieldDiffs(
          existing,
          incoming,
          allowedFieldKeys: allowedFieldKeys,
          ignoreBlankValues: ignoreBlankValues,
        );

        if (diffs.isEmpty) {
          // EXACT DUPLICATE: Differences in skipped columns do not trigger conflict/update!
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

  /// Compute field-level differences between existing and incoming record, strictly restricted to allowed update fields
  static List<FieldDiff> computeFieldDiffs(
    ConsumerRecord existing,
    ConsumerRecord incoming, {
    Set<String>? allowedFieldKeys,
    bool ignoreBlankValues = false,
  }) {
    final diffs = <FieldDiff>[];

    final allowed = allowedFieldKeys ?? {
      'name',
      'mobile',
      'address',
      'application_id',
      'status',
      'remarks',
      'application_date',
      'submit_date',
    };

    void check(String key, String label, String? oldVal, String? newVal) {
      if (!allowed.contains(key)) return; // SKIPPED COLUMN: Never check or trigger diffs

      final cleanOld = oldVal?.trim() ?? '';
      final cleanNew = newVal?.trim() ?? '';

      // If ignoring blank values and incoming value is empty, don't trigger diff
      if (ignoreBlankValues && cleanNew.isEmpty) {
        return;
      }

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

    /// Check DateTime fields — compare by date-only ISO string (YYYY-MM-DD)
    void checkDate(String key, String label, DateTime? oldDate, DateTime? newDate) {
      if (!allowed.contains(key)) return; // SKIPPED COLUMN

      final oldStr = oldDate != null
          ? '${oldDate.year}-${oldDate.month.toString().padLeft(2, '0')}-${oldDate.day.toString().padLeft(2, '0')}'
          : '';
      final newStr = newDate != null
          ? '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}'
          : '';

      // If ignoring blank values and incoming date is null/empty, don't trigger diff
      if (ignoreBlankValues && newStr.isEmpty) {
        return;
      }

      if (oldStr != newStr) {
        diffs.add(
          FieldDiff(
            fieldKey: key,
            fieldLabel: label,
            oldValue: oldStr.isEmpty ? null : oldStr,
            newValue: newStr.isEmpty ? null : newStr,
          ),
        );
      }
    }

    check('name', 'Consumer Name', existing.name, incoming.name);
    check('mobile', 'Mobile Number', existing.mobile, incoming.mobile);
    check('address', 'Address', existing.address, incoming.address);
    check('application_id', 'Application ID', existing.applicationId, incoming.applicationId);
    check('status', 'Status', existing.status, incoming.status);
    check('remarks', 'Remarks', existing.remarks, incoming.remarks);

    // Date field checks (DateTime comparison)
    checkDate('application_date', 'Application Date', existing.applicationDate, incoming.applicationDate);
    checkDate('submit_date', 'Submit Date', existing.submitDate, incoming.submitDate);

    // Workflow checks
    check('application_status', 'Application Status', existing.applicationStatus, incoming.applicationStatus);
    check('agreement_status', 'Agreement Status', existing.agreementStatus, incoming.agreementStatus);
    check('loan_required', 'Loan Required', existing.loanRequired, incoming.loanRequired);
    check('loan_status', 'Loan Status', existing.loanStatus, incoming.loanStatus);
    check('installation_status', 'Installation Status', existing.installationStatus, incoming.installationStatus);
    check('installer_team', 'Installer Team', existing.installerTeam, incoming.installerTeam);
    check('rts_status', 'RTS Status', existing.rtsStatus, incoming.rtsStatus);
    check('rts_application_id', 'RTS Application ID', existing.rtsApplicationId, incoming.rtsApplicationId);
    check('subsidy_status', 'Subsidy Status', existing.subsidyStatus, incoming.subsidyStatus);

    return diffs;
  }
}
