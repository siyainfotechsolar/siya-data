import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';

import '../services/settings_service.dart';
import '../services/supabase_service.dart';
import '../services/record_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedSectionIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Diagnostics & Telemetry state (preserved)
  bool _isTestingTelemetry = false;
  int _latencyMs = 0;
  bool _serverOnline = false;
  bool _dbConnected = false;
  int _totalUsers = 0;
  int _totalRecords = 0;
  DateTime _lastTelemetryChecked = DateTime.now();

  // User permission state
  String _userRole = 'staff';
  Map<String, dynamic>? _userProfile;
  bool _canEditSettings = false;
  bool _canViewSensitiveBank = false;

  // Form Controllers
  late TextEditingController _companyNameController;
  late TextEditingController _brandNameController;
  late TextEditingController _taglineController;
  late TextEditingController _addressController;
  late TextEditingController _villageCityController;
  late TextEditingController _talukaController;
  late TextEditingController _districtController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _mobileController;
  late TextEditingController _altMobileController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _busRegController;
  late TextEditingController _signatoryNameController;
  late TextEditingController _signatoryDesigController;
  late TextEditingController _discomNameController;

  // GST & Tax
  late TextEditingController _gstinController;
  late TextEditingController _stateCodeController;
  late TextEditingController _hsnCodeController;
  late TextEditingController _solarGstRateController;
  late TextEditingController _stdGstRateController;
  String _gstPricingMode = 'inclusive';
  bool _isSplitGstEnabled = true;

  // Branding Assets (data URI or url)
  String? _logoDataUri;
  String? _stampDataUri;
  String? _signatureDataUri;
  bool _showLogoOnPdf = true;
  bool _showStampOnPdf = true;
  bool _showSignatureOnPdf = true;
  bool _showHeaderOnPdf = true;

  // Quotation
  late TextEditingController _quotPrefixController;
  late TextEditingController _quotValidityController;
  late TextEditingController _quotTermsController;
  late TextEditingController _quotDescController;

  // Invoice
  late TextEditingController _invPrefixController;
  late TextEditingController _invPayTermsController;
  late TextEditingController _invTermsController;
  bool _showBankOnInvoice = true;
  bool _showQrOnInvoice = true;

  // Payment
  late TextEditingController _receiptPrefixController;
  String _defaultPaymentMode = 'Cash';
  List<String> _supportedModes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'];

  // Customer & Solar
  late TextEditingController _solarCapacitiesController;
  late TextEditingController _solarTypesController;
  bool _bankStickerLoanApp = true;
  bool _bankStickerDate = true;

  // Document & PDF
  String _defaultPageSize = 'A4';
  String _defaultOrientation = 'Portrait';

  // App Preferences
  String _dateFormat = 'dd/MM/yyyy';
  String _defaultLanguage = 'English';

  final List<_SettingsSectionItem> _sections = const [
    _SettingsSectionItem('Company Profile', Icons.business_rounded, 'Master company details, registration & contacts'),
    _SettingsSectionItem('GST & Tax Settings', Icons.receipt_long_rounded, 'GSTIN, 70/30 split rule & tax calculations'),
    _SettingsSectionItem('Bank Accounts', Icons.account_balance_rounded, 'Company accounts, IFSC, UPI & disbursement target'),
    _SettingsSectionItem('Logo, Stamp & Signature', Icons.draw_rounded, 'Official branding assets & authorization stamps'),
    _SettingsSectionItem('Quotation Settings', Icons.request_quote_rounded, 'Quotation numbering, validity & standard terms'),
    _SettingsSectionItem('Invoice Settings', Icons.inventory_rounded, 'Invoice prefixes, payment terms & QR preferences'),
    _SettingsSectionItem('Payment Settings', Icons.payments_rounded, 'Accepted payment modes & receipt preferences'),
    _SettingsSectionItem('Customer & Solar Settings', Icons.solar_power_rounded, 'System capacities, solar types & sticker configs'),
    _SettingsSectionItem('Staff & Permissions', Icons.admin_panel_settings_rounded, 'Role capabilities matrix & access protection'),
    _SettingsSectionItem('Document & PDF Settings', Icons.picture_as_pdf_rounded, 'Paper sizes, header layout & template defaults'),
    _SettingsSectionItem('Data Import & Export', Icons.import_export_rounded, 'Excel & CSV backups, exports & templates'),
    _SettingsSectionItem('App Preferences & Health', Icons.tune_rounded, 'System diagnostics, telemetry & formats'),
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadData();
  }

  void _initControllers() {
    final s = SettingsService.currentSettings;

    _companyNameController = TextEditingController(text: s.companyName);
    _brandNameController = TextEditingController(text: s.brandName);
    _taglineController = TextEditingController(text: s.tagline);
    _addressController = TextEditingController(text: s.address);
    _villageCityController = TextEditingController(text: s.villageCity);
    _talukaController = TextEditingController(text: s.taluka);
    _districtController = TextEditingController(text: s.district);
    _stateController = TextEditingController(text: s.state);
    _pincodeController = TextEditingController(text: s.pincode);
    _mobileController = TextEditingController(text: s.mobile);
    _altMobileController = TextEditingController(text: s.alternateMobile);
    _emailController = TextEditingController(text: s.email);
    _websiteController = TextEditingController(text: s.website);
    _busRegController = TextEditingController(text: s.businessRegNo);
    _signatoryNameController = TextEditingController(text: s.signatoryName);
    _signatoryDesigController = TextEditingController(text: s.signatoryDesignation);
    _discomNameController = TextEditingController(text: s.discomName);

    _gstinController = TextEditingController(text: s.gstin);
    _stateCodeController = TextEditingController(text: s.stateCode);
    _hsnCodeController = TextEditingController(text: s.hsnSacCode);
    _solarGstRateController = TextEditingController(text: s.solarSystemGstRate.toString());
    _stdGstRateController = TextEditingController(text: s.standardGstRate.toString());
    _gstPricingMode = s.gstPricingMode;
    _isSplitGstEnabled = s.isSplitGstRuleEnabled;

    _logoDataUri = s.logoUrl;
    _stampDataUri = s.stampUrl;
    _signatureDataUri = s.signatureUrl;
    _showLogoOnPdf = s.showLogoOnPdf;
    _showStampOnPdf = s.showStampOnPdf;
    _showSignatureOnPdf = s.showSignatureOnPdf;
    _showHeaderOnPdf = s.showHeaderOnPdf;

    _quotPrefixController = TextEditingController(text: s.quotationPrefix);
    _quotValidityController = TextEditingController(text: s.quotationValidityDays.toString());
    _quotTermsController = TextEditingController(text: s.quotationTerms);
    _quotDescController = TextEditingController(text: s.defaultSolarDescription);

    _invPrefixController = TextEditingController(text: s.invoicePrefix);
    _invPayTermsController = TextEditingController(text: s.invoicePaymentTerms);
    _invTermsController = TextEditingController(text: s.invoiceTerms);
    _showBankOnInvoice = s.showBankDetailsOnInvoice;
    _showQrOnInvoice = s.showQrOnInvoice;

    _receiptPrefixController = TextEditingController(text: s.receiptPrefix);
    _defaultPaymentMode = s.defaultPaymentMode;
    _supportedModes = List<String>.from(s.supportedPaymentModes);

    _solarCapacitiesController = TextEditingController(text: s.solarCapacityOptions.join(', '));
    _solarTypesController = TextEditingController(text: s.solarSystemTypes.join(', '));
    _bankStickerLoanApp = s.bankStickerIncludeLoanApp;
    _bankStickerDate = s.bankStickerIncludeDate;

    _defaultPageSize = s.defaultPageSize;
    _defaultOrientation = s.defaultOrientation;
    _dateFormat = s.dateFormat;
    _defaultLanguage = s.defaultLanguage;

    // Attach listeners for dirty tracking
    final controllers = [
      _companyNameController, _brandNameController, _taglineController,
      _addressController, _villageCityController, _talukaController,
      _districtController, _stateController, _pincodeController,
      _mobileController, _altMobileController, _emailController,
      _websiteController, _busRegController, _signatoryNameController,
      _signatoryDesigController, _discomNameController, _gstinController,
      _stateCodeController, _hsnCodeController, _solarGstRateController,
      _stdGstRateController, _quotPrefixController, _quotValidityController,
      _quotTermsController, _quotDescController, _invPrefixController,
      _invPayTermsController, _invTermsController, _receiptPrefixController,
      _solarCapacitiesController, _solarTypesController,
    ];
    for (final c in controllers) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_hasChanges && mounted) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _brandNameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _villageCityController.dispose();
    _talukaController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _mobileController.dispose();
    _altMobileController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _busRegController.dispose();
    _signatoryNameController.dispose();
    _signatoryDesigController.dispose();
    _discomNameController.dispose();
    _gstinController.dispose();
    _stateCodeController.dispose();
    _hsnCodeController.dispose();
    _solarGstRateController.dispose();
    _stdGstRateController.dispose();
    _quotPrefixController.dispose();
    _quotValidityController.dispose();
    _quotTermsController.dispose();
    _quotDescController.dispose();
    _invPrefixController.dispose();
    _invPayTermsController.dispose();
    _invTermsController.dispose();
    _receiptPrefixController.dispose();
    _solarCapacitiesController.dispose();
    _solarTypesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Load user profile & permissions
    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        _userProfile = await SupabaseService.fetchProfile(user.id);
        _userRole = (_userProfile?['role'] as String?) ?? 'staff';
      } catch (_) {
        _userRole = 'staff';
      }
    }
    _canEditSettings = SettingsService.canManageSettings(_userProfile, _userRole);
    _canViewSensitiveBank = SettingsService.canViewSensitiveBankDetails(_userProfile, _userRole);

    // 2. Refresh settings from database
    await SettingsService.syncWithDatabase();
    _populateControllers(SettingsService.currentSettings);

    // 3. Telemetry check
    await _checkSystemHealth();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });
    }
  }

  void _populateControllers(CompanySettings s) {
    _companyNameController.text = s.companyName;
    _brandNameController.text = s.brandName;
    _taglineController.text = s.tagline;
    _addressController.text = s.address;
    _villageCityController.text = s.villageCity;
    _talukaController.text = s.taluka;
    _districtController.text = s.district;
    _stateController.text = s.state;
    _pincodeController.text = s.pincode;
    _mobileController.text = s.mobile;
    _altMobileController.text = s.alternateMobile;
    _emailController.text = s.email;
    _websiteController.text = s.website;
    _busRegController.text = s.businessRegNo;
    _signatoryNameController.text = s.signatoryName;
    _signatoryDesigController.text = s.signatoryDesignation;
    _discomNameController.text = s.discomName;

    _gstinController.text = s.gstin;
    _stateCodeController.text = s.stateCode;
    _hsnCodeController.text = s.hsnSacCode;
    _solarGstRateController.text = s.solarSystemGstRate.toString();
    _stdGstRateController.text = s.standardGstRate.toString();
    _gstPricingMode = s.gstPricingMode;
    _isSplitGstEnabled = s.isSplitGstRuleEnabled;

    _logoDataUri = s.logoUrl;
    _stampDataUri = s.stampUrl;
    _signatureDataUri = s.signatureUrl;
    _showLogoOnPdf = s.showLogoOnPdf;
    _showStampOnPdf = s.showStampOnPdf;
    _showSignatureOnPdf = s.showSignatureOnPdf;
    _showHeaderOnPdf = s.showHeaderOnPdf;

    _quotPrefixController.text = s.quotationPrefix;
    _quotValidityController.text = s.quotationValidityDays.toString();
    _quotTermsController.text = s.quotationTerms;
    _quotDescController.text = s.defaultSolarDescription;

    _invPrefixController.text = s.invoicePrefix;
    _invPayTermsController.text = s.invoicePaymentTerms;
    _invTermsController.text = s.invoiceTerms;
    _showBankOnInvoice = s.showBankDetailsOnInvoice;
    _showQrOnInvoice = s.showQrOnInvoice;

    _receiptPrefixController.text = s.receiptPrefix;
    _defaultPaymentMode = s.defaultPaymentMode;
    _supportedModes = List<String>.from(s.supportedPaymentModes);

    _solarCapacitiesController.text = s.solarCapacityOptions.join(', ');
    _solarTypesController.text = s.solarSystemTypes.join(', ');
    _bankStickerLoanApp = s.bankStickerIncludeLoanApp;
    _bankStickerDate = s.bankStickerIncludeDate;

    _defaultPageSize = s.defaultPageSize;
    _defaultOrientation = s.defaultOrientation;
    _dateFormat = s.dateFormat;
    _defaultLanguage = s.defaultLanguage;
  }

  Future<void> _checkSystemHealth() async {
    final sw = Stopwatch()..start();
    try {
      final client = SupabaseService.client;
      await client.from('consumer_records').select('id').limit(1);
      sw.stop();
      _latencyMs = sw.elapsedMilliseconds;
      _serverOnline = true;
      _dbConnected = true;

      final userResp = await client.from('profiles').select('id').count(CountOption.exact);
      _totalUsers = userResp.count;

      final recResp = await client.from('consumer_records').select('id').eq('deleted', false).count(CountOption.exact);
      _totalRecords = recResp.count;
    } catch (_) {
      sw.stop();
      _latencyMs = sw.elapsedMilliseconds > 0 ? sw.elapsedMilliseconds : 999;
      _serverOnline = false;
      _dbConnected = false;
    }
    _lastTelemetryChecked = DateTime.now();
  }

  Future<void> _handleSave() async {
    if (!_canEditSettings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only administrators can modify system settings.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_companyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company Name cannot be empty.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    List<String> parseCommaList(String val, List<String> fallback) {
      final items = val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return items.isNotEmpty ? items : fallback;
    }

    final newSettings = CompanySettings(
      id: 'default',
      companyName: _companyNameController.text.trim(),
      brandName: _brandNameController.text.trim(),
      tagline: _taglineController.text.trim(),
      address: _addressController.text.trim(),
      villageCity: _villageCityController.text.trim(),
      taluka: _talukaController.text.trim(),
      district: _districtController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      mobile: _mobileController.text.trim(),
      alternateMobile: _altMobileController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      businessRegNo: _busRegController.text.trim(),
      signatoryName: _signatoryNameController.text.trim(),
      signatoryDesignation: _signatoryDesigController.text.trim(),
      discomName: _discomNameController.text.trim(),
      gstin: _gstinController.text.trim().toUpperCase(),
      stateCode: _stateCodeController.text.trim(),
      gstPricingMode: _gstPricingMode,
      isSplitGstRuleEnabled: _isSplitGstEnabled,
      hsnSacCode: _hsnCodeController.text.trim(),
      solarSystemGstRate: double.tryParse(_solarGstRateController.text.trim()) ?? 13.80,
      standardGstRate: double.tryParse(_stdGstRateController.text.trim()) ?? 18.00,
      logoUrl: _logoDataUri,
      stampUrl: _stampDataUri,
      signatureUrl: _signatureDataUri,
      showLogoOnPdf: _showLogoOnPdf,
      showStampOnPdf: _showStampOnPdf,
      showSignatureOnPdf: _showSignatureOnPdf,
      showHeaderOnPdf: _showHeaderOnPdf,
      quotationPrefix: _quotPrefixController.text.trim(),
      quotationValidityDays: int.tryParse(_quotValidityController.text.trim()) ?? 30,
      quotationTerms: _quotTermsController.text.trim(),
      defaultSolarDescription: _quotDescController.text.trim(),
      invoicePrefix: _invPrefixController.text.trim(),
      invoicePaymentTerms: _invPayTermsController.text.trim(),
      invoiceTerms: _invTermsController.text.trim(),
      showBankDetailsOnInvoice: _showBankOnInvoice,
      showQrOnInvoice: _showQrOnInvoice,
      supportedPaymentModes: _supportedModes,
      defaultPaymentMode: _defaultPaymentMode,
      receiptPrefix: _receiptPrefixController.text.trim(),
      defaultBankAccountId: SettingsService.defaultBankAccount.id,
      solarCapacityOptions: parseCommaList(_solarCapacitiesController.text, SettingsService.currentSettings.solarCapacityOptions),
      solarSystemTypes: parseCommaList(_solarTypesController.text, SettingsService.currentSettings.solarSystemTypes),
      bankStickerIncludeLoanApp: _bankStickerLoanApp,
      bankStickerIncludeDate: _bankStickerDate,
      defaultPageSize: _defaultPageSize,
      defaultOrientation: _defaultOrientation,
      dateFormat: _dateFormat,
      defaultLanguage: _defaultLanguage,
    );

    await SettingsService.saveSettings(newSettings);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully. All new documents will automatically use updated details.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  void _handleDiscard() {
    _populateControllers(SettingsService.currentSettings);
    setState(() => _hasChanges = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unsaved changes discarded.')),
    );
  }

  Future<void> _pickImage(String type) async {
    if (!_canEditSettings) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) return;

        if (bytes.lengthInBytes > 2 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected image exceeds 2MB limit. Please choose a smaller PNG/JPEG.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final ext = file.extension?.toLowerCase() ?? 'png';
        final mime = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png';
        final dataUri = await SettingsService.processImageForStorage(bytes, mime);

        setState(() {
          if (type == 'logo') _logoDataUri = dataUri;
          if (type == 'stamp') _stampDataUri = dataUri;
          if (type == 'signature') _signatureDataUri = dataUri;
          _hasChanges = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$type asset loaded. Click "Save Changes" to apply permanently.'),
              backgroundColor: const Color(0xFF0F172A),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _removeAsset(String type) {
    if (!_canEditSettings) return;
    setState(() {
      if (type == 'logo') _logoDataUri = null;
      if (type == 'stamp') _stampDataUri = null;
      if (type == 'signature') _signatureDataUri = null;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasChanges) {
          _showExitWarningDialog();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF0F172A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Settings & Master Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Central configuration for company, GST, bank accounts & document templates',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (_hasChanges) ...[
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _handleDiscard,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Discard'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
              ),
              const SizedBox(width: 10),
            ],
            FilledButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : isDesktop
                ? _buildDesktopLayout(theme)
                : _buildMobileLayout(theme),
      ),
    );
  }

  Future<void> _showExitWarningDialog() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have modified settings that have not been saved. Do you want to discard them?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay & Review')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Discard & Leave'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Desktop Layout with Sidebar Navigation ───────────────────────────────────

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Navigation
        SizedBox(
          width: 280,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount: _sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final item = _sections[idx];
                final isSelected = _selectedSectionIndex == idx;
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  leading: Icon(
                    item.icon,
                    size: 20,
                    color: isSelected ? const Color(0xFF0F172A) : Colors.blueGrey.shade600,
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0F172A) : Colors.blueGrey.shade800,
                    ),
                  ),
                  onTap: () => setState(() => _selectedSectionIndex = idx),
                );
              },
            ),
          ),
        ),

        // Active Section Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActiveSectionHeader(),
                const SizedBox(height: 16),
                _buildActiveSectionBody(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile Layout with Horizontal Tabs ───────────────────────────────────────

  Widget _buildMobileLayout(ThemeData theme) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _sections.length,
            itemBuilder: (context, idx) {
              final item = _sections[idx];
              final isSelected = _selectedSectionIndex == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(item.title, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedSectionIndex = idx);
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActiveSectionHeader(),
                const SizedBox(height: 14),
                _buildActiveSectionBody(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSectionHeader() {
    final item = _sections[_selectedSectionIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: const Color(0xFF0F172A), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (!_canEditSettings)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Text(
                'View Only (${_userRole.toUpperCase()})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSectionBody(ThemeData theme) {
    switch (_selectedSectionIndex) {
      case 0:
        return _buildCompanyProfileSection();
      case 1:
        return _buildGstTaxSection();
      case 2:
        return _buildBankAccountsSection();
      case 3:
        return _buildBrandingAssetsSection();
      case 4:
        return _buildQuotationSettingsSection();
      case 5:
        return _buildInvoiceSettingsSection();
      case 6:
        return _buildPaymentSettingsSection();
      case 7:
        return _buildCustomerSolarSection();
      case 8:
        return _buildPermissionsSection();
      case 9:
        return _buildDocumentPdfSection();
      case 10:
        return _buildDataImportExportSection();
      case 11:
      default:
        return _buildAppPreferencesAndDiagnosticsSection(theme);
    }
  }

  // ── 1. Company Profile Section ──────────────────────────────────────────────

  Widget _buildCompanyProfileSection() {
    return _buildCardWrapper(
      title: 'Company Information Master',
      subtitle: 'Official business identity used across all generated customer documentation',
      children: [
        _buildTextField(_companyNameController, 'Company Name (Full Legal Entity)', isRequired: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_brandNameController, 'Brand Name / Trade Name')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_taglineController, 'Business Tagline / Subtitle')),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(_addressController, 'Full Registered Address (for invoices & agreements)', maxLines: 2),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_villageCityController, 'Village / City')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_talukaController, 'Taluka')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_districtController, 'District')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_stateController, 'State')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_pincodeController, 'PIN Code')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_mobileController, 'Primary Mobile Number', isRequired: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_altMobileController, 'Alternate Helpline Contact')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_emailController, 'Official Email Address')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_websiteController, 'Company Website URL')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_signatoryNameController, 'Authorized Signatory Name')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_signatoryDesigController, 'Signatory Designation')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_discomNameController, 'Default Electricity DISCOM (e.g. MSEDCL)')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_busRegController, 'Business Registration Details (Optional)')),
          ],
        ),
      ],
    );
  }

  // ── 2. GST & Tax Settings Section ───────────────────────────────────────────

  Widget _buildGstTaxSection() {
    return _buildCardWrapper(
      title: 'GST & Statutory Tax Configuration',
      subtitle: 'Configures tax rates, GSTIN, and the 70% @ 5% + 30% @ 18% split rule',
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField(_gstinController, 'Company GSTIN Number', hint: '27CVTPK6358P1ZD')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_stateCodeController, 'State Code (e.g. 27 for Maharashtra)')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_hsnCodeController, 'HSN / SAC Master Code', hint: '8466 / 9954')),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable 70/30 Solar Dual-GST Split Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text(
                  'As per MNRE & GST Council: 70% of EPC contract taxable at 5% GST (goods) and 30% taxable at 18% GST (services).',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isSplitGstEnabled,
                onChanged: _canEditSettings
                    ? (val) {
                        setState(() {
                          _isSplitGstEnabled = val;
                          _hasChanges = true;
                        });
                      }
                    : null,
              ),
              const Divider(height: 16),
              Row(
                children: [
                  const Text('Default Pricing Mode: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('GST-Inclusive'),
                    selected: _gstPricingMode == 'inclusive',
                    onSelected: _canEditSettings
                        ? (s) {
                            if (s) setState(() { _gstPricingMode = 'inclusive'; _hasChanges = true; });
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('GST-Exclusive'),
                    selected: _gstPricingMode == 'exclusive',
                    onSelected: _canEditSettings
                        ? (s) {
                            if (s) setState(() { _gstPricingMode = 'exclusive'; _hasChanges = true; });
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 3. Bank Accounts Section ────────────────────────────────────────────────

  Widget _buildBankAccountsSection() {
    final accounts = SettingsService.bankAccounts;

    return _buildCardWrapper(
      title: 'Company Bank Accounts Master',
      subtitle: 'Manage official banking accounts used for customer loan disbursements and invoices',
      headerTrailing: FilledButton.icon(
        onPressed: _canEditSettings ? () => _showAddOrEditBankDialog() : null,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Account'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
      ),
      children: [
        if (accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: Text('No bank accounts configured.')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, idx) {
              final acc = accounts[idx];
              final displayAccount = _canViewSensitiveBank ? acc.accountNo : acc.maskedAccountNo;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: acc.isDefault ? const Color(0xFFF8FAFC) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: acc.isDefault ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0), width: acc.isDefault ? 1.5 : 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance, color: Color(0xFF0F172A), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(acc.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              if (acc.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('PRIMARY / DEFAULT', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                              if (!acc.isActive)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text('INACTIVE', style: TextStyle(color: Colors.red.shade900, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Holder: ${acc.accountHolderName}  |  Branch: ${acc.branch}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(height: 2),
                          Text('Account: $displayAccount  |  IFSC: ${acc.ifscCode}  |  Type: ${acc.accountType}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          if (acc.upiId.isNotEmpty)
                            Text('UPI: ${acc.upiId}', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700)),
                        ],
                      ),
                    ),
                    if (_canEditSettings) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit Account',
                        onPressed: () => _showAddOrEditBankDialog(account: acc),
                      ),
                      if (acc.isActive && !acc.isDefault)
                        IconButton(
                          icon: const Icon(Icons.star_border, size: 20),
                          tooltip: 'Set as Default',
                          onPressed: () async {
                            await SettingsService.saveBankAccount(acc.copyWith(isDefault: true));
                            setState(() {});
                          },
                        ),
                      if (acc.isActive && !acc.isDefault)
                        IconButton(
                          icon: const Icon(Icons.block_outlined, size: 20, color: Colors.red),
                          tooltip: 'Deactivate Account',
                          onPressed: () async {
                            await SettingsService.deactivateBankAccount(acc.id);
                            setState(() {});
                          },
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAddOrEditBankDialog({CompanyBankAccount? account}) async {
    final isEdit = account != null;
    final bankNameCtrl = TextEditingController(text: account?.bankName ?? '');
    final holderCtrl = TextEditingController(text: account?.accountHolderName ?? _companyNameController.text);
    final accNoCtrl = TextEditingController(text: account?.accountNo ?? '');
    final ifscCtrl = TextEditingController(text: account?.ifscCode ?? '');
    final branchCtrl = TextEditingController(text: account?.branch ?? '');
    final upiCtrl = TextEditingController(text: account?.upiId ?? '');
    String accType = account?.accountType ?? 'Current Account';
    bool isDef = account?.isDefault ?? false;
    bool isActive = account?.isActive ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Bank Account' : 'Add Company Bank Account'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(bankNameCtrl, 'Bank Name', hint: 'State Bank of India', isRequired: true),
                  const SizedBox(height: 10),
                  _buildTextField(holderCtrl, 'Account Holder Name', isRequired: true),
                  const SizedBox(height: 10),
                  _buildTextField(accNoCtrl, 'Account Number', isRequired: true),
                  const SizedBox(height: 10),
                  _buildTextField(ifscCtrl, 'IFSC Code', isRequired: true),
                  const SizedBox(height: 10),
                  _buildTextField(branchCtrl, 'Branch Name'),
                  const SizedBox(height: 10),
                  _buildTextField(upiCtrl, 'UPI ID (Optional)'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Account Type'),
                    value: accType,
                    items: const [
                      DropdownMenuItem(value: 'Current Account', child: Text('Current Account')),
                      DropdownMenuItem(value: 'Savings Account', child: Text('Savings Account')),
                      DropdownMenuItem(value: 'Cash Credit / OD', child: Text('Cash Credit / OD')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => accType = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Set as Default Primary Account'),
                    value: isDef,
                    onChanged: (v) => setDialogState(() => isDef = v),
                  ),
                  if (isEdit)
                    SwitchListTile(
                      title: const Text('Account Status Active'),
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (bankNameCtrl.text.trim().isEmpty || accNoCtrl.text.trim().isEmpty || ifscCtrl.text.trim().isEmpty) {
                  return;
                }
                final newAcc = CompanyBankAccount(
                  id: account?.id ?? 'acc-${DateTime.now().millisecondsSinceEpoch}',
                  bankName: bankNameCtrl.text.trim(),
                  accountHolderName: holderCtrl.text.trim(),
                  accountNo: accNoCtrl.text.trim(),
                  ifscCode: ifscCtrl.text.trim().toUpperCase(),
                  branch: branchCtrl.text.trim(),
                  accountType: accType,
                  upiId: upiCtrl.text.trim(),
                  isDefault: isDef,
                  isActive: isActive,
                );
                await SettingsService.saveBankAccount(newAcc);
                if (mounted) {
                  setState(() {});
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Save Account'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. Logo, Stamp & Signature Section ──────────────────────────────────────

  Widget _buildBrandingAssetsSection() {
    return _buildCardWrapper(
      title: 'Company Logo, Stamp & Signatures',
      subtitle: 'Upload and preview assets automatically placed on newly generated documents',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 700;
            return isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAssetCard('Company Logo', 'logo', _logoDataUri, 'assets/images/logo.png')),
                      const SizedBox(width: 14),
                      Expanded(child: _buildAssetCard('Official Stamp', 'stamp', _stampDataUri, 'assets/images/company_stamp_signature_pair.png')),
                      const SizedBox(width: 14),
                      Expanded(child: _buildAssetCard('Authorized Signature', 'signature', _signatureDataUri, null)),
                    ],
                  )
                : Column(
                    children: [
                      _buildAssetCard('Company Logo', 'logo', _logoDataUri, 'assets/images/logo.png'),
                      const SizedBox(height: 12),
                      _buildAssetCard('Official Stamp', 'stamp', _stampDataUri, 'assets/images/company_stamp_signature_pair.png'),
                      const SizedBox(height: 12),
                      _buildAssetCard('Authorized Signature', 'signature', _signatureDataUri, null),
                    ],
                  );
          },
        ),
        const SizedBox(height: 18),
        const Divider(),
        const Text('Default Visibility on Generated PDFs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Company Logo in Header'),
          value: _showLogoOnPdf,
          onChanged: _canEditSettings ? (v) => setState(() { _showLogoOnPdf = v ?? true; _hasChanges = true; }) : null,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Stamp & Signature in Vendor Authorization Block'),
          value: _showStampOnPdf,
          onChanged: _canEditSettings ? (v) => setState(() { _showStampOnPdf = v ?? true; _hasChanges = true; }) : null,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Full Company Header on Quotations and Invoices'),
          value: _showHeaderOnPdf,
          onChanged: _canEditSettings ? (v) => setState(() { _showHeaderOnPdf = v ?? true; _hasChanges = true; }) : null,
        ),
      ],
    );
  }

  Widget _buildAssetCard(String title, String type, String? dataUri, String? fallbackAssetPath) {
    final hasCustom = dataUri != null && dataUri.isNotEmpty;
    Uint8List? previewBytes = SettingsService.decodeImageFromDataUri(dataUri);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: previewBytes != null
                ? Image.memory(previewBytes, fit: BoxFit.contain)
                : (fallbackAssetPath != null
                    ? Image.asset(fallbackAssetPath, fit: BoxFit.contain)
                    : const Center(child: Text('No Signature Uploaded', style: TextStyle(color: Colors.grey, fontSize: 11)))),
          ),
          const SizedBox(height: 8),
          Text(
            hasCustom ? 'Custom Upload Active' : (fallbackAssetPath != null ? 'Using Default App Asset' : 'None Set'),
            style: TextStyle(fontSize: 10.5, color: hasCustom ? const Color(0xFF059669) : Colors.grey.shade700, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _canEditSettings ? () => _pickImage(type) : null,
                icon: const Icon(Icons.upload, size: 14),
                label: Text(hasCustom ? 'Replace' : 'Upload', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              if (hasCustom) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  tooltip: 'Reset to Default',
                  onPressed: _canEditSettings ? () => _removeAsset(type) : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. Quotation Settings Section ───────────────────────────────────────────

  Widget _buildQuotationSettingsSection() {
    return _buildCardWrapper(
      title: 'Quotation Numbering & Defaults',
      subtitle: 'Configures default validity period, numbering prefix, and legal terms',
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField(_quotPrefixController, 'Quotation Number Prefix', hint: 'SIYA-Q-')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_quotValidityController, 'Default Validity Period (Days)', hint: '30')),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(_quotDescController, 'Default Solar System Description', maxLines: 2),
        const SizedBox(height: 12),
        _buildTextField(_quotTermsController, 'Standard Quotation Terms & Conditions', maxLines: 5),
      ],
    );
  }

  // ── 6. Invoice Settings Section ─────────────────────────────────────────────

  Widget _buildInvoiceSettingsSection() {
    return _buildCardWrapper(
      title: 'Tax Invoice Numbering & Payment Terms',
      subtitle: 'Controls invoice prefix, default payment terms, and QR code visibility',
      children: [
        _buildTextField(_invPrefixController, 'Invoice Number Prefix', hint: 'SIYA-INV-'),
        const SizedBox(height: 12),
        _buildTextField(_invPayTermsController, 'Default Payment Terms', hint: '100% advance or bank loan disbursement on delivery.'),
        const SizedBox(height: 12),
        _buildTextField(_invTermsController, 'Standard Invoice Terms & Conditions', maxLines: 4),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Display Primary Bank Account on Invoices'),
          value: _showBankOnInvoice,
          onChanged: _canEditSettings ? (v) => setState(() { _showBankOnInvoice = v; _hasChanges = true; }) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Display Dynamic UPI QR Code for Instant Customer Payment'),
          value: _showQrOnInvoice,
          onChanged: _canEditSettings ? (v) => setState(() { _showQrOnInvoice = v; _hasChanges = true; }) : null,
        ),
      ],
    );
  }

  // ── 7. Payment Settings Section ─────────────────────────────────────────────

  Widget _buildPaymentSettingsSection() {
    return _buildCardWrapper(
      title: 'Payment Modes & Receipts Configuration',
      subtitle: 'Configure accepted payment modes and receipt defaults',
      children: [
        _buildTextField(_receiptPrefixController, 'Payment Receipt Prefix', hint: 'REC-'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Default Payment Mode'),
          value: _defaultPaymentMode,
          items: _supportedModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: _canEditSettings
              ? (v) {
                  if (v != null) setState(() { _defaultPaymentMode = v; _hasChanges = true; });
                }
              : null,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Regulatory Notice: Customer Margin Receipts are loan-documentation records only. They do not alter Customer Pending Amount or modify financial ledgers.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 8. Customer & Solar Settings Section ────────────────────────────────────

  Widget _buildCustomerSolarSection() {
    return _buildCardWrapper(
      title: 'Customer & Solar Engineering Parameters',
      subtitle: 'Default capacities, system types, and file sticker parameters',
      children: [
        _buildTextField(_solarCapacitiesController, 'Solar System Capacity Options (Comma separated)', hint: '2 kW, 3 kW, 4 kW, 5 kW, 6 kW, 10 kW'),
        const SizedBox(height: 12),
        _buildTextField(_solarTypesController, 'Supported Solar System Types (Comma separated)', hint: 'On-Grid Solar System, Off-Grid Solar System, Hybrid Solar System'),
        const SizedBox(height: 16),
        const Divider(),
        const Text('Bank Submission Sticker Options (A4 Sheet, 2 Landscape Stickers)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include Loan Application ID on Sticker'),
          value: _bankStickerLoanApp,
          onChanged: _canEditSettings ? (v) => setState(() { _bankStickerLoanApp = v ?? true; _hasChanges = true; }) : null,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include Submission Date on Sticker'),
          value: _bankStickerDate,
          onChanged: _canEditSettings ? (v) => setState(() { _bankStickerDate = v ?? true; _hasChanges = true; }) : null,
        ),
      ],
    );
  }

  // ── 9. Staff & Permissions Section ──────────────────────────────────────────

  Widget _buildPermissionsSection() {
    return _buildCardWrapper(
      title: 'Staff Roles & Authorization Matrix',
      subtitle: 'Current role capabilities and settings management protection',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF0F172A), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current User Role: ${_userRole.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Email: ${SupabaseService.currentUser?.email ?? "N/A"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _canEditSettings ? const Color(0xFF059669) : Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _canEditSettings ? 'FULL SETTINGS WRITE ACCESS' : 'RESTRICTED VIEW ACCESS',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Role Capabilities Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        _buildPermissionRow('Super Admin / Owner', 'Full control: Edit profile, manage bank accounts, update GST, replace branding assets.'),
        _buildPermissionRow('Admin', 'Full control: All configuration, document templates, and export operations.'),
        _buildPermissionRow('Office Staff', 'View settings and print documents using latest saved master data.'),
        _buildPermissionRow('Viewer / Sales', 'Read-only access with sensitive account numbers masked.'),
      ],
    );
  }

  Widget _buildPermissionRow(String role, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF0F172A).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
            child: Text(role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade800))),
        ],
      ),
    );
  }

  // ── 10. Document & PDF Settings Section ─────────────────────────────────────

  Widget _buildDocumentPdfSection() {
    return _buildCardWrapper(
      title: 'PDF Page Sizes & Document Formats',
      subtitle: 'Sets global paper dimensions and layout parameters',
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Default Paper Size'),
                value: _defaultPageSize,
                items: const [
                  DropdownMenuItem(value: 'A4', child: Text('A4 (210 x 297 mm)')),
                  DropdownMenuItem(value: 'Letter', child: Text('Letter (8.5 x 11 in)')),
                ],
                onChanged: _canEditSettings ? (v) => setState(() { _defaultPageSize = v ?? 'A4'; _hasChanges = true; }) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Default Orientation'),
                value: _defaultOrientation,
                items: const [
                  DropdownMenuItem(value: 'Portrait', child: Text('Portrait (Vertical)')),
                  DropdownMenuItem(value: 'Landscape', child: Text('Landscape (Horizontal)')),
                ],
                onChanged: _canEditSettings ? (v) => setState(() { _defaultOrientation = v ?? 'Portrait'; _hasChanges = true; }) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Document Templates Integrated with Central Master:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              SizedBox(height: 6),
              Text('• Single-Page Bank Loan Solar Quotation (A4 Portrait)', style: TextStyle(fontSize: 11.5)),
              Text('• Official GST Tax Invoice (A4 Portrait with Split-Tax)', style: TextStyle(fontSize: 11.5)),
              Text('• Customer Margin Contribution Receipt (A4 Portrait)', style: TextStyle(fontSize: 11.5)),
              Text('• Bank Work Completion Certificate (A4 Portrait)', style: TextStyle(fontSize: 11.5)),
              Text('• Consumer-Vendor Agreement - Annexure 2 (A4 Portrait)', style: TextStyle(fontSize: 11.5)),
              Text('• Bank File Submission Sticker (A4 Portrait, 2 Landscape Stickers with Safe Margin)', style: TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

  // ── 11. Data Import & Export Section ────────────────────────────────────────

  Widget _buildDataImportExportSection() {
    return _buildCardWrapper(
      title: 'Data Import & Export Management',
      subtitle: 'Export records to CSV/Excel or download sample import templates',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildExportButton(
              title: 'Export Customers (CSV)',
              icon: Icons.people_outline,
              onTap: _exportCustomersCsv,
            ),
            _buildExportButton(
              title: 'Export Invoices (CSV)',
              icon: Icons.receipt_long_outlined,
              onTap: _exportInvoicesCsv,
            ),
            _buildExportButton(
              title: 'Export Quotations (CSV)',
              icon: Icons.request_quote_outlined,
              onTap: _exportQuotationsCsv,
            ),
            _buildExportButton(
              title: 'Download Import Template (CSV)',
              icon: Icons.download_outlined,
              onTap: _downloadImportTemplate,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButton({required String title, required IconData icon, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      icon: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
    );
  }

  Future<void> _exportCustomersCsv() async {
    try {
      final res = await RecordService.fetchRecords(page: 1, pageSize: 1000);
      final records = res.items;
      if (records.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No customer records to export.')));
        return;
      }
      final rows = [
        ['Consumer No', 'Name', 'Mobile', 'Address', 'Capacity', 'Type', 'Total Amount', 'Status'],
        ...records.map((r) => [r.consumerNo, r.name, r.mobile ?? '', r.address ?? '', r.systemCapacity ?? '', r.systemType ?? '', r.totalAmount, r.status]),
      ];
      final csvStr = const ListToCsvConverter().convert(rows);
      await Printing.sharePdf(bytes: Uint8List.fromList(utf8.encode(csvStr)), filename: 'customers_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  Future<void> _exportInvoicesCsv() async {
    try {
      final client = SupabaseService.client;
      final List<dynamic> data = await client.from('customer_invoices').select('invoice_number, consumer_no, customer_name, invoice_date, grand_total, payment_status');
      if (data.isNotEmpty) {
        final rows = [
          ['Invoice No', 'Consumer No', 'Customer Name', 'Date', 'Grand Total', 'Status'],
          ...data.map((r) => [r['invoice_number'], r['consumer_no'], r['customer_name'], r['invoice_date'], r['grand_total'], r['payment_status']]),
        ];
        final csvStr = const ListToCsvConverter().convert(rows);
        await Printing.sharePdf(bytes: Uint8List.fromList(utf8.encode(csvStr)), filename: 'invoices_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No invoice records to export.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice export error: $e')));
    }
  }

  Future<void> _exportQuotationsCsv() async {
    try {
      final client = SupabaseService.client;
      final List<dynamic> data = await client.from('customer_quotations').select('quotation_no, consumer_no, customer_name, quotation_date, grand_total');
      if (data.isNotEmpty) {
        final rows = [
          ['Quotation No', 'Consumer No', 'Customer Name', 'Date', 'Grand Total'],
          ...data.map((r) => [r['quotation_no'], r['consumer_no'], r['customer_name'], r['quotation_date'], r['grand_total']]),
        ];
        final csvStr = const ListToCsvConverter().convert(rows);
        await Printing.sharePdf(bytes: Uint8List.fromList(utf8.encode(csvStr)), filename: 'quotations_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No quotation records to export.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quotation export error: $e')));
    }
  }

  Future<void> _downloadImportTemplate() async {
    final rows = [
      ['Consumer No', 'Customer Name', 'Mobile Number', 'Address', 'System Capacity', 'Site Type', 'Application ID'],
      ['123456789012', 'Ramesh Patil', '9876543210', 'Betawad, Tal. Sindkheda', '3 kW', 'Subsidy', 'APP-2026-001'],
    ];
    final csvStr = const ListToCsvConverter().convert(rows);
    await Printing.sharePdf(bytes: Uint8List.fromList(utf8.encode(csvStr)), filename: 'siya_customer_import_template.csv');
  }

  // ── 12. App Preferences & Diagnostics Section ───────────────────────────────

  Widget _buildAppPreferencesAndDiagnosticsSection(ThemeData theme) {
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

    return Column(
      children: [
        _buildCardWrapper(
          title: 'Display Preferences & Formats',
          subtitle: 'Date formatting and language options',
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Display Date Format'),
                    value: _dateFormat,
                    items: const [
                      DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY (e.g. 17/10/2026)')),
                      DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD (e.g. 2026-10-17)')),
                      DropdownMenuItem(value: 'dd-MMM-yyyy', child: Text('DD-MMM-YYYY (e.g. 17-Oct-2026)')),
                    ],
                    onChanged: _canEditSettings ? (v) => setState(() { _dateFormat = v ?? 'dd/MM/yyyy'; _hasChanges = true; }) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Default App Language'),
                    value: _defaultLanguage,
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English (Default)')),
                      DropdownMenuItem(value: 'Marathi', child: Text('Marathi (मराठी)')),
                    ],
                    onChanged: _canEditSettings ? (v) => setState(() { _defaultLanguage = v ?? 'English'; _hasChanges = true; }) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Telemetry & Diagnostics Cards (Preserved from existing settings_screen)
        _buildCardWrapper(
          title: 'Live System Telemetry & Cluster Diagnostics',
          subtitle: 'Real-time database reachability, latency, and registered data volume',
          headerTrailing: FilledButton.icon(
            onPressed: _isTestingTelemetry
                ? null
                : () async {
                    setState(() => _isTestingTelemetry = true);
                    await _checkSystemHealth();
                    setState(() => _isTestingTelemetry = false);
                  },
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Refresh'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
          ),
          children: [
            _buildTelemetryRow('Server Reachability', _serverOnline ? 'Online' : 'Offline', isOk: _serverOnline),
            _buildTelemetryRow('Database Connection', _dbConnected ? 'Connected (Postgres 15)' : 'Disconnected', isOk: _dbConnected),
            _buildTelemetryRow('Dynamic Query Latency', '$_latencyMs ms', isOk: _latencyMs < 300),
            _buildTelemetryRow('Active Consumer Records', '$_totalRecords Records in Database', isOk: true),
            _buildTelemetryRow('Registered Staff Profiles', '$_totalUsers Accounts', isOk: true),
            _buildTelemetryRow('Last Verified Time', dateFormat.format(_lastTelemetryChecked), isOk: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.grey, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Security Compliance: Diagnostic data is strictly sanitized. Passwords, authorization tokens, and credentials are protected by Row Level Security (RLS).',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryRow(String label, String value, {required bool isOk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isOk ? Icons.check_circle : Icons.cancel, size: 16, color: isOk ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isOk ? Colors.green.shade800 : Colors.red)),
        ],
      ),
    );
  }

  // ── Helper UI Builders ──────────────────────────────────────────────────────

  Widget _buildCardWrapper({
    required String title,
    required String subtitle,
    required List<Widget> children,
    Widget? headerTrailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: !_canEditSettings,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        isDense: true,
      ),
    );
  }
}

class _SettingsSectionItem {
  final String title;
  final IconData icon;
  final String subtitle;

  const _SettingsSectionItem(this.title, this.icon, this.subtitle);
}
