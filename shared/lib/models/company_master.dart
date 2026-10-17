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
  final String villageCity;
  final String taluka;
  final String district;
  final String state;
  final String pincode;
  final String mobile;
  final String alternateMobile;
  final String email;
  final String website;
  final String businessRegNo;
  final String gstin;
  final String stateCode;
  final String bankName;
  final String branch;
  final String accountNo;
  final String ifscCode;
  final String accountType;
  final String upiId;
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
    this.villageCity = 'Betawad',
    this.taluka = 'Shindkheda',
    this.district = 'Dhule',
    this.state = 'Maharashtra',
    this.pincode = '425403',
    this.mobile = '7972143798',
    this.alternateMobile = '7588003220',
    this.email = 'siyainfodigital@gmail.com',
    this.website = 'https://siyainfotechsolar.com',
    this.businessRegNo = '',
    this.gstin = '27CVTPK6358P1ZD',
    this.stateCode = '27',
    this.bankName = 'STATE BANK OF INDIA',
    this.branch = 'Betawad',
    this.accountNo = '40662252403',
    this.ifscCode = 'SBIN0004798',
    this.accountType = 'Current Account',
    this.upiId = '40662252403@sbi',
    this.signatoryName = 'Manoj Kshirsagar',
    this.signatoryDesignation = 'Managing Director / Partner',
    this.discomName = 'MSEDCL',
    this.stampImagePath,
    this.signatureImagePath,
    this.logoImagePath,
    this.updatedAt,
    this.updatedBy,
  });

  /// Formatted contact display (both phones if available)
  String get displayPhones {
    if (alternateMobile.isNotEmpty && alternateMobile != mobile) {
      return '$mobile / $alternateMobile';
    }
    return mobile;
  }

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
    String? villageCity,
    String? taluka,
    String? district,
    String? state,
    String? pincode,
    String? mobile,
    String? alternateMobile,
    String? email,
    String? website,
    String? businessRegNo,
    String? gstin,
    String? stateCode,
    String? bankName,
    String? branch,
    String? accountNo,
    String? ifscCode,
    String? accountType,
    String? upiId,
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
      villageCity: villageCity ?? this.villageCity,
      taluka: taluka ?? this.taluka,
      district: district ?? this.district,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      mobile: mobile ?? this.mobile,
      alternateMobile: alternateMobile ?? this.alternateMobile,
      email: email ?? this.email,
      website: website ?? this.website,
      businessRegNo: businessRegNo ?? this.businessRegNo,
      gstin: gstin ?? this.gstin,
      stateCode: stateCode ?? this.stateCode,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      accountNo: accountNo ?? this.accountNo,
      ifscCode: ifscCode ?? this.ifscCode,
      accountType: accountType ?? this.accountType,
      upiId: upiId ?? this.upiId,
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
      'village_city': villageCity,
      'taluka': taluka,
      'district': district,
      'state': state,
      'pincode': pincode,
      'mobile': mobile,
      'alternate_mobile': alternateMobile,
      'email': email,
      'website': website,
      'business_reg_no': businessRegNo,
      'gstin': gstin,
      'state_code': stateCode,
      'bank_name': bankName,
      'branch': branch,
      'account_no': accountNo,
      'ifsc_code': ifscCode,
      'account_type': accountType,
      'upi_id': upiId,
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
      villageCity: json['village_city'] as String? ?? 'Betawad',
      taluka: json['taluka'] as String? ?? 'Shindkheda',
      district: json['district'] as String? ?? 'Dhule',
      state: json['state'] as String? ?? 'Maharashtra',
      pincode: json['pincode'] as String? ?? '425403',
      mobile: json['mobile'] as String? ?? '7972143798',
      alternateMobile: json['alternate_mobile'] as String? ?? '7588003220',
      email: json['email'] as String? ?? 'siyainfodigital@gmail.com',
      website: json['website'] as String? ?? 'https://siyainfotechsolar.com',
      businessRegNo: json['business_reg_no'] as String? ?? '',
      gstin: json['gstin'] as String? ?? '27CVTPK6358P1ZD',
      stateCode: json['state_code'] as String? ?? '27',
      bankName: json['bank_name'] as String? ?? 'STATE BANK OF INDIA',
      branch: json['branch'] as String? ?? 'Betawad',
      accountNo: json['account_no'] as String? ?? '40662252403',
      ifscCode: json['ifsc_code'] as String? ?? 'SBIN0004798',
      accountType: json['account_type'] as String? ?? 'Current Account',
      upiId: json['upi_id'] as String? ?? '40662252403@sbi',
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
