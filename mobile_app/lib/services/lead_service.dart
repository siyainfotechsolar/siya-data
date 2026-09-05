import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lead_record.dart';
import 'supabase_service.dart';

class MobileLeadMetrics {
  final int myLeads;
  final int todayFollowups;
  final int overdueFollowups;
  final int activeLeads;

  const MobileLeadMetrics({
    this.myLeads = 0,
    this.todayFollowups = 0,
    this.overdueFollowups = 0,
    this.activeLeads = 0,
  });
}

class MobileLeadService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch leads for mobile app
  static Future<List<LeadRecord>> fetchLeads({
    String? filterScope, // 'my_leads', 'today', 'overdue', 'all'
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('leads').select().eq('deleted', false);

      final user = _client.auth.currentUser;

      if (filterScope == 'my_leads' && user != null) {
        query = query.eq('assigned_staff_id', user.id);
      }

      final now = DateTime.now();
      final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];

      if (filterScope == 'today') {
        query = query
            .eq('next_followup_date', todayStr)
            .not('lead_status', 'in', '("Converted","Lost","No Action Required")');
      } else if (filterScope == 'overdue') {
        query = query
            .lt('next_followup_date', todayStr)
            .not('lead_status', 'in', '("Converted","Lost","No Action Required")');
      }

      if (statusFilter != null && statusFilter != 'All') {
        query = query.eq('lead_status', statusFilter);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('customer_name.ilike.%$q%,mobile_no.ilike.%$q%,village.ilike.%$q%');
      }

      query = query.order('next_followup_date', ascending: true, nullsFirst: false).order('updated_at', ascending: false);

      final res = await query;
      return (res as List).map((json) => LeadRecord.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch quick summary metrics for mobile
  static Future<MobileLeadMetrics> fetchLeadMetrics() async {
    try {
      final user = _client.auth.currentUser;
      final res = await _client
          .from('leads')
          .select('assigned_staff_id, lead_status, next_followup_date')
          .eq('deleted', false);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = today.toIso8601String().split('T')[0];

      int myLeads = 0;
      int todayFollowups = 0;
      int overdueFollowups = 0;
      int activeLeads = 0;

      for (final row in (res as List)) {
        final status = row['lead_status'] as String? ?? 'New';
        final isTerminal = status == 'Converted' || status == 'Lost' || status == 'No Action Required';
        final assignedId = row['assigned_staff_id'] as String?;
        final followupStr = row['next_followup_date'] as String?;

        if (user != null && assignedId == user.id) {
          myLeads++;
        }

        if (!isTerminal) {
          activeLeads++;
          if (followupStr != null && followupStr.isNotEmpty) {
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
      }

      return MobileLeadMetrics(
        myLeads: myLeads,
        todayFollowups: todayFollowups,
        overdueFollowups: overdueFollowups,
        activeLeads: activeLeads,
      );
    } catch (e) {
      return const MobileLeadMetrics();
    }
  }

  /// Create new lead from mobile
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
        newValue: 'Lead created via Mobile for ${lead.customerName} (${lead.mobileNo})',
      );
      return lead;
    } catch (e) {
      return null;
    }
  }

  /// Add follow-up entry from mobile
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
        newValue: '$followupType: $notes',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch followups for a lead
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

  /// Update lead status
  static Future<bool> updateStatus(String leadId, String newStatus, {DateTime? nextFollowupDate}) async {
    try {
      final updates = <String, dynamic>{
        'lead_status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (nextFollowupDate != null) {
        updates['next_followup_date'] = nextFollowupDate.toIso8601String().split('T')[0];
      }

      await _client.from('leads').update(updates).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'STATUS_CHANGED',
        newValue: newStatus,
      );
      return true;
    } catch (e) {
      return false;
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

  /// Convert lead to customer from mobile
  static Future<Map<String, dynamic>?> convertLeadToCustomer({
    required LeadRecord lead,
    String? remarks,
  }) async {
    try {
      final user = _client.auth.currentUser;
      final consNo = (lead.consumerNo != null && lead.consumerNo!.trim().isNotEmpty)
          ? lead.consumerNo!.trim()
          : 'LEAD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

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
        'assigned_to': lead.assignedStaffName ?? user?.email?.split('@').first,
        'remarks': 'Converted via Mobile from Lead #${lead.id.substring(0, 8)}. Source: ${lead.leadSource}. ${remarks ?? ""}',
        'created_by': user?.id,
        'updated_by': user?.id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final customerRes = await _client.from('consumer_records').insert(customerData).select().single();
      final customerId = customerRes['id'] as String;

      await _client.from('leads').update({
        'lead_status': 'Converted',
        'converted_at': DateTime.now().toUtc().toIso8601String(),
        'converted_by': user?.id,
        'customer_id': customerId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', lead.id);

      await _logAudit(
        leadId: lead.id,
        action: 'CONVERTED',
        newValue: 'Converted via Mobile App to Customer #$customerId',
      );

      return customerRes;
    } catch (e) {
      return null;
    }
  }

  /// Mark as lost
  static Future<bool> markLeadLost(String leadId, {required String reason, String? notes}) async {
    try {
      await _client.from('leads').update({
        'lead_status': 'Lost',
        'lost_reason': reason,
        'lost_notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'LOST',
        reason: 'Reason: $reason. ${notes ?? ""}',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark as No Action Required
  static Future<bool> markLeadNoAction(String leadId, {required String reason, String? notes}) async {
    try {
      await _client.from('leads').update({
        'lead_status': 'No Action Required',
        'no_action_reason': reason,
        'no_action_notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', leadId);

      await _logAudit(
        leadId: leadId,
        action: 'NO_ACTION',
        reason: 'Reason: $reason. ${notes ?? ""}',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reopen lead
  static Future<bool> reopenLead(String leadId, {DateTime? nextFollowupDate}) async {
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
        newValue: 'Reopened to Follow-up',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _logAudit({
    required String leadId,
    required String action,
    String? newValue,
    String? reason,
  }) async {
    try {
      final user = _client.auth.currentUser;
      await _client.from('lead_audit_logs').insert({
        'lead_id': leadId,
        'action': action,
        'new_value': newValue,
        'reason': reason,
        'changed_by': user?.id,
        'changed_by_name': user?.email?.split('@').first,
        'source': 'Mobile App',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
}
