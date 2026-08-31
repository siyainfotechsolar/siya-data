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
  });

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
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
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
    );
  }
}
