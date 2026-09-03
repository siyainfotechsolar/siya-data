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
      deleted: json['deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at']) : null,
      deletedBy: json['deleted_by'] as String?,
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
    };
    if (deletedAt != null) {
      map['deleted_at'] = deletedAt!.toUtc().toIso8601String();
    }
    if (deletedBy != null) {
      map['deleted_by'] = deletedBy;
    }
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
    String? createdBy,
    String? updatedBy,
    bool? deleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearDeletedMetadata = false,
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
    );
  }
}
