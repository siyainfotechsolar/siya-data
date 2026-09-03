import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/duplicate_group.dart';
import '../utils/consumer_no_utils.dart';
import 'supabase_service.dart';

class BulkMergeSummary {
  final int mergedGroupsCount;
  final int mergedRecordsCount;
  final bool success;

  BulkMergeSummary({
    required this.mergedGroupsCount,
    required this.mergedRecordsCount,
    required this.success,
  });
}

class DuplicateFinderService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch all Duplicate Groups from database with optional search and sorting
  static Future<List<DuplicateGroup>> fetchDuplicateGroups({
    String? searchQuery,
    String? statusFilter,
    String? priorityFilter,
    String sortBy = 'count', // 'count', 'appDays', 'submitDate', 'name'
    bool descending = true,
  }) async {
    try {
      // Query active, non-merged records
      final response = await _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false);

      final List<dynamic> data = response as List<dynamic>;
      final allRecords = data.map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>)).toList();

      // Group records by normalized consumer number
      final groupMap = <String, List<ConsumerRecord>>{};
      for (final r in allRecords) {
        final normNo = r.normalizedConsumerNo;
        if (normNo.isNotEmpty) {
          groupMap.putIfAbsent(normNo, () => []).add(r);
        }
      }

      // Filter groups with count > 1
      final rawGroups = <DuplicateGroup>[];
      groupMap.forEach((normNo, records) {
        if (records.length > 1) {
          // Check if exact raw string match or formatting variation
          final firstRaw = records.first.consumerNo.trim();
          final isExact = records.every((r) => r.consumerNo.trim() == firstRaw);
          final matchType = isExact ? DuplicateMatchType.exactMatch : DuplicateMatchType.formattingVariation;

          rawGroups.add(
            DuplicateGroup(
              normalizedConsumerNo: normNo,
              records: records,
              matchType: matchType,
            ),
          );
        }
      });

      // Filter by search query
      List<DuplicateGroup> filteredGroups = rawGroups;
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = searchQuery.trim().toLowerCase();
        final normTerm = ConsumerNoNormalizer.normalize(searchQuery);

        filteredGroups = filteredGroups.where((g) {
          if (g.normalizedConsumerNo.contains(normTerm)) return true;
          return g.records.any((r) =>
              r.name.toLowerCase().contains(term) ||
              r.consumerNo.toLowerCase().contains(term) ||
              (r.mobile != null && r.mobile!.contains(term)) ||
              (r.applicationId != null && r.applicationId!.toLowerCase().contains(term)));
        }).toList();
      }

      // Filter by status or priority
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        filteredGroups = filteredGroups.where((g) {
          return g.records.any((r) => r.status.toUpperCase() == statusFilter.toUpperCase());
        }).toList();
      }

      if (priorityFilter != null && priorityFilter.isNotEmpty && priorityFilter != 'ALL') {
        filteredGroups = filteredGroups.where((g) {
          return g.records.any((r) => r.priority.toUpperCase() == priorityFilter.toUpperCase());
        }).toList();
      }

      // Sort duplicate groups
      filteredGroups.sort((a, b) {
        int cmp = 0;
        switch (sortBy) {
          case 'appDays':
            cmp = a.maxApplicationDays.compareTo(b.maxApplicationDays);
            break;
          case 'submitDate':
            final dateA = a.oldestSubmitDate ?? DateTime(2000);
            final dateB = b.oldestSubmitDate ?? DateTime(2000);
            cmp = dateA.compareTo(dateB);
            break;
          case 'name':
            final nameA = a.records.first.name;
            final nameB = b.records.first.name;
            cmp = nameA.toLowerCase().compareTo(nameB.toLowerCase());
            break;
          case 'count':
          default:
            cmp = a.recordCount.compareTo(b.recordCount);
            break;
        }
        return descending ? -cmp : cmp;
      });

      return filteredGroups;
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in DuplicateFinderService.fetchDuplicateGroups: $e\n$stack');
      return [];
    }
  }

  /// Execute atomic Smart Merge using database RPC transaction
  static Future<bool> executeSmartMerge({
    required String masterId,
    required List<String> duplicateIds,
    required Map<String, dynamic> mergedPayload,
    required Map<String, dynamic> conflictsSummary,
  }) async {
    try {
      final user = SupabaseService.currentUser;

      final res = await _client.rpc(
        'execute_smart_merge',
        params: {
          'master_id': masterId,
          'duplicate_ids': duplicateIds,
          'merged_payload': mergedPayload,
          'conflicts_summary': conflictsSummary,
          'executing_user_id': user?.id,
        },
      );

      if (res != null && res['success'] == true) {
        return true;
      }
      return false;
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error calling execute_smart_merge RPC, attempting fallback: $e\n$stack');

      // Fallback: Perform batch update
      try {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        final user = SupabaseService.currentUser;

        // 1. Update Master Record
        await _client.from('consumer_records').update(mergedPayload).eq('id', masterId);

        // 2. Mark Duplicate Records as merged
        for (final dupId in duplicateIds) {
          if (dupId != masterId) {
            await _client.from('consumer_records').update({
              'is_merged': true,
              'merged_into_id': masterId,
              'merged_at': nowIso,
              'merged_by': user?.id,
            }).eq('id', dupId);
          }
        }

        // 3. Write Audit Log
        try {
          await _client.from('audit_logs').insert({
            'record_id': masterId,
            'consumer_no': mergedPayload['consumer_no'] ?? 'MERGED',
            'action': 'SMART_MERGE',
            'field_name': 'Smart Merge Execution',
            'old_value': 'Multiple Duplicates (${duplicateIds.length})',
            'new_value': 'Merged into Master $masterId',
            'changed_by': user?.id,
            'source': 'Admin Panel',
            'created_at': nowIso,
          });
        } catch (_) {}

        return true;
      } catch (fallbackError) {
        // ignore: avoid_print
        print('Smart Merge Fallback failed: $fallbackError');
        return false;
      }
    }
  }

  /// Automatically merge multiple duplicate groups in bulk without losing any data
  static Future<BulkMergeSummary> executeBulkAutoMerge({
    required List<DuplicateGroup> groups,
    void Function(int processed, int total)? onProgress,
  }) async {
    int mergedGroups = 0;
    int mergedRecords = 0;

    for (int i = 0; i < groups.length; i++) {
      final g = groups[i];
      if (g.records.length < 2) continue;

      // 1. Pick Master Record (oldest submit date or created_at)
      final master = g.records.reduce((a, b) {
        final dateA = a.submitDate ?? a.createdAt ?? DateTime(2099);
        final dateB = b.submitDate ?? b.createdAt ?? DateTime(2099);
        return dateA.isBefore(dateB) ? a : b;
      });

      // 2. Build non-empty payload & highest workflow stages
      final mergedPayload = <String, dynamic>{
        'consumer_no': g.normalizedConsumerNo,
      };

      String? getNonEmpty(String? Function(ConsumerRecord r) getter) {
        final masterVal = getter(master)?.trim();
        if (masterVal != null && masterVal.isNotEmpty) return masterVal;
        for (final r in g.records) {
          final val = getter(r)?.trim();
          if (val != null && val.isNotEmpty) return val;
        }
        return masterVal;
      }

      final name = getNonEmpty((r) => r.name);
      if (name != null) mergedPayload['name'] = name;

      final mobile = getNonEmpty((r) => r.mobile);
      if (mobile != null) mergedPayload['mobile'] = mobile;

      final address = getNonEmpty((r) => r.address);
      if (address != null) mergedPayload['address'] = address;

      final appId = getNonEmpty((r) => r.applicationId);
      if (appId != null) mergedPayload['application_id'] = appId;

      final remarks = getNonEmpty((r) => r.remarks);
      if (remarks != null) mergedPayload['remarks'] = remarks;

      final agreeDoc = getNonEmpty((r) => r.agreementDocUrl);
      if (agreeDoc != null) mergedPayload['agreement_doc_url'] = agreeDoc;

      final instPhotos = getNonEmpty((r) => r.installationPhotosUrl);
      if (instPhotos != null) mergedPayload['installation_photos_url'] = instPhotos;

      final rtsAppId = getNonEmpty((r) => r.rtsApplicationId);
      if (rtsAppId != null) mergedPayload['rts_application_id'] = rtsAppId;

      final installerTeam = getNonEmpty((r) => r.installerTeam);
      if (installerTeam != null) mergedPayload['installer_team'] = installerTeam;

      // Workflow Stages - Pick highest stage value
      mergedPayload['application_status'] = _pickHighestStage(g.records.map((r) => r.applicationStatus), ['Approved', 'Submitted', 'Pending']);
      mergedPayload['agreement_status'] = _pickHighestStage(g.records.map((r) => r.agreementStatus), ['Verified', 'Uploaded', 'Pending']);
      mergedPayload['loan_status'] = _pickHighestStage(g.records.map((r) => r.loanStatus), ['Approved', 'Applied', 'Under Process', 'Pending', 'Not Required']);
      mergedPayload['installation_status'] = _pickHighestStage(g.records.map((r) => r.installationStatus), ['Completed', 'Installed', 'In Progress', 'Approved', 'Not Started']);
      mergedPayload['rts_status'] = _pickHighestStage(g.records.map((r) => r.rtsStatus), ['Completed', 'Applied', 'Pending', 'Not Started']);
      mergedPayload['subsidy_status'] = _pickHighestStage(g.records.map((r) => r.subsidyStatus), ['Received', 'Approved', 'Applied', 'Under Process', 'Not Applied']);

      // 3. Execute smart merge for this group
      final duplicateIds = g.records.where((r) => r.id != master.id).map((r) => r.id ?? '').where((id) => id.isNotEmpty).toList();

      final ok = await executeSmartMerge(
        masterId: master.id ?? '',
        duplicateIds: duplicateIds,
        mergedPayload: mergedPayload,
        conflictsSummary: {'auto_merge': 'Bulk Auto-Merge executed'},
      );

      if (ok) {
        mergedGroups++;
        mergedRecords += duplicateIds.length;
      }

      onProgress?.call(i + 1, groups.length);
    }

    return BulkMergeSummary(
      mergedGroupsCount: mergedGroups,
      mergedRecordsCount: mergedRecords,
      success: true,
    );
  }

  static String _pickHighestStage(Iterable<String> values, List<String> rankOrder) {
    for (final rank in rankOrder) {
      if (values.any((v) => v.trim().toLowerCase() == rank.toLowerCase())) {
        return rank;
      }
    }
    final firstNonEmpty = values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => rankOrder.last);
    return firstNonEmpty;
  }
}
