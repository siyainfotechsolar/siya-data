import 'dart:convert';

/// Represents a company bank account used across invoices, quotations, and banking operations.
class CompanyBankAccount {
  final String id;
  final String bankName;
  final String accountHolderName;
  final String accountNo;
  final String ifscCode;
  final String branch;
  final String accountType;
  final String upiId;
  final bool isActive;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CompanyBankAccount({
    required this.id,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNo,
    required this.ifscCode,
    this.branch = '',
    this.accountType = 'Current Account',
    this.upiId = '',
    this.isActive = true,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Returns masked account number (e.g. "•••• •••• 2403") for restricted viewers
  String get maskedAccountNo {
    final cleaned = accountNo.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length <= 4) return cleaned;
    final last4 = cleaned.substring(cleaned.length - 4);
    return '•••• •••• $last4';
  }

  CompanyBankAccount copyWith({
    String? id,
    String? bankName,
    String? accountHolderName,
    String? accountNo,
    String? ifscCode,
    String? branch,
    String? accountType,
    String? upiId,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyBankAccount(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNo: accountNo ?? this.accountNo,
      ifscCode: ifscCode ?? this.ifscCode,
      branch: branch ?? this.branch,
      accountType: accountType ?? this.accountType,
      upiId: upiId ?? this.upiId,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'account_holder_name': accountHolderName,
      'account_no': accountNo,
      'ifsc_code': ifscCode,
      'branch': branch,
      'account_type': accountType,
      'upi_id': upiId,
      'is_active': isActive,
      'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory CompanyBankAccount.fromJson(Map<String, dynamic> json) {
    return CompanyBankAccount(
      id: json['id'] as String? ?? 'acc-${DateTime.now().millisecondsSinceEpoch}',
      bankName: json['bank_name'] as String? ?? '',
      accountHolderName: json['account_holder_name'] as String? ?? '',
      accountNo: json['account_no'] as String? ?? '',
      ifscCode: json['ifsc_code'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      accountType: json['account_type'] as String? ?? 'Current Account',
      upiId: json['upi_id'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  static CompanyBankAccount defaultAccount() {
    return const CompanyBankAccount(
      id: 'default-sbi',
      bankName: 'STATE BANK OF INDIA',
      accountHolderName: 'SIYA INFOTECH & DIGITAL SOLUTIONS',
      accountNo: '40662252403',
      ifscCode: 'SBIN0004798',
      branch: 'Betawad',
      accountType: 'Current Account',
      upiId: '40662252403@sbi',
      isActive: true,
      isDefault: true,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory CompanyBankAccount.fromJsonString(String str) =>
      CompanyBankAccount.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
