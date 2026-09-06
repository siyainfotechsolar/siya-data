import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/record_diff.dart';
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

    // 1. Gather all unique normalized consumer numbers and cleaned mobile numbers
    final normalizedNos = incomingRecords
        .map((r) => r.normalizedConsumerNo)
        .where((no) => no.isNotEmpty)
        .toSet()
        .toList();

    final mobileSet = incomingRecords
        .map((r) => r.mobile?.replaceAll(RegExp(r'[^0-9]'), '') ?? '')
        .where((m) => m.length >= 10)
        .toSet()
        .toList();

    // 2. Fetch existing records using RPC with fallback
    final existingRecordsMap = <String, ConsumerRecord>{};
    final existingMobilesMap = <String, ConsumerRecord>{};
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
          final cleanM = record.mobile?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
          if (cleanM.length >= 10) {
            existingMobilesMap[cleanM] = record;
          }
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
            final cleanM = record.mobile?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
            if (cleanM.length >= 10) {
              existingMobilesMap[cleanM] = record;
            }
          }
        } catch (_) {}
      }
    }

    // Secondary mobile query if needed for mobiles not already found
    if (mobileSet.isNotEmpty) {
      final missingMobiles = mobileSet.where((m) => !existingMobilesMap.containsKey(m)).toList();
      if (missingMobiles.isNotEmpty) {
        try {
          final mobRes = await _client
              .from('consumer_records')
              .select('*')
              .eq('deleted', false)
              .inFilter('mobile', missingMobiles);
          final List<dynamic> mobData = mobRes as List<dynamic>;
          for (final item in mobData) {
            final record = ConsumerRecord.fromJson(item as Map<String, dynamic>);
            final cleanM = record.mobile?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
            if (cleanM.length >= 10) {
              existingMobilesMap[cleanM] = record;
            }
          }
        } catch (_) {}
      }
    }

    // 3. Classify records: Primary (Consumer No), Secondary (Mobile / Name+Mobile), New
    final newRecords = <ConsumerRecord>[];
    final identicalRecords = <ConsumerRecord>[];
    final conflictRecords = <RecordDiff>[];
    final possibleDuplicateRecords = <RecordDiff>[];

    for (final incoming in incomingRecords) {
      final normNo = incoming.normalizedConsumerNo;
      final cleanMobile = incoming.mobile?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      final existing = normNo.isEmpty ? null : existingRecordsMap[normNo];

      if (existing != null) {
        // Primary Match: Same Consumer Number
        final diffs = computeFieldDiffs(
          existing,
          incoming,
          allowedFieldKeys: allowedFieldKeys,
          ignoreBlankValues: ignoreBlankValues,
        );

        if (diffs.isEmpty) {
          // DUPLICATE: Exactly identical data in database
          identicalRecords.add(existing);
        } else {
          // MATCHED: Existing record with modified/updated fields
          conflictRecords.add(
            RecordDiff(
              existingRecord: existing,
              incomingRecord: incoming,
              changedFields: diffs,
              shouldUpdate: true,
            ),
          );
        }
      } else if (cleanMobile.length >= 10 && existingMobilesMap.containsKey(cleanMobile)) {
        // Secondary Match: Different Consumer No, but same Mobile / Customer Name match
        final mobileMatch = existingMobilesMap[cleanMobile]!;
        final diffs = computeFieldDiffs(
          mobileMatch,
          incoming,
          allowedFieldKeys: allowedFieldKeys,
          ignoreBlankValues: ignoreBlankValues,
        );

        possibleDuplicateRecords.add(
          RecordDiff(
            existingRecord: mobileMatch,
            incomingRecord: incoming,
            changedFields: diffs,
            shouldUpdate: false, // Safe default: do not auto-overwrite
          ),
        );
      } else {
        // NEW Record
        newRecords.add(incoming);
      }
    }

    return DuplicateAnalysisResult(
      newRecords: newRecords,
      identicalRecords: identicalRecords,
      conflictRecords: conflictRecords,
      possibleDuplicateRecords: possibleDuplicateRecords,
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
      'loan_status',
      'loan_sub_stage',
      'installation_status',
      'rts_status',
      'subsidy_status',
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
    check('loan_sub_stage', 'Loan Sub-Stage', existing.loanSubStage, incoming.loanSubStage);
    check('installation_status', 'Installation Status', existing.installationStatus, incoming.installationStatus);
    check('installer_team', 'Installer Team', existing.installerTeam, incoming.installerTeam);
    check('rts_status', 'RTS Status', existing.rtsStatus, incoming.rtsStatus);
    check('rts_application_id', 'RTS Application ID', existing.rtsApplicationId, incoming.rtsApplicationId);
    check('subsidy_status', 'Subsidy Status', existing.subsidyStatus, incoming.subsidyStatus);

    return diffs;
  }
}
