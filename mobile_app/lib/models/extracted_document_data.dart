class ExtractedDocumentData {
  final String rawText;
  final String? customerName;
  final String? consumerNo;
  final String? mobileNumber;
  final String? applicationId;
  final String? village;
  final String? billDate;
  final String? dueDate;
  final double? billAmount;
  final String? documentNumber;
  final String detectedDocType; // 'Electricity Bill', 'Loan Document', 'Payment Proof', 'Agreement', 'RTS', 'Subsidy', 'Installation', 'Other'
  final Map<String, dynamic>? paymentCandidate;
  final Map<String, String> confidenceMap;

  const ExtractedDocumentData({
    this.rawText = '',
    this.customerName,
    this.consumerNo,
    this.mobileNumber,
    this.applicationId,
    this.village,
    this.billDate,
    this.dueDate,
    this.billAmount,
    this.documentNumber,
    this.detectedDocType = 'Other',
    this.paymentCandidate,
    this.confidenceMap = const {},
  });

  bool get hasCustomerIdentifiers =>
      (consumerNo != null && consumerNo!.trim().isNotEmpty) ||
      (applicationId != null && applicationId!.trim().isNotEmpty) ||
      (mobileNumber != null && mobileNumber!.trim().isNotEmpty) ||
      (customerName != null && customerName!.trim().isNotEmpty);

  bool get isPaymentProof =>
      detectedDocType == 'Payment Proof' || paymentCandidate != null;

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'consumerNo': consumerNo,
      'mobileNumber': mobileNumber,
      'applicationId': applicationId,
      'village': village,
      'billDate': billDate,
      'dueDate': dueDate,
      'billAmount': billAmount,
      'documentNumber': documentNumber,
      'detectedDocType': detectedDocType,
      'paymentCandidate': paymentCandidate,
      'confidenceMap': confidenceMap,
    };
  }

  factory ExtractedDocumentData.fromMap(Map<String, dynamic> map) {
    return ExtractedDocumentData(
      rawText: map['rawText'] as String? ?? '',
      customerName: map['customerName'] as String?,
      consumerNo: map['consumerNo'] as String?,
      mobileNumber: map['mobileNumber'] as String?,
      applicationId: map['applicationId'] as String?,
      village: map['village'] as String?,
      billDate: map['billDate'] as String?,
      dueDate: map['dueDate'] as String?,
      billAmount: (map['billAmount'] as num?)?.toDouble(),
      documentNumber: map['documentNumber'] as String?,
      detectedDocType: map['detectedDocType'] as String? ?? 'Other',
      paymentCandidate: map['paymentCandidate'] != null
          ? Map<String, dynamic>.from(map['paymentCandidate'] as Map)
          : null,
      confidenceMap: map['confidenceMap'] != null
          ? Map<String, String>.from(map['confidenceMap'] as Map)
          : const {},
    );
  }

  ExtractedDocumentData copyWith({
    String? rawText,
    String? customerName,
    String? consumerNo,
    String? mobileNumber,
    String? applicationId,
    String? village,
    String? billDate,
    String? dueDate,
    double? billAmount,
    String? documentNumber,
    String? detectedDocType,
    Map<String, dynamic>? paymentCandidate,
    Map<String, String>? confidenceMap,
  }) {
    return ExtractedDocumentData(
      rawText: rawText ?? this.rawText,
      customerName: customerName ?? this.customerName,
      consumerNo: consumerNo ?? this.consumerNo,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      applicationId: applicationId ?? this.applicationId,
      village: village ?? this.village,
      billDate: billDate ?? this.billDate,
      dueDate: dueDate ?? this.dueDate,
      billAmount: billAmount ?? this.billAmount,
      documentNumber: documentNumber ?? this.documentNumber,
      detectedDocType: detectedDocType ?? this.detectedDocType,
      paymentCandidate: paymentCandidate ?? this.paymentCandidate,
      confidenceMap: confidenceMap ?? this.confidenceMap,
    );
  }
}
