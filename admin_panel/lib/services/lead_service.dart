import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lead_record.dart';
import 'supabase_service.dart';

class LeadMetrics {
  final int total;
  final int newLeads;
  final int inProgress;
  final int todayFollowups;
  final int overdueFollowups;
  final int converted;
  final int lost;
  final int noActionRequired;

  const LeadMetrics({
    this.total = 0,
    this.newLeads = 0,
    this.inProgress = 0,
    this.todayFollowups = 0,
    this.overdueFollowups = 0,
    this.converted = 0,
    this.lost = 0,
    this.noActionRequired = 0,
  });
}

class LeadService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch leads with filters
  static Future<List<LeadRecord>> fetchLeads({
    String? statusFilter,
    String? searchQuery,
    String? staffFilter,
    String? scopeFilter, // 'all', 'today', 'overdue', 'upcoming'
  }) async {
    try {
      var query = _client.from('leads').select().eq('deleted', false);

      if (statusFilter != null && statusFilter != 'All') {
        query = query.eq('lead_status', statusFilter);
      }

      if (staffFilter != null && staffFilter.isNotEmpty) {
        query = query.eq('assigned_staff_id', staffFilter);
      }

      final now = DateTime.now();
      final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];

      if (scopeFilter == 'today') {
        query = query
            .eq('next_followup_date', todayStr)
            .not('lead_status', 'in', '("Converted","Lost","No Action Required")');
      } else if (scopeFilter == 'overdue') {
        query = query
            .lt('next_followup_date', todayStr)
            .not('lead_status', 'in', '("Converted","Lost","No Action Required")');
      } else if (scopeFilter == 'upcoming') {
        query = query
            .gt('next_followup_date', todayStr)
            .not('lead_status', 'in', '("Converted","Lost","No Action Required")');
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('customer_name.ilike.%$q%,mobile_no.ilike.%$q%,consumer_no.ilike.%$q%,village.ilike.%$q%');
      }

      query = query.order('next_followup_date', ascending: true, nullsFirst: false).order('updated_at', ascending: false);

      final res = await query;
      final list = (res as List).map((json) => LeadRecord.fromJson(json)).toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  /// Fetch dashboard metrics for Leads
  static Future<LeadMetrics> fetchLeadMetrics() async {
    try {
      final res = await _client
          .from('leads')
          .select('lead_status, next_followup_date')
          .eq('deleted', false);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = today.toIso8601String().split('T')[0];

      int total = 0;
      int newLeads = 0;
      int inProgress = 0;
      int todayFollowups = 0;
      int overdueFollowups = 0;
      int converted = 0;
      int lost = 0;
      int noActionRequired = 0;

      for (final row in (res as List)) {
        total++;
        final status = row['lead_status'] as String? ?? 'New';
        final followupStr = row['next_followup_date'] as String?;

        final isTerminal = status == 'Converted' || status == 'Lost' || status == 'No Action Required';

        if (status == 'New') newLeads++;
        if (status == 'Converted') converted++;
        if (status == 'Lost') lost++;
        if (status == 'No Action Required') noActionRequired++;
        if (!isTerminal && status != 'New') inProgress++;

        if (!isTerminal && followupStr != null && followupStr.isNotEmpty) {
          final fDate = DateTime.tryParse(followupStr);
          if (fDate != null) {
            final fOnly = DateTime(fDate.year, fDate.month, fDate.day);
            if (followupStr == todayStr || fOnly == today) {
              todayFollowups++;
            } else if (fOnly.isBefore(today)) {
              overdueFollowups++;
            }
          }
        }
      }

      return LeadMetrics(
        total: total,
        newLeads: newLeads,
        inProgress: inProgress,
        todayFollowups: todayFollowups,
        overdueFollowups: overdueFollowups,
        converted: converted,
        lost: lost,
        noActionRequired: noActionRequired,
      );
    } catch (e) {
      return const LeadMetrics();
    }
  }

  /// Create a new Lead
  static Future<LeadRecord?> createLead(Map<String, dynamic> data) async {
    try {
      final user = _client.auth.currentUser;
      data['created_by'] = user?.id;
      data['created_at'] = DateTime.now().toUtc().toIso8601String();
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final res = await _client.from('leads').insert(data).select().single();
      final lead = LeadRecord.fromJson(res);

      await _logAudit(
        leadId: lead.id,
        action: 'CREATED',
        newValue: 'Lead created for ${lead.customerName} (${lead.mobileNo})',
        source: 'Admin Web',
      );

      return lead;
    } catch (e) {
      return null;
    }
  }

  /// Update lead details
  static Future<bool> updateLead(String leadId, Map<String, dynamic> data, {String? reason}) async {
    try {
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _client.from('leads').update(data).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'UPDATED',
        reason: reason ?? 'Details updated',
        source: 'Admin Web',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch follow-up history
  static Future<List<LeadFollowup>> fetchFollowups(String leadId) async {
    try {
      final res = await _client
          .from('lead_followups')
          .select()
          .eq('lead_id', leadId)
          .order('followup_date', ascending: false);

      return (res as List).map((j) => LeadFollowup.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add follow-up entry
  static Future<bool> addFollowup({
    required String leadId,
    required String followupType,
    required String notes,
    String? result,
    DateTime? nextFollowupDate,
    String? updatedStatus,
  }) async {
    try {
      final user = _client.auth.currentUser;
      final followupData = {
        'lead_id': leadId,
        'followup_type': followupType,
        'notes': notes,
        'result': result,
        'next_followup_date': nextFollowupDate?.toIso8601String().split('T')[0],
        'performed_by': user?.id,
        'performed_by_name': user?.email?.split('@').first,
        'followup_date': DateTime.now().toUtc().toIso8601String(),
      };

      await _client.from('lead_followups').insert(followupData);

      // Also update lead's next_followup_date and status if provided
      final leadUpdates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (nextFollowupDate != null) {
        leadUpdates['next_followup_date'] = nextFollowupDate.toIso8601String().split('T')[0];
      }
      if (updatedStatus != null && updatedStatus.isNotEmpty) {
        leadUpdates['lead_status'] = updatedStatus;
      }

      await _client.from('leads').update(leadUpdates).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'FOLLOWUP_ADDED',
        newValue: '$followupType: $notes (Result: ${result ?? "Logged"})',
        source: 'Admin Web',
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch audit logs
  static Future<List<LeadAuditLog>> fetchAuditLogs(String leadId) async {
    try {
      final res = await _client
          .from('lead_audit_logs')
          .select()
          .eq('lead_id', leadId)
          .order('created_at', ascending: false);

      return (res as List).map((j) => LeadAuditLog.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if customer already exists before converting
  static Future<List<Map<String, dynamic>>> checkExistingCustomer({
    required String mobileNo,
    String? consumerNo,
  }) async {
    try {
      var query = _client.from('consumer_records').select('id, name, mobile, consumer_no, status, address').eq('deleted', false);

      if (consumerNo != null && consumerNo.trim().isNotEmpty) {
        query = query.or('mobile.eq.$mobileNo,consumer_no.eq.${consumerNo.trim()}');
      } else {
        query = query.eq('mobile', mobileNo.trim());
      }

      final res = await query.limit(5);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return [];
    }
  }

  /// Convert Lead to Customer Application
  static Future<Map<String, dynamic>?> convertLeadToCustomer({
    required LeadRecord lead,
    String? remarks,
    String? assignedStaffName,
  }) async {
    try {
      final user = _client.auth.currentUser;

      // 1. Generate or use consumer_no
      final consNo = (lead.consumerNo != null && lead.consumerNo!.trim().isNotEmpty)
          ? lead.consumerNo!.trim()
          : 'LEAD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // 2. Insert into consumer_records
      final customerData = {
        'name': lead.customerName,
        'mobile': lead.mobileNo,
        'consumer_no': consNo,
        'address': lead.fullAddress,
        'status': 'Pending',
        'customer_work_state': 'ACTIVE',
        'workflow_queue': 'Agreement Pending',
        'current_work_stage': 'Agreement Pending',
        'action_required': 'Complete Agreement',
        'next_action': 'Draft and sign customer agreement',
        'assigned_to': assignedStaffName ?? lead.assignedStaffName,
        'remarks': 'Converted from Lead #${lead.id.substring(0, 8)}. Source: ${lead.leadSource}. ${remarks ?? ""}',
        'created_by': user?.id,
        'updated_by': user?.id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final customerRes = await _client.from('consumer_records').insert(customerData).select().single();
      final customerId = customerRes['id'] as String;

      // 3. Update Lead as Converted
      final leadUpdates = {
        'lead_status': 'Converted',
        'converted_at': DateTime.now().toUtc().toIso8601String(),
        'converted_by': user?.id,
        'customer_id': customerId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _client.from('leads').update(leadUpdates).eq('id', lead.id);

      // 4. Audit Log
      await _logAudit(
        leadId: lead.id,
        action: 'CONVERTED',
        newValue: 'Converted to Customer Application (ID: $customerId, Consumer No: $consNo)',
        source: 'Admin Web',
      );

      return customerRes;
    } catch (e) {
      return null;
    }
  }

  /// Mark Lead as Lost
  static Future<bool> markLeadLost(String leadId, {required String reason, String? notes}) async {
    try {
      final updates = {
        'lead_status': 'Lost',
        'lost_reason': reason,
        'lost_notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _client.from('leads').update(updates).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'LOST',
        reason: 'Reason: $reason. ${notes ?? ""}',
        source: 'Admin Web',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark Lead as No Action Required (Hold)
  static Future<bool> markLeadNoAction(String leadId, {required String reason, String? notes}) async {
    try {
      final updates = {
        'lead_status': 'No Action Required',
        'no_action_reason': reason,
        'no_action_notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _client.from('leads').update(updates).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'NO_ACTION',
        reason: 'Reason: $reason. ${notes ?? ""}',
        source: 'Admin Web',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reopen Lead
  static Future<bool> reopenLead(String leadId, {DateTime? nextFollowupDate, String? reason}) async {
    try {
      final updates = <String, dynamic>{
        'lead_status': 'Follow-up',
        'lost_reason': null,
        'lost_notes': null,
        'no_action_reason': null,
        'no_action_notes': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (nextFollowupDate != null) {
        updates['next_followup_date'] = nextFollowupDate.toIso8601String().split('T')[0];
      }

      await _client.from('leads').update(updates).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'REOPENED',
        reason: reason ?? 'Reopened to Follow-up',
        source: 'Admin Web',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _logAudit({
    required String leadId,
    required String action,
    String? fieldName,
    String? oldValue,
    String? newValue,
    String? reason,
    String source = 'Admin Web',
  }) async {
    try {
      final user = _client.auth.currentUser;
      await _client.from('lead_audit_logs').insert({
        'lead_id': leadId,
        'action': action,
        'field_name': fieldName,
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'changed_by': user?.id,
        'changed_by_name': user?.email?.split('@').first,
        'source': source,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
}
