enum PriorityLevel {
  critical('CRITICAL', '31+ Days', 1),
  high('HIGH', '16–30 Days', 2),
  medium('MEDIUM', '8–15 Days', 3),
  normal('NORMAL', '0–7 Days', 4);

  final String label;
  final String rangeLabel;
  final int rank;

  const PriorityLevel(this.label, this.rangeLabel, this.rank);

  static PriorityLevel fromDays(int days) {
    if (days >= 31) return PriorityLevel.critical;
    if (days >= 16) return PriorityLevel.high;
    if (days >= 8) return PriorityLevel.medium;
    return PriorityLevel.normal;
  }

  static PriorityLevel fromLabel(String label) {
    switch (label.toUpperCase()) {
      case 'CRITICAL':
        return PriorityLevel.critical;
      case 'HIGH':
        return PriorityLevel.high;
      case 'MEDIUM':
        return PriorityLevel.medium;
      case 'NORMAL':
      default:
        return PriorityLevel.normal;
    }
  }
}

class ConsumerRecord {
  final String? id;
  final String consumerNo;
  final String name;
  final String? mobile;
  final String? address;
  final String? applicationId;
  final String status;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final bool deleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  // --- Step 1: Application ---
  final String applicationStatus;
  final DateTime? submitDate;

  // --- Step 2: Agreement ---
  final bool agreementRequired;
  final String agreementStatus; // 'Pending', 'Uploaded', 'Verified', 'Rejected'
  final String? agreementDocUrl;
  final DateTime? agreementDate;

  // --- Step 3: Loan Decision ---
  final String loanRequired; // 'Yes', 'No'
  final String loanStatus; // 'Not Required', 'Pending', 'Applied', 'Under Process', 'Approved', 'Rejected'
  final DateTime? loanAppliedDate;
  final DateTime? loanApprovedDate;

  // --- Step 4: Installation ---
  final String installationStatus; // 'Not Started', 'Scheduled', 'Installation Pending', 'Structure Pending', 'Panel Pending', 'Wiring Pending', 'Installation Completed'
  final DateTime? installationDate;
  final String? installerTeam;
  final String? installationPhotosUrl;

  // --- Step 5: RTS / Net Meter ---
  final String rtsStatus; // 'Not Started', 'Application Pending', 'Applied', 'Meter Pending', 'Inspection Pending', 'Completed', 'Rejected'
  final String? rtsApplicationId;
  final DateTime? rtsDate;
  final DateTime? rtsCompletionDate;

  // --- Step 6: Subsidy ---
  final String subsidyStatus; // 'Not Applied', 'Applied', 'Under Process', 'Pending', 'Approved', 'Received', 'Rejected'
  final DateTime? subsidyAppliedDate;
  final DateTime? subsidyApprovedDate;
  final DateTime? subsidyReceivedDate;

  ConsumerRecord({
    this.id,
    required this.consumerNo,
    required this.name,
    this.mobile,
    this.address,
    this.applicationId,
    this.status = 'Pending',
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.deleted = false,
    this.deletedAt,
    this.deletedBy,
    // Step 1
    this.applicationStatus = 'Submitted',
    this.submitDate,
    // Step 2
    this.agreementRequired = true,
    this.agreementStatus = 'Pending',
    this.agreementDocUrl,
    this.agreementDate,
    // Step 3
    this.loanRequired = 'No',
    this.loanStatus = 'Not Required',
    this.loanAppliedDate,
    this.loanApprovedDate,
    // Step 4
    this.installationStatus = 'Not Started',
    this.installationDate,
    this.installerTeam,
    this.installationPhotosUrl,
    // Step 5
    this.rtsStatus = 'Not Started',
    this.rtsApplicationId,
    this.rtsDate,
    this.rtsCompletionDate,
    // Step 6
    this.subsidyStatus = 'Not Applied',
    this.subsidyAppliedDate,
    this.subsidyApprovedDate,
    this.subsidyReceivedDate,
  });

  // --- Computed Priority & Application Days Engine ---

  /// Calendar-date difference between current date and submit date
  int get applicationDays {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final start = submitDate ?? createdAt ?? now;
    final startDate = DateTime(start.year, start.month, start.day);

    if (startDate.isAfter(todayDate)) {
      return 0;
    }
    return todayDate.difference(startDate).inDays;
  }

  /// True if submit date is set in the future
  bool get isSubmitDateFuture {
    if (submitDate == null) return false;
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final sDate = DateTime(submitDate!.year, submitDate!.month, submitDate!.day);
    return sDate.isAfter(todayDate);
  }

  /// Dynamic priority level derived purely from Application Days
  PriorityLevel get priorityLevel => PriorityLevel.fromDays(applicationDays);

  /// Priority string label (CRITICAL, HIGH, MEDIUM, NORMAL)
  String get priority => priorityLevel.label;

  /// Returns true if record is an active application (excluding Completed and Cancelled)
  bool get isActiveApplication {
    if (deleted) return false;
    final st = status.trim().toLowerCase();
    final appSt = applicationStatus.trim().toLowerCase();
    return st != 'completed' && st != 'cancelled' && appSt != 'completed' && appSt != 'cancelled';
  }

  // --- Computed Business Logic & Workflow Rules ---

  bool get isLoanSatisfied {
    if (loanRequired.toLowerCase() != 'yes') return true;
    return loanStatus.toLowerCase() == 'approved';
  }

  bool get canCompleteInstallation => isLoanSatisfied;

  bool get canStartRts => installationStatus.toLowerCase() == 'installation completed';

  bool get canStartSubsidy => rtsStatus.toLowerCase() == 'completed';

  bool get isFullyCompleted => subsidyStatus.toLowerCase() == 'received';

  String get overallStage {
    if (isFullyCompleted) return 'Completed';
    if (subsidyStatus.toLowerCase() != 'not applied') return 'Subsidy';
    if (rtsStatus.toLowerCase() == 'completed' || rtsStatus.toLowerCase() != 'not started') return 'RTS';
    if (installationStatus.toLowerCase() == 'installation completed' || installationStatus.toLowerCase() != 'not started') {
      return 'Installation';
    }
    if (loanRequired.toLowerCase() == 'yes' && loanStatus.toLowerCase() != 'approved') {
      return 'Loan';
    }
    if (agreementStatus.toLowerCase() != 'verified') {
      return 'Agreement';
    }
    return 'Application';
  }

  factory ConsumerRecord.fromJson(Map<String, dynamic> json) {
    return ConsumerRecord(
      id: json['id'] as String?,
      consumerNo: json['consumer_no'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mobile: json['mobile'] as String?,
      address: json['address'] as String?,
      applicationId: json['application_id'] as String?,
      status: json['status'] as String? ?? 'Pending',
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      deleted: json['deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at']) : null,
      deletedBy: json['deleted_by'] as String?,
      // Step 1
      applicationStatus: json['application_status'] as String? ?? 'Submitted',
      submitDate: json['submit_date'] != null ? DateTime.tryParse(json['submit_date']) : null,
      // Step 2
      agreementRequired: json['agreement_required'] as bool? ?? true,
      agreementStatus: json['agreement_status'] as String? ?? 'Pending',
      agreementDocUrl: json['agreement_doc_url'] as String?,
      agreementDate: json['agreement_date'] != null ? DateTime.tryParse(json['agreement_date']) : null,
      // Step 3
      loanRequired: json['loan_required'] as String? ?? 'No',
      loanStatus: json['loan_status'] as String? ?? 'Not Required',
      loanAppliedDate: json['loan_applied_date'] != null ? DateTime.tryParse(json['loan_applied_date']) : null,
      loanApprovedDate: json['loan_approved_date'] != null ? DateTime.tryParse(json['loan_approved_date']) : null,
      // Step 4
      installationStatus: json['installation_status'] as String? ?? 'Not Started',
      installationDate: json['installation_date'] != null ? DateTime.tryParse(json['installation_date']) : null,
      installerTeam: json['installer_team'] as String?,
      installationPhotosUrl: json['installation_photos_url'] as String?,
      // Step 5
      rtsStatus: json['rts_status'] as String? ?? 'Not Started',
      rtsApplicationId: json['rts_application_id'] as String?,
      rtsDate: json['rts_date'] != null ? DateTime.tryParse(json['rts_date']) : null,
      rtsCompletionDate: json['rts_completion_date'] != null ? DateTime.tryParse(json['rts_completion_date']) : null,
      // Step 6
      subsidyStatus: json['subsidy_status'] as String? ?? 'Not Applied',
      subsidyAppliedDate: json['subsidy_applied_date'] != null ? DateTime.tryParse(json['subsidy_applied_date']) : null,
      subsidyApprovedDate: json['subsidy_approved_date'] != null ? DateTime.tryParse(json['subsidy_approved_date']) : null,
      subsidyReceivedDate: json['subsidy_received_date'] != null ? DateTime.tryParse(json['subsidy_received_date']) : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    final map = <String, dynamic>{
      'consumer_no': consumerNo.trim(),
      'name': name.trim(),
      'mobile': mobile?.trim(),
      'address': address?.trim(),
      'application_id': applicationId?.trim(),
      'status': status,
      'remarks': remarks?.trim(),
      'deleted': deleted,
      'application_status': applicationStatus,
      'agreement_required': agreementRequired,
      'agreement_status': agreementStatus,
      'agreement_doc_url': agreementDocUrl?.trim(),
      'loan_required': loanRequired,
      'loan_status': loanStatus,
      'installation_status': installationStatus,
      'installer_team': installerTeam?.trim(),
      'installation_photos_url': installationPhotosUrl?.trim(),
      'rts_status': rtsStatus,
      'rts_application_id': rtsApplicationId?.trim(),
      'subsidy_status': subsidyStatus,
    };

    if (submitDate != null) map['submit_date'] = submitDate!.toUtc().toIso8601String();
    if (agreementDate != null) map['agreement_date'] = agreementDate!.toUtc().toIso8601String();
    if (loanAppliedDate != null) map['loan_applied_date'] = loanAppliedDate!.toUtc().toIso8601String();
    if (loanApprovedDate != null) map['loan_approved_date'] = loanApprovedDate!.toUtc().toIso8601String();
    if (installationDate != null) map['installation_date'] = installationDate!.toUtc().toIso8601String();
    if (rtsDate != null) map['rts_date'] = rtsDate!.toUtc().toIso8601String();
    if (rtsCompletionDate != null) map['rts_completion_date'] = rtsCompletionDate!.toUtc().toIso8601String();
    if (subsidyAppliedDate != null) map['subsidy_applied_date'] = subsidyAppliedDate!.toUtc().toIso8601String();
    if (subsidyApprovedDate != null) map['subsidy_approved_date'] = subsidyApprovedDate!.toUtc().toIso8601String();
    if (subsidyReceivedDate != null) map['subsidy_received_date'] = subsidyReceivedDate!.toUtc().toIso8601String();

    if (deletedAt != null) map['deleted_at'] = deletedAt!.toUtc().toIso8601String();
    if (deletedBy != null) map['deleted_by'] = deletedBy;
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  ConsumerRecord copyWith({
    String? id,
    String? consumerNo,
    String? name,
    String? mobile,
    String? address,
    String? applicationId,
    String? status,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool? deleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearDeletedMetadata = false,
    String? applicationStatus,
    DateTime? submitDate,
    bool? agreementRequired,
    String? agreementStatus,
    String? agreementDocUrl,
    DateTime? agreementDate,
    String? loanRequired,
    String? loanStatus,
    DateTime? loanAppliedDate,
    DateTime? loanApprovedDate,
    String? installationStatus,
    DateTime? installationDate,
    String? installerTeam,
    String? installationPhotosUrl,
    String? rtsStatus,
    String? rtsApplicationId,
    DateTime? rtsDate,
    DateTime? rtsCompletionDate,
    String? subsidyStatus,
    DateTime? subsidyAppliedDate,
    DateTime? subsidyApprovedDate,
    DateTime? subsidyReceivedDate,
  }) {
    return ConsumerRecord(
      id: id ?? this.id,
      consumerNo: consumerNo ?? this.consumerNo,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      applicationId: applicationId ?? this.applicationId,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      deleted: deleted ?? this.deleted,
      deletedAt: clearDeletedMetadata ? null : (deletedAt ?? this.deletedAt),
      deletedBy: clearDeletedMetadata ? null : (deletedBy ?? this.deletedBy),
      applicationStatus: applicationStatus ?? this.applicationStatus,
      submitDate: submitDate ?? this.submitDate,
      agreementRequired: agreementRequired ?? this.agreementRequired,
      agreementStatus: agreementStatus ?? this.agreementStatus,
      agreementDocUrl: agreementDocUrl ?? this.agreementDocUrl,
      agreementDate: agreementDate ?? this.agreementDate,
      loanRequired: loanRequired ?? this.loanRequired,
      loanStatus: loanStatus ?? this.loanStatus,
      loanAppliedDate: loanAppliedDate ?? this.loanAppliedDate,
      loanApprovedDate: loanApprovedDate ?? this.loanApprovedDate,
      installationStatus: installationStatus ?? this.installationStatus,
      installationDate: installationDate ?? this.installationDate,
      installerTeam: installerTeam ?? this.installerTeam,
      installationPhotosUrl: installationPhotosUrl ?? this.installationPhotosUrl,
      rtsStatus: rtsStatus ?? this.rtsStatus,
      rtsApplicationId: rtsApplicationId ?? this.rtsApplicationId,
      rtsDate: rtsDate ?? this.rtsDate,
      rtsCompletionDate: rtsCompletionDate ?? this.rtsCompletionDate,
      subsidyStatus: subsidyStatus ?? this.subsidyStatus,
      subsidyAppliedDate: subsidyAppliedDate ?? this.subsidyAppliedDate,
      subsidyApprovedDate: subsidyApprovedDate ?? this.subsidyApprovedDate,
      subsidyReceivedDate: subsidyReceivedDate ?? this.subsidyReceivedDate,
    );
  }
}
