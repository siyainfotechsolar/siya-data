import 'dart:convert';

/// Global Company Master — Single Source of Truth for Company Information.
/// 
/// When any company detail (Name, Address, Mobile, Email, GST, Bank Details,
/// Signatory, Stamp, Signature) is updated here, it automatically reflects
/// everywhere across the entire application and on newly generated PDFs.
class CompanyMaster {
  final String companyName;
  final String brandName;
  final String tagline;
  final String address;
  final String mobile;
  final String email;
  final String gstin;
  final String bankName;
  final String branch;
  final String accountNo;
  final String ifscCode;
  final String accountType;
  final String signatoryName;
  final String signatoryDesignation;
  final String discomName;
  final String? stampImagePath;
  final String? signatureImagePath;
  final String? logoImagePath;
  final DateTime? updatedAt;
  final String? updatedBy;

  const CompanyMaster({
    this.companyName = 'SIYA INFOTECH & DIGITAL SOLUTIONS',
    this.brandName = 'Siya Solar Energy',
    this.tagline = 'Complete Solar Solutions & EPC Contractor',
    this.address = '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
    this.mobile = '7972143798',
    this.email = 'siyainfodigital@gmail.com',
    this.gstin = '27CVTPK6358P1ZD',
    this.bankName = 'STATE BANK OF INDIA',
    this.branch = 'Betawad',
    this.accountNo = '40662252403',
    this.ifscCode = 'SBIN0004798',
    this.accountType = 'Current Account',
    this.signatoryName = 'Manoj Kshirsagar',
    this.signatoryDesignation = 'Managing Director / Partner',
    this.discomName = 'MSEDCL',
    this.stampImagePath,
    this.signatureImagePath,
    this.logoImagePath,
    this.updatedAt,
    this.updatedBy,
  });

  /// Singleton in-memory instance providing active Master Data
  static CompanyMaster _current = const CompanyMaster();
  static CompanyMaster get current => _current;

  /// Update active in-memory singleton
  static void setGlobal(CompanyMaster master) {
    _current = master;
  }

  /// Default predefined company master
  factory CompanyMaster.defaultMaster() => const CompanyMaster();

  CompanyMaster copyWith({
    String? companyName,
    String? brandName,
    String? tagline,
    String? address,
    String? mobile,
    String? email,
    String? gstin,
    String? bankName,
    String? branch,
    String? accountNo,
    String? ifscCode,
    String? accountType,
    String? signatoryName,
    String? signatoryDesignation,
    String? discomName,
    String? stampImagePath,
    String? signatureImagePath,
    String? logoImagePath,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CompanyMaster(
      companyName: companyName ?? this.companyName,
      brandName: brandName ?? this.brandName,
      tagline: tagline ?? this.tagline,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      accountNo: accountNo ?? this.accountNo,
      ifscCode: ifscCode ?? this.ifscCode,
      accountType: accountType ?? this.accountType,
      signatoryName: signatoryName ?? this.signatoryName,
      signatoryDesignation: signatoryDesignation ?? this.signatoryDesignation,
      discomName: discomName ?? this.discomName,
      stampImagePath: stampImagePath ?? this.stampImagePath,
      signatureImagePath: signatureImagePath ?? this.signatureImagePath,
      logoImagePath: logoImagePath ?? this.logoImagePath,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_name': companyName,
      'brand_name': brandName,
      'tagline': tagline,
      'address': address,
      'mobile': mobile,
      'email': email,
      'gstin': gstin,
      'bank_name': bankName,
      'branch': branch,
      'account_no': accountNo,
      'ifsc_code': ifscCode,
      'account_type': accountType,
      'signatory_name': signatoryName,
      'signatory_designation': signatoryDesignation,
      'discom_name': discomName,
      'stamp_image_path': stampImagePath,
      'signature_image_path': signatureImagePath,
      'logo_image_path': logoImagePath,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  factory CompanyMaster.fromJson(Map<String, dynamic> json) {
    return CompanyMaster(
      companyName: json['company_name'] as String? ?? 'SIYA INFOTECH & DIGITAL SOLUTIONS',
      brandName: json['brand_name'] as String? ?? 'Siya Solar Energy',
      tagline: json['tagline'] as String? ?? 'Complete Solar Solutions & EPC Contractor',
      address: json['address'] as String? ?? '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
      mobile: json['mobile'] as String? ?? '7972143798',
      email: json['email'] as String? ?? 'siyainfodigital@gmail.com',
      gstin: json['gstin'] as String? ?? '27CVTPK6358P1ZD',
      bankName: json['bank_name'] as String? ?? 'STATE BANK OF INDIA',
      branch: json['branch'] as String? ?? 'Betawad',
      accountNo: json['account_no'] as String? ?? '40662252403',
      ifscCode: json['ifsc_code'] as String? ?? 'SBIN0004798',
      accountType: json['account_type'] as String? ?? 'Current Account',
      signatoryName: json['signatory_name'] as String? ?? 'Manoj Kshirsagar',
      signatoryDesignation: json['signatory_designation'] as String? ?? 'Managing Director / Partner',
      discomName: json['discom_name'] as String? ?? 'MSEDCL',
      stampImagePath: json['stamp_image_path'] as String?,
      signatureImagePath: json['signature_image_path'] as String?,
      logoImagePath: json['logo_image_path'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory CompanyMaster.fromJsonString(String source) => CompanyMaster.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
