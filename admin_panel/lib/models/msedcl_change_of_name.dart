import 'dart:convert';
import 'dart:typed_data';

/// MSEDCL Application Status values
class MsedclApplicationStatus {
  static const String newEntry = 'New Entry';
  static const String docsPending = 'Documents Pending';
  static const String docsCompleted = 'Documents Completed';
  static const String submitted = 'Application Submitted';
  static const String msedclProcessing = 'MSEDCL Processing';
  static const String objectionRaised = 'Objection Raised';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
  static const String nameChanged = 'Name Changed Successfully';

  static const List<String> all = [
    newEntry,
    docsPending,
    docsCompleted,
    submitted,
    msedclProcessing,
    objectionRaised,
    approved,
    rejected,
    nameChanged,
  ];
}

/// Reasons for change of name / transfer of electricity connection
class MsedclReasonForChange {
  static const String purchaseOfProperty = 'Purchase of Property / Flat / Land';
  static const String inheritance = 'Inheritance / Succession / Legal Heir';
  static const String giftDeed = 'Gift Deed';
  static const String personalNameChange = 'Personal Name Change / Gazette / Marriage';
  static const String tenantTransfer = 'Transfer to Tenant / Lease (With Owner NOC)';
  static const String familySettlement = 'Partition Deed / Family Settlement';
  static const String other = 'Other';

  static const List<String> all = [
    purchaseOfProperty,
    inheritance,
    giftDeed,
    personalNameChange,
    tenantTransfer,
    familySettlement,
    other,
  ];
}

/// Standard Document Types for Annexure A Checklist
class MsedclDocumentType {
  static const String electricityBill = 'Latest Electricity Bill';
  static const String occupancyCertificate = 'Occupancy Certificate';
  static const String ownershipProof = 'Ownership Proof (Sale Deed / Index II)';
  static const String extract712 = '7/12 Extract (७/१२ उतारा)';
  static const String form8 = 'Form 8 (ग्रामपंचायत नमुना ८-अ)';
  static const String propertyTaxReceipt = 'Property Tax Receipt (घरपट्टी पावती)';
  static const String leaseAgreement = 'Lease / Rent Agreement (भाडेकरार)';
  static const String successionOrWill = 'Inheritance / Succession / Will / Gift Deed';
  static const String affidavitGazette = 'Affidavit / Gazette Notification';
  static const String ownerNoc = 'Owner NOC (जागा मालकाचे संमतीपत्र)';
  static const String other = 'Other Supporting Documents';

  static const List<String> all = [
    electricityBill,
    ownershipProof,
    extract712,
    form8,
    propertyTaxReceipt,
    occupancyCertificate,
    leaseAgreement,
    successionOrWill,
    affidavitGazette,
    ownerNoc,
    other,
  ];
}

/// Supporting Document Item in Annexure A
class MsedclDocumentItem {
  final String docType;
  final String status; // 'Received', 'Pending', 'Not Applicable'
  final String? fileName;
  final String? fileBytesBase64;
  final String? notes;
  final DateTime? uploadedAt;

  const MsedclDocumentItem({
    required this.docType,
    this.status = 'Pending',
    this.fileName,
    this.fileBytesBase64,
    this.notes,
    this.uploadedAt,
  });

  Uint8List? get fileBytes {
    if (fileBytesBase64 == null || fileBytesBase64!.isEmpty) return null;
    try {
      return base64Decode(fileBytesBase64!);
    } catch (_) {
      return null;
    }
  }

  bool get isReceived => status == 'Received';
  bool get isPending => status == 'Pending';
  bool get isNotApplicable => status == 'Not Applicable';

  MsedclDocumentItem copyWith({
    String? docType,
    String? status,
    String? fileName,
    String? fileBytesBase64,
    String? notes,
    DateTime? uploadedAt,
  }) {
    return MsedclDocumentItem(
      docType: docType ?? this.docType,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      fileBytesBase64: fileBytesBase64 ?? this.fileBytesBase64,
      notes: notes ?? this.notes,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doc_type': docType,
      'status': status,
      'file_name': fileName,
      'file_bytes_base64': fileBytesBase64,
      'notes': notes,
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }

  factory MsedclDocumentItem.fromJson(Map<String, dynamic> json) {
    return MsedclDocumentItem(
      docType: json['doc_type'] as String? ?? json['docType'] as String? ?? 'Other Supporting Documents',
      status: json['status'] as String? ?? 'Pending',
      fileName: json['file_name'] as String? ?? json['fileName'] as String?,
      fileBytesBase64: json['file_bytes_base64'] as String? ?? json['fileBytesBase64'] as String?,
      notes: json['notes'] as String?,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'] as String)
          : (json['uploadedAt'] != null ? DateTime.tryParse(json['uploadedAt'] as String) : null),
    );
  }
}

/// Status transition history entry
class MsedclStatusHistoryEntry {
  final String status;
  final DateTime timestamp;
  final String updatedBy;
  final String remarks;

  const MsedclStatusHistoryEntry({
    required this.status,
    required this.timestamp,
    required this.updatedBy,
    this.remarks = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'updated_by': updatedBy,
      'remarks': remarks,
    };
  }

  factory MsedclStatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MsedclStatusHistoryEntry(
      status: json['status'] as String? ?? 'New Entry',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedBy: json['updated_by'] as String? ?? json['updatedBy'] as String? ?? 'Admin',
      remarks: json['remarks'] as String? ?? '',
    );
  }
}

/// Main Model: MSEDCL Change of Name Application
class MsedclChangeOfNameApplication {
  final String id;
  final String applicationNo;
  final DateTime applicationDate;
  final String subDivisionOffice;
  final String circleOffice;
  final String village;
  final String reasonForChange;
  final String assignedEmployee;
  final String remarks;
  final String status;
  final List<MsedclStatusHistoryEntry> statusHistory;

  // Old Consumer (Transferor) Details
  final String oldFirstName;
  final String oldFatherOrHusbandName;
  final String oldSurname;
  final String oldConsumerFullName;
  final String consumerNo;
  final String oldMobileNo;
  final String oldMeterNo;

  // New Consumer (Transferee) Details
  final String newFirstName;
  final String newFatherOrHusbandName;
  final String newSurname;
  final String newConsumerFullName;
  final int newAge;
  final String newMobileNo;
  final String newPhoneNo;
  final String newEmail;
  final String newAadhaarNo;
  final String propertyAddress;

  // Stamp Paper Affidavit Configuration
  final double stampPaperValue; // Configurable: e.g. 100, 200, 500
  final String stampPaperState; // Default 'Maharashtra'
  final String stampPaperLanguage; // 'Marathi' or 'English'
  final double stampTopMarginMm; // Gap at top for physical non-judicial stamp paper
  final String? affidavitCustomText; // Custom edited affidavit content
  final String affidavitPlace; // Default e.g. 'Dhule' / 'Nardana'

  // Form X Configuration (Security Deposit)
  final String formXOption; // 'transfer' or 'refund'
  final bool oldConsumerConsent; // Consent given to transfer SD
  final String refundAccountHolderName;
  final String refundBankName;
  final String refundBranch;
  final String refundAccountNumber;
  final String refundIfscCode;
  final String originalReceiptNo;
  final String receiptStatus; // 'Available' or 'Lost'
  final String indemnityBondDetails;

  // Annexure A Supporting Documents
  final List<MsedclDocumentItem> documents;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MsedclChangeOfNameApplication({
    required this.id,
    required this.applicationNo,
    required this.applicationDate,
    this.subDivisionOffice = 'Nardana Sub-Division',
    this.circleOffice = 'Dhule Circle',
    this.village = '',
    this.reasonForChange = MsedclReasonForChange.purchaseOfProperty,
    this.assignedEmployee = 'Rahul',
    this.remarks = '',
    this.status = MsedclApplicationStatus.newEntry,
    this.statusHistory = const [],
    // Old Consumer
    required this.oldFirstName,
    this.oldFatherOrHusbandName = '',
    this.oldSurname = '',
    required this.oldConsumerFullName,
    required this.consumerNo,
    this.oldMobileNo = '',
    this.oldMeterNo = '',
    // New Consumer
    required this.newFirstName,
    this.newFatherOrHusbandName = '',
    this.newSurname = '',
    required this.newConsumerFullName,
    this.newAge = 35,
    required this.newMobileNo,
    this.newPhoneNo = '',
    this.newEmail = '',
    this.newAadhaarNo = '',
    required this.propertyAddress,
    // Stamp Paper Configuration
    this.stampPaperValue = 100.0,
    this.stampPaperState = 'Maharashtra',
    this.stampPaperLanguage = 'Marathi',
    this.stampTopMarginMm = 80.0, // Default 80mm top margin for physical stamp paper
    this.affidavitCustomText,
    this.affidavitPlace = 'Dhule',
    // Form X Configuration
    this.formXOption = 'transfer',
    this.oldConsumerConsent = true,
    this.refundAccountHolderName = '',
    this.refundBankName = '',
    this.refundBranch = '',
    this.refundAccountNumber = '',
    this.refundIfscCode = '',
    this.originalReceiptNo = '',
    this.receiptStatus = 'Available',
    this.indemnityBondDetails = '',
    // Documents
    this.documents = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if Form X option is Transfer
  bool get isFormXTransfer => formXOption.toLowerCase() == 'transfer';

  /// Check if Form X option is Refund
  bool get isFormXRefund => formXOption.toLowerCase() == 'refund';

  /// Received documents count
  int get receivedDocCount => documents.where((d) => d.isReceived).length;

  /// Total applicable documents count
  int get applicableDocCount => documents.where((d) => !d.isNotApplicable).length;

  /// Formatted New Consumer Full Name with Father/Husband Name
  String get computedNewFullName {
    if (newConsumerFullName.trim().isNotEmpty) return newConsumerFullName.trim();
    final parts = [newFirstName, newFatherOrHusbandName, newSurname].where((p) => p.trim().isNotEmpty).toList();
    return parts.join(' ');
  }

  /// Formatted Old Consumer Full Name with Father/Husband Name
  String get computedOldFullName {
    if (oldConsumerFullName.trim().isNotEmpty) return oldConsumerFullName.trim();
    final parts = [oldFirstName, oldFatherOrHusbandName, oldSurname].where((p) => p.trim().isNotEmpty).toList();
    return parts.join(' ');
  }

  MsedclChangeOfNameApplication copyWith({
    String? id,
    String? applicationNo,
    DateTime? applicationDate,
    String? subDivisionOffice,
    String? circleOffice,
    String? village,
    String? reasonForChange,
    String? assignedEmployee,
    String? remarks,
    String? status,
    List<MsedclStatusHistoryEntry>? statusHistory,
    String? oldFirstName,
    String? oldFatherOrHusbandName,
    String? oldSurname,
    String? oldConsumerFullName,
    String? consumerNo,
    String? oldMobileNo,
    String? oldMeterNo,
    String? newFirstName,
    String? newFatherOrHusbandName,
    String? newSurname,
    String? newConsumerFullName,
    int? newAge,
    String? newMobileNo,
    String? newPhoneNo,
    String? newEmail,
    String? newAadhaarNo,
    String? propertyAddress,
    double? stampPaperValue,
    String? stampPaperState,
    String? stampPaperLanguage,
    double? stampTopMarginMm,
    String? affidavitCustomText,
    String? affidavitPlace,
    String? formXOption,
    bool? oldConsumerConsent,
    String? refundAccountHolderName,
    String? refundBankName,
    String? refundBranch,
    String? refundAccountNumber,
    String? refundIfscCode,
    String? originalReceiptNo,
    String? receiptStatus,
    String? indemnityBondDetails,
    List<MsedclDocumentItem>? documents,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MsedclChangeOfNameApplication(
      id: id ?? this.id,
      applicationNo: applicationNo ?? this.applicationNo,
      applicationDate: applicationDate ?? this.applicationDate,
      subDivisionOffice: subDivisionOffice ?? this.subDivisionOffice,
      circleOffice: circleOffice ?? this.circleOffice,
      village: village ?? this.village,
      reasonForChange: reasonForChange ?? this.reasonForChange,
      assignedEmployee: assignedEmployee ?? this.assignedEmployee,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      oldFirstName: oldFirstName ?? this.oldFirstName,
      oldFatherOrHusbandName: oldFatherOrHusbandName ?? this.oldFatherOrHusbandName,
      oldSurname: oldSurname ?? this.oldSurname,
      oldConsumerFullName: oldConsumerFullName ?? this.oldConsumerFullName,
      consumerNo: consumerNo ?? this.consumerNo,
      oldMobileNo: oldMobileNo ?? this.oldMobileNo,
      oldMeterNo: oldMeterNo ?? this.oldMeterNo,
      newFirstName: newFirstName ?? this.newFirstName,
      newFatherOrHusbandName: newFatherOrHusbandName ?? this.newFatherOrHusbandName,
      newSurname: newSurname ?? this.newSurname,
      newConsumerFullName: newConsumerFullName ?? this.newConsumerFullName,
      newAge: newAge ?? this.newAge,
      newMobileNo: newMobileNo ?? this.newMobileNo,
      newPhoneNo: newPhoneNo ?? this.newPhoneNo,
      newEmail: newEmail ?? this.newEmail,
      newAadhaarNo: newAadhaarNo ?? this.newAadhaarNo,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      stampPaperValue: stampPaperValue ?? this.stampPaperValue,
      stampPaperState: stampPaperState ?? this.stampPaperState,
      stampPaperLanguage: stampPaperLanguage ?? this.stampPaperLanguage,
      stampTopMarginMm: stampTopMarginMm ?? this.stampTopMarginMm,
      affidavitCustomText: affidavitCustomText ?? this.affidavitCustomText,
      affidavitPlace: affidavitPlace ?? this.affidavitPlace,
      formXOption: formXOption ?? this.formXOption,
      oldConsumerConsent: oldConsumerConsent ?? this.oldConsumerConsent,
      refundAccountHolderName: refundAccountHolderName ?? this.refundAccountHolderName,
      refundBankName: refundBankName ?? this.refundBankName,
      refundBranch: refundBranch ?? this.refundBranch,
      refundAccountNumber: refundAccountNumber ?? this.refundAccountNumber,
      refundIfscCode: refundIfscCode ?? this.refundIfscCode,
      originalReceiptNo: originalReceiptNo ?? this.originalReceiptNo,
      receiptStatus: receiptStatus ?? this.receiptStatus,
      indemnityBondDetails: indemnityBondDetails ?? this.indemnityBondDetails,
      documents: documents ?? this.documents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'application_no': applicationNo,
      'application_date': applicationDate.toIso8601String(),
      'sub_division_office': subDivisionOffice,
      'circle_office': circleOffice,
      'village': village,
      'reason_for_change': reasonForChange,
      'assigned_employee': assignedEmployee,
      'remarks': remarks,
      'status': status,
      'status_history': statusHistory.map((s) => s.toJson()).toList(),
      'old_first_name': oldFirstName,
      'old_father_or_husband_name': oldFatherOrHusbandName,
      'old_surname': oldSurname,
      'old_consumer_full_name': oldConsumerFullName,
      'consumer_no': consumerNo,
      'old_mobile_no': oldMobileNo,
      'old_meter_no': oldMeterNo,
      'new_first_name': newFirstName,
      'new_father_or_husband_name': newFatherOrHusbandName,
      'new_surname': newSurname,
      'new_consumer_full_name': newConsumerFullName,
      'new_age': newAge,
      'new_mobile_no': newMobileNo,
      'new_phone_no': newPhoneNo,
      'new_email': newEmail,
      'new_aadhaar_no': newAadhaarNo,
      'property_address': propertyAddress,
      'stamp_paper_value': stampPaperValue,
      'stamp_paper_state': stampPaperState,
      'stamp_paper_language': stampPaperLanguage,
      'stamp_top_margin_mm': stampTopMarginMm,
      'affidavit_custom_text': affidavitCustomText,
      'affidavit_place': affidavitPlace,
      'form_x_option': formXOption,
      'old_consumer_consent': oldConsumerConsent,
      'refund_account_holder_name': refundAccountHolderName,
      'refund_bank_name': refundBankName,
      'refund_branch': refundBranch,
      'refund_account_number': refundAccountNumber,
      'refund_ifsc_code': refundIfscCode,
      'original_receipt_no': originalReceiptNo,
      'receipt_status': receiptStatus,
      'indemnity_bond_details': indemnityBondDetails,
      'documents': documents.map((d) => d.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MsedclChangeOfNameApplication.fromJson(Map<String, dynamic> json) {
    // Parse status history
    List<MsedclStatusHistoryEntry> history = [];
    if (json['status_history'] != null && json['status_history'] is List) {
      history = (json['status_history'] as List)
          .map((item) => MsedclStatusHistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Parse documents
    List<MsedclDocumentItem> docs = [];
    if (json['documents'] != null && json['documents'] is List) {
      docs = (json['documents'] as List)
          .map((item) => MsedclDocumentItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      // Default initial document items
      docs = MsedclDocumentType.all.map((t) => MsedclDocumentItem(docType: t)).toList();
    }

    return MsedclChangeOfNameApplication(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      applicationNo: json['application_no'] as String? ?? 'MSEDCL-CN-${DateTime.now().millisecondsSinceEpoch}',
      applicationDate: json['application_date'] != null
          ? DateTime.tryParse(json['application_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      subDivisionOffice: json['sub_division_office'] as String? ?? 'Nardana Sub-Division',
      circleOffice: json['circle_office'] as String? ?? 'Dhule Circle',
      village: json['village'] as String? ?? '',
      reasonForChange: json['reason_for_change'] as String? ?? MsedclReasonForChange.purchaseOfProperty,
      assignedEmployee: json['assigned_employee'] as String? ?? 'Rahul',
      remarks: json['remarks'] as String? ?? '',
      status: json['status'] as String? ?? MsedclApplicationStatus.newEntry,
      statusHistory: history,
      oldFirstName: json['old_first_name'] as String? ?? '',
      oldFatherOrHusbandName: json['old_father_or_husband_name'] as String? ?? '',
      oldSurname: json['old_surname'] as String? ?? '',
      oldConsumerFullName: json['old_consumer_full_name'] as String? ?? '',
      consumerNo: json['consumer_no'] as String? ?? '',
      oldMobileNo: json['old_mobile_no'] as String? ?? '',
      oldMeterNo: json['old_meter_no'] as String? ?? '',
      newFirstName: json['new_first_name'] as String? ?? '',
      newFatherOrHusbandName: json['new_father_or_husband_name'] as String? ?? '',
      newSurname: json['new_surname'] as String? ?? '',
      newConsumerFullName: json['new_consumer_full_name'] as String? ?? '',
      newAge: (json['new_age'] as num?)?.toInt() ?? 35,
      newMobileNo: json['new_mobile_no'] as String? ?? '',
      newPhoneNo: json['new_phone_no'] as String? ?? '',
      newEmail: json['new_email'] as String? ?? '',
      newAadhaarNo: json['new_aadhaar_no'] as String? ?? '',
      propertyAddress: json['property_address'] as String? ?? '',
      stampPaperValue: (json['stamp_paper_value'] as num?)?.toDouble() ?? 100.0,
      stampPaperState: json['stamp_paper_state'] as String? ?? 'Maharashtra',
      stampPaperLanguage: json['stamp_paper_language'] as String? ?? 'Marathi',
      stampTopMarginMm: (json['stamp_top_margin_mm'] as num?)?.toDouble() ?? 80.0,
      affidavitCustomText: json['affidavit_custom_text'] as String?,
      affidavitPlace: json['affidavit_place'] as String? ?? 'Dhule',
      formXOption: json['form_x_option'] as String? ?? 'transfer',
      oldConsumerConsent: json['old_consumer_consent'] as bool? ?? true,
      refundAccountHolderName: json['refund_account_holder_name'] as String? ?? '',
      refundBankName: json['refund_bank_name'] as String? ?? '',
      refundBranch: json['refund_branch'] as String? ?? '',
      refundAccountNumber: json['refund_account_number'] as String? ?? '',
      refundIfscCode: json['refund_ifsc_code'] as String? ?? '',
      originalReceiptNo: json['original_receipt_no'] as String? ?? '',
      receiptStatus: json['receipt_status'] as String? ?? 'Available',
      indemnityBondDetails: json['indemnity_bond_details'] as String? ?? '',
      documents: docs,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
