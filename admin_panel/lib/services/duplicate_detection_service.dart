import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/record_diff.dart';
import 'supabase_service.dart';

class DuplicateDetectionService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Analyze incoming records against existing database records to detect duplicates and field differences
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

    // 3. Classify records and calculate field diffs strictly for allowed update columns
    final newRecords = <ConsumerRecord>[];
    final identicalRecords = <ConsumerRecord>[];
    final conflictRecords = <RecordDiff>[];

    for (final incoming in incomingRecords) {
      final normalizedNo = incoming.consumerNo.trim().toUpperCase();
      final existing = existingRecordsMap[normalizedNo];

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
          // Differences in skipped columns do not trigger conflict/update!
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

    check('name', 'Consumer Name', existing.name, incoming.name);
    check('mobile', 'Mobile Number', existing.mobile, incoming.mobile);
    check('address', 'Address', existing.address, incoming.address);
    check('application_id', 'Application ID', existing.applicationId, incoming.applicationId);
    check('status', 'Status', existing.status, incoming.status);
    check('remarks', 'Remarks', existing.remarks, incoming.remarks);

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
