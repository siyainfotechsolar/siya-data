import 'dart:convert';
import 'company_master.dart';

/// Centralized configuration entity containing all system settings across the 12 sections.
class CompanySettings {
  final String id;
  
  // 1. Company Profile
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
  final String signatoryName;
  final String signatoryDesignation;
  final String discomName;

  // 2. GST & Tax Settings
  final String gstin;
  final String stateCode;
  final String gstPricingMode; // 'inclusive' or 'exclusive'
  final bool isSplitGstRuleEnabled; // 70% @ 5% + 30% @ 18%
  final String hsnSacCode;
  final double solarSystemGstRate;
  final double standardGstRate;

  // 3. Logo, Stamp & Signature
  final String? logoUrl;
  final String? stampUrl;
  final String? signatureUrl;
  final bool showLogoOnPdf;
  final bool showStampOnPdf;
  final bool showSignatureOnPdf;
  final bool showHeaderOnPdf;

  // 4. Quotation Settings
  final String quotationPrefix;
  final int quotationValidityDays;
  final String quotationTerms;
  final String defaultSolarDescription;

  // 5. Invoice Settings
  final String invoicePrefix;
  final String invoicePaymentTerms;
  final String invoiceTerms;
  final bool showBankDetailsOnInvoice;
  final bool showQrOnInvoice;

  // 6. Payment Settings
  final List<String> supportedPaymentModes;
  final String defaultPaymentMode;
  final String receiptPrefix;
  final String? defaultBankAccountId;

  // 7. Customer & Solar Settings
  final List<String> solarCapacityOptions;
  final List<String> solarSystemTypes;
  final List<String> documentCategories;
  final List<String> warrantyChecklist;
  final bool bankStickerIncludeLoanApp;
  final bool bankStickerIncludeDate;

  // 8. Document & PDF Settings
  final String defaultPageSize;
  final String defaultOrientation;

  // 9. App Preferences
  final String dateFormat;
  final String defaultLanguage;

  // Metadata
  final DateTime? updatedAt;
  final String? updatedBy;

  const CompanySettings({
    this.id = 'default',
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
    this.signatoryName = 'Manoj Kshirsagar',
    this.signatoryDesignation = 'Managing Director / Partner',
    this.discomName = 'MSEDCL',
    this.gstin = '27CVTPK6358P1ZD',
    this.stateCode = '27',
    this.gstPricingMode = 'inclusive',
    this.isSplitGstRuleEnabled = true,
    this.hsnSacCode = '8466',
    this.solarSystemGstRate = 13.80,
    this.standardGstRate = 18.00,
    this.logoUrl,
    this.stampUrl,
    this.signatureUrl,
    this.showLogoOnPdf = true,
    this.showStampOnPdf = true,
    this.showSignatureOnPdf = true,
    this.showHeaderOnPdf = true,
    this.quotationPrefix = 'SIYA-Q-',
    this.quotationValidityDays = 30,
    this.quotationTerms = '1. Rates are inclusive of Solar Panels, Inverter, Structure, and standard installation.\n2. Net Metering approval as per MSEDCL guidelines.\n3. Subsidy as per MNRE PM Surya Ghar scheme.',
    this.defaultSolarDescription = 'PM Surya Ghar Rooftop Solar PV System with High-Efficiency Mono PERC / TOPCon Modules and Grid-Tied Inverter.',
    this.invoicePrefix = 'SIYA-INV-',
    this.invoicePaymentTerms = '100% advance or bank loan disbursement on delivery.',
    this.invoiceTerms = '1. Goods once sold will not be taken back.\n2. Warranty as per manufacturer terms.\n3. Subject to Dhule Jurisdiction.',
    this.showBankDetailsOnInvoice = true,
    this.showQrOnInvoice = true,
    this.supportedPaymentModes = const ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'],
    this.defaultPaymentMode = 'Cash',
    this.receiptPrefix = 'REC-',
    this.defaultBankAccountId = 'default-sbi',
    this.solarCapacityOptions = const ['2 kW', '3 kW', '4 kW', '5 kW', '6 kW', '10 kW', '15 kW'],
    this.solarSystemTypes = const ['On-Grid Solar System', 'Off-Grid Solar System', 'Hybrid Solar System'],
    this.documentCategories = const ['Aadhar Card', 'Electricity Bill', 'Bank Passbook / Cheque', 'Passport Photo', 'Tax Receipt / Index-2'],
    this.warrantyChecklist = const ['Solar PV Modules (25 Years)', 'Grid-Tied Inverter (5/10 Years)', 'Module Mounting Structure (5 Years)', 'Earthing & Lightning Arrester', 'Net Meter Testing Certificate'],
    this.bankStickerIncludeLoanApp = true,
    this.bankStickerIncludeDate = true,
    this.defaultPageSize = 'A4',
    this.defaultOrientation = 'Portrait',
    this.dateFormat = 'dd/MM/yyyy',
    this.defaultLanguage = 'English',
    this.updatedAt,
    this.updatedBy,
  });

  /// Converts settings to a CompanyMaster instance (preserving existing bank account or applying defaults)
  CompanyMaster toCompanyMaster({
    String? bankName,
    String? branch,
    String? accountNo,
    String? ifscCode,
    String? accountType,
    String? upiId,
  }) {
    return CompanyMaster(
      companyName: companyName,
      brandName: brandName,
      tagline: tagline,
      address: address,
      villageCity: villageCity,
      taluka: taluka,
      district: district,
      state: state,
      pincode: pincode,
      mobile: mobile,
      alternateMobile: alternateMobile,
      email: email,
      website: website,
      businessRegNo: businessRegNo,
      gstin: gstin,
      stateCode: stateCode,
      bankName: bankName ?? 'STATE BANK OF INDIA',
      branch: branch ?? 'Betawad',
      accountNo: accountNo ?? '40662252403',
      ifscCode: ifscCode ?? 'SBIN0004798',
      accountType: accountType ?? 'Current Account',
      upiId: upiId ?? '40662252403@sbi',
      signatoryName: signatoryName,
      signatoryDesignation: signatoryDesignation,
      discomName: discomName,
      logoImagePath: logoUrl,
      stampImagePath: stampUrl,
      signatureImagePath: signatureUrl,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }

  CompanySettings copyWith({
    String? id,
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
    String? signatoryName,
    String? signatoryDesignation,
    String? discomName,
    String? gstin,
    String? stateCode,
    String? gstPricingMode,
    bool? isSplitGstRuleEnabled,
    String? hsnSacCode,
    double? solarSystemGstRate,
    double? standardGstRate,
    String? logoUrl,
    String? stampUrl,
    String? signatureUrl,
    bool? showLogoOnPdf,
    bool? showStampOnPdf,
    bool? showSignatureOnPdf,
    bool? showHeaderOnPdf,
    String? quotationPrefix,
    int? quotationValidityDays,
    String? quotationTerms,
    String? defaultSolarDescription,
    String? invoicePrefix,
    String? invoicePaymentTerms,
    String? invoiceTerms,
    bool? showBankDetailsOnInvoice,
    bool? showQrOnInvoice,
    List<String>? supportedPaymentModes,
    String? defaultPaymentMode,
    String? receiptPrefix,
    String? defaultBankAccountId,
    List<String>? solarCapacityOptions,
    List<String>? solarSystemTypes,
    List<String>? documentCategories,
    List<String>? warrantyChecklist,
    bool? bankStickerIncludeLoanApp,
    bool? bankStickerIncludeDate,
    String? defaultPageSize,
    String? defaultOrientation,
    String? dateFormat,
    String? defaultLanguage,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CompanySettings(
      id: id ?? this.id,
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
      signatoryName: signatoryName ?? this.signatoryName,
      signatoryDesignation: signatoryDesignation ?? this.signatoryDesignation,
      discomName: discomName ?? this.discomName,
      gstin: gstin ?? this.gstin,
      stateCode: stateCode ?? this.stateCode,
      gstPricingMode: gstPricingMode ?? this.gstPricingMode,
      isSplitGstRuleEnabled: isSplitGstRuleEnabled ?? this.isSplitGstRuleEnabled,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      solarSystemGstRate: solarSystemGstRate ?? this.solarSystemGstRate,
      standardGstRate: standardGstRate ?? this.standardGstRate,
      logoUrl: logoUrl ?? this.logoUrl,
      stampUrl: stampUrl ?? this.stampUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      showLogoOnPdf: showLogoOnPdf ?? this.showLogoOnPdf,
      showStampOnPdf: showStampOnPdf ?? this.showStampOnPdf,
      showSignatureOnPdf: showSignatureOnPdf ?? this.showSignatureOnPdf,
      showHeaderOnPdf: showHeaderOnPdf ?? this.showHeaderOnPdf,
      quotationPrefix: quotationPrefix ?? this.quotationPrefix,
      quotationValidityDays: quotationValidityDays ?? this.quotationValidityDays,
      quotationTerms: quotationTerms ?? this.quotationTerms,
      defaultSolarDescription: defaultSolarDescription ?? this.defaultSolarDescription,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoicePaymentTerms: invoicePaymentTerms ?? this.invoicePaymentTerms,
      invoiceTerms: invoiceTerms ?? this.invoiceTerms,
      showBankDetailsOnInvoice: showBankDetailsOnInvoice ?? this.showBankDetailsOnInvoice,
      showQrOnInvoice: showQrOnInvoice ?? this.showQrOnInvoice,
      supportedPaymentModes: supportedPaymentModes ?? this.supportedPaymentModes,
      defaultPaymentMode: defaultPaymentMode ?? this.defaultPaymentMode,
      receiptPrefix: receiptPrefix ?? this.receiptPrefix,
      defaultBankAccountId: defaultBankAccountId ?? this.defaultBankAccountId,
      solarCapacityOptions: solarCapacityOptions ?? this.solarCapacityOptions,
      solarSystemTypes: solarSystemTypes ?? this.solarSystemTypes,
      documentCategories: documentCategories ?? this.documentCategories,
      warrantyChecklist: warrantyChecklist ?? this.warrantyChecklist,
      bankStickerIncludeLoanApp: bankStickerIncludeLoanApp ?? this.bankStickerIncludeLoanApp,
      bankStickerIncludeDate: bankStickerIncludeDate ?? this.bankStickerIncludeDate,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      defaultOrientation: defaultOrientation ?? this.defaultOrientation,
      dateFormat: dateFormat ?? this.dateFormat,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'signatory_name': signatoryName,
      'signatory_designation': signatoryDesignation,
      'discom_name': discomName,
      'gstin': gstin,
      'state_code': stateCode,
      'gst_pricing_mode': gstPricingMode,
      'is_split_gst_rule_enabled': isSplitGstRuleEnabled,
      'hsn_sac_code': hsnSacCode,
      'solar_system_gst_rate': solarSystemGstRate,
      'standard_gst_rate': standardGstRate,
      'logo_url': logoUrl,
      'stamp_url': stampUrl,
      'signature_url': signatureUrl,
      'show_logo_on_pdf': showLogoOnPdf,
      'show_stamp_on_pdf': showStampOnPdf,
      'show_signature_on_pdf': showSignatureOnPdf,
      'show_header_on_pdf': showHeaderOnPdf,
      'quotation_prefix': quotationPrefix,
      'quotation_validity_days': quotationValidityDays,
      'quotation_terms': quotationTerms,
      'default_solar_description': defaultSolarDescription,
      'invoice_prefix': invoicePrefix,
      'invoice_payment_terms': invoicePaymentTerms,
      'invoice_terms': invoiceTerms,
      'show_bank_details_on_invoice': showBankDetailsOnInvoice,
      'show_qr_on_invoice': showQrOnInvoice,
      'supported_payment_modes': supportedPaymentModes,
      'default_payment_mode': defaultPaymentMode,
      'receipt_prefix': receiptPrefix,
      'default_bank_account_id': defaultBankAccountId,
      'solar_capacity_options': solarCapacityOptions,
      'solar_system_types': solarSystemTypes,
      'document_categories': documentCategories,
      'warranty_checklist': warrantyChecklist,
      'bank_sticker_include_loan_app': bankStickerIncludeLoanApp,
      'bank_sticker_include_date': bankStickerIncludeDate,
      'default_page_size': defaultPageSize,
      'default_orientation': defaultOrientation,
      'date_format': dateFormat,
      'default_language': defaultLanguage,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
    };
  }

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val, List<String> fallback) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return fallback;
    }

    return CompanySettings(
      id: json['id'] as String? ?? 'default',
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
      signatoryName: json['signatory_name'] as String? ?? 'Manoj Kshirsagar',
      signatoryDesignation: json['signatory_designation'] as String? ?? 'Managing Director / Partner',
      discomName: json['discom_name'] as String? ?? 'MSEDCL',
      gstin: json['gstin'] as String? ?? '27CVTPK6358P1ZD',
      stateCode: json['state_code'] as String? ?? '27',
      gstPricingMode: json['gst_pricing_mode'] as String? ?? 'inclusive',
      isSplitGstRuleEnabled: json['is_split_gst_rule_enabled'] as bool? ?? true,
      hsnSacCode: json['hsn_sac_code'] as String? ?? '8466',
      solarSystemGstRate: (json['solar_system_gst_rate'] as num?)?.toDouble() ?? 13.80,
      standardGstRate: (json['standard_gst_rate'] as num?)?.toDouble() ?? 18.00,
      logoUrl: json['logo_url'] as String?,
      stampUrl: json['stamp_url'] as String?,
      signatureUrl: json['signature_url'] as String?,
      showLogoOnPdf: json['show_logo_on_pdf'] as bool? ?? true,
      showStampOnPdf: json['show_stamp_on_pdf'] as bool? ?? true,
      showSignatureOnPdf: json['show_signature_on_pdf'] as bool? ?? true,
      showHeaderOnPdf: json['show_header_on_pdf'] as bool? ?? true,
      quotationPrefix: json['quotation_prefix'] as String? ?? 'SIYA-Q-',
      quotationValidityDays: (json['quotation_validity_days'] as num?)?.toInt() ?? 30,
      quotationTerms: json['quotation_terms'] as String? ??
          '1. Rates are inclusive of Solar Panels, Inverter, Structure, and standard installation.\n2. Net Metering approval as per MSEDCL guidelines.\n3. Subsidy as per MNRE PM Surya Ghar scheme.',
      defaultSolarDescription: json['default_solar_description'] as String? ??
          'PM Surya Ghar Rooftop Solar PV System with High-Efficiency Mono PERC / TOPCon Modules and Grid-Tied Inverter.',
      invoicePrefix: json['invoice_prefix'] as String? ?? 'SIYA-INV-',
      invoicePaymentTerms: json['invoice_payment_terms'] as String? ?? '100% advance or bank loan disbursement on delivery.',
      invoiceTerms: json['invoice_terms'] as String? ??
          '1. Goods once sold will not be taken back.\n2. Warranty as per manufacturer terms.\n3. Subject to Dhule Jurisdiction.',
      showBankDetailsOnInvoice: json['show_bank_details_on_invoice'] as bool? ?? true,
      showQrOnInvoice: json['show_qr_on_invoice'] as bool? ?? true,
      supportedPaymentModes: parseList(json['supported_payment_modes'], const ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other']),
      defaultPaymentMode: json['default_payment_mode'] as String? ?? 'Cash',
      receiptPrefix: json['receipt_prefix'] as String? ?? 'REC-',
      defaultBankAccountId: json['default_bank_account_id'] as String? ?? 'default-sbi',
      solarCapacityOptions: parseList(json['solar_capacity_options'], const ['2 kW', '3 kW', '4 kW', '5 kW', '6 kW', '10 kW', '15 kW']),
      solarSystemTypes: parseList(json['solar_system_types'], const ['On-Grid Solar System', 'Off-Grid Solar System', 'Hybrid Solar System']),
      documentCategories: parseList(json['document_categories'], const ['Aadhar Card', 'Electricity Bill', 'Bank Passbook / Cheque', 'Passport Photo', 'Tax Receipt / Index-2']),
      warrantyChecklist: parseList(json['warranty_checklist'], const ['Solar PV Modules (25 Years)', 'Grid-Tied Inverter (5/10 Years)', 'Module Mounting Structure (5 Years)', 'Earthing & Lightning Arrester', 'Net Meter Testing Certificate']),
      bankStickerIncludeLoanApp: json['bank_sticker_include_loan_app'] as bool? ?? true,
      bankStickerIncludeDate: json['bank_sticker_include_date'] as bool? ?? true,
      defaultPageSize: json['default_page_size'] as String? ?? 'A4',
      defaultOrientation: json['default_orientation'] as String? ?? 'Portrait',
      dateFormat: json['date_format'] as String? ?? 'dd/MM/yyyy',
      defaultLanguage: json['default_language'] as String? ?? 'English',
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  static CompanySettings defaultSettings() => const CompanySettings();

  String toJsonString() => jsonEncode(toJson());
  factory CompanySettings.fromJsonString(String str) =>
      CompanySettings.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
