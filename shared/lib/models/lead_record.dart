class LeadRecord {
  final String id;
  final String customerName;
  final String mobileNo;
  final String? whatsappNo;
  final String? village;
  final String? taluka;
  final String? district;
  final String leadSource;
  final String interestedIn;
  final String? approxSystemSize;
  final double? monthlyElectricityBill;
  final double? estimatedBudget;
  final String? consumerNo;
  final String leadStatus;
  final DateTime? nextFollowupDate;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String? remarks;
  final String? lostReason;
  final String? lostNotes;
  final String? noActionReason;
  final String? noActionNotes;
  final DateTime? convertedAt;
  final String? convertedBy;
  final String? customerId;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const LeadRecord({
    required this.id,
    required this.customerName,
    required this.mobileNo,
    this.whatsappNo,
    this.village,
    this.taluka,
    this.district,
    required this.leadSource,
    required this.interestedIn,
    this.approxSystemSize,
    this.monthlyElectricityBill,
    this.estimatedBudget,
    this.consumerNo,
    required this.leadStatus,
    this.nextFollowupDate,
    this.assignedStaffId,
    this.assignedStaffName,
    this.remarks,
    this.lostReason,
    this.lostNotes,
    this.noActionReason,
    this.noActionNotes,
    this.convertedAt,
    this.convertedBy,
    this.customerId,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory LeadRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String && val.trim().isNotEmpty) {
        return DateTime.tryParse(val.trim());
      }
      return null;
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return LeadRecord(
      id: json['id'] as String,
      customerName: json['customer_name'] as String? ?? 'Unnamed',
      mobileNo: json['mobile_no'] as String? ?? '',
      whatsappNo: json['whatsapp_no'] as String?,
      village: json['village'] as String?,
      taluka: json['taluka'] as String?,
      district: json['district'] as String?,
      leadSource: json['lead_source'] as String? ?? 'Other',
      interestedIn: json['interested_in'] as String? ?? 'On-Grid',
      approxSystemSize: json['approx_system_size'] as String?,
      monthlyElectricityBill: parseDouble(json['monthly_electricity_bill']),
      estimatedBudget: parseDouble(json['estimated_budget']),
      consumerNo: json['consumer_no'] as String?,
      leadStatus: json['lead_status'] as String? ?? 'New',
      nextFollowupDate: parseDate(json['next_followup_date']),
      assignedStaffId: json['assigned_staff_id'] as String?,
      assignedStaffName: json['assigned_staff_name'] as String?,
      remarks: json['remarks'] as String?,
      lostReason: json['lost_reason'] as String?,
      lostNotes: json['lost_notes'] as String?,
      noActionReason: json['no_action_reason'] as String?,
      noActionNotes: json['no_action_notes'] as String?,
      convertedAt: parseDate(json['converted_at']),
      convertedBy: json['converted_by'] as String?,
      customerId: json['customer_id'] as String?,
      deleted: json['deleted'] as bool? ?? false,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'mobile_no': mobileNo,
      'whatsapp_no': whatsappNo,
      'village': village,
      'taluka': taluka,
      'district': district,
      'lead_source': leadSource,
      'interested_in': interestedIn,
      'approx_system_size': approxSystemSize,
      'monthly_electricity_bill': monthlyElectricityBill,
      'estimated_budget': estimatedBudget,
      'consumer_no': consumerNo,
      'lead_status': leadStatus,
      'next_followup_date': nextFollowupDate?.toIso8601String().split('T')[0],
      'assigned_staff_id': assignedStaffId,
      'assigned_staff_name': assignedStaffName,
      'remarks': remarks,
      'lost_reason': lostReason,
      'lost_notes': lostNotes,
      'no_action_reason': noActionReason,
      'no_action_notes': noActionNotes,
      'converted_at': convertedAt?.toIso8601String(),
      'converted_by': convertedBy,
      'customer_id': customerId,
      'deleted': deleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  bool get isConverted => leadStatus == 'Converted';
  bool get isLost => leadStatus == 'Lost';
  bool get isNoActionRequired => leadStatus == 'No Action Required';
  bool get isTerminalState => isConverted || isLost || isNoActionRequired;

  bool get isTodayFollowup {
    if (nextFollowupDate == null || isTerminalState) return false;
    final now = DateTime.now();
    return nextFollowupDate!.year == now.year &&
        nextFollowupDate!.month == now.month &&
        nextFollowupDate!.day == now.day;
  }

  bool get isOverdue {
    if (nextFollowupDate == null || isTerminalState) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextFollowupDate!.year, nextFollowupDate!.month, nextFollowupDate!.day);
    return target.isBefore(today);
  }

  int get overdueDays {
    if (!isOverdue || nextFollowupDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextFollowupDate!.year, nextFollowupDate!.month, nextFollowupDate!.day);
    return today.difference(target).inDays;
  }

  String get smartNextAction {
    switch (leadStatus) {
      case 'New':
        return 'Contact Customer';
      case 'Contacted':
        return 'Assess Requirement';
      case 'Interested':
        return 'Schedule Site Survey';
      case 'Site Survey':
        return 'Complete Survey & Quotation';
      case 'Quotation':
        return 'Follow Up Quotation';
      case 'Follow-up':
        return 'Call Customer';
      case 'Converted':
        return 'None (Converted to Application)';
      case 'Lost':
        return 'None (Lost Lead)';
      case 'No Action Required':
        return 'None (On Hold)';
      default:
        return 'Review Lead';
    }
  }

  String get fullAddress {
    final parts = [village, taluka, district].where((e) => e != null && e.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Address not specified' : parts.join(', ');
  }
}

class LeadFollowup {
  final String id;
  final String leadId;
  final DateTime followupDate;
  final String followupType;
  final String notes;
  final String? result;
  final DateTime? nextFollowupDate;
  final String? performedBy;
  final String? performedByName;
  final DateTime createdAt;

  const LeadFollowup({
    required this.id,
    required this.leadId,
    required this.followupDate,
    required this.followupType,
    required this.notes,
    this.result,
    this.nextFollowupDate,
    this.performedBy,
    this.performedByName,
    required this.createdAt,
  });

  factory LeadFollowup.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String && val.trim().isNotEmpty) {
        return DateTime.tryParse(val.trim());
      }
      return null;
    }

    return LeadFollowup(
      id: json['id'] as String,
      leadId: json['lead_id'] as String,
      followupDate: parseDate(json['followup_date']) ?? DateTime.now(),
      followupType: json['followup_type'] as String? ?? 'Call',
      notes: json['notes'] as String? ?? '',
      result: json['result'] as String?,
      nextFollowupDate: parseDate(json['next_followup_date']),
      performedBy: json['performed_by'] as String?,
      performedByName: json['performed_by_name'] as String?,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lead_id': leadId,
      'followup_date': followupDate.toIso8601String(),
      'followup_type': followupType,
      'notes': notes,
      'result': result,
      'next_followup_date': nextFollowupDate?.toIso8601String().split('T')[0],
      'performed_by': performedBy,
      'performed_by_name': performedByName,
    };
  }
}

class LeadAuditLog {
  final String id;
  final String leadId;
  final String action;
  final String? fieldName;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final String? changedBy;
  final String? changedByName;
  final String source;
  final DateTime createdAt;

  const LeadAuditLog({
    required this.id,
    required this.leadId,
    required this.action,
    this.fieldName,
    this.oldValue,
    this.newValue,
    this.reason,
    this.changedBy,
    this.changedByName,
    required this.source,
    required this.createdAt,
  });

  factory LeadAuditLog.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String && val.trim().isNotEmpty) {
        return DateTime.tryParse(val.trim());
      }
      return null;
    }

    return LeadAuditLog(
      id: json['id'] as String,
      leadId: json['lead_id'] as String,
      action: json['action'] as String? ?? 'UPDATED',
      fieldName: json['field_name'] as String?,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      reason: json['reason'] as String?,
      changedBy: json['changed_by'] as String?,
      changedByName: json['changed_by_name'] as String?,
      source: json['source'] as String? ?? 'Admin Web',
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
