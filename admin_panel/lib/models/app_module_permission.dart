import 'package:flutter/material.dart';
import 'user_profile.dart';

/// Represents a system module definition in Siya Solar ERP
class AppModuleDefinition {
  final String key;
  final String nameEn;
  final String nameMr;
  final String descriptionEn;
  final String descriptionMr;
  final String category; // 'Operations', 'Finance', 'Tools', 'System'
  final IconData icon;

  const AppModuleDefinition({
    required this.key,
    required this.nameEn,
    required this.nameMr,
    required this.descriptionEn,
    required this.descriptionMr,
    required this.category,
    required this.icon,
  });
}

/// Central catalog of all ERP modules with bilingual names and metadata
class AppModuleRegistry {
  static const List<AppModuleDefinition> allModules = [
    // --- 1. OPERATIONS ---
    AppModuleDefinition(
      key: 'customer',
      nameEn: 'Customer / Consumer Records',
      nameMr: 'ग्राहक नोंदणी व संपूर्ण प्रोफाईल',
      descriptionEn: 'Master consumer records, site progress, customer search & filters',
      descriptionMr: 'ग्राहकांची मुख्य माहिती, साईट काम प्रगती, शोध व तपशील',
      category: 'Operations',
      icon: Icons.people_alt_outlined,
    ),
    AppModuleDefinition(
      key: 'loan',
      nameEn: 'Bank Loans & Sanctions',
      nameMr: 'बँक कर्ज, मंजुरी व कागदपत्रे',
      descriptionEn: 'Bank loan application, sanction letter, disbursement tracking',
      descriptionMr: 'बँक कर्ज अर्ज, मंजुरी पत्र, डिस्बर्समेंट स्थिती',
      category: 'Operations',
      icon: Icons.account_balance_outlined,
    ),
    AppModuleDefinition(
      key: 'installation',
      nameEn: 'Installation & Site Execution',
      nameMr: 'सोलर इन्स्टॉलेशन व साईट कार्य',
      descriptionEn: 'Installer team assignments, structure & inverter work updates',
      descriptionMr: 'इन्स्टॉलेशन टीम नेमणूक, स्ट्रक्चर व इनव्हर्टर काम अपडेट्स',
      category: 'Operations',
      icon: Icons.handyman_outlined,
    ),
    AppModuleDefinition(
      key: 'rts',
      nameEn: 'RTS / Net Metering',
      nameMr: 'महावितरण RTS / नेट मीटरिंग',
      descriptionEn: 'MSEDCL RTS submission, inspection, net meter release',
      descriptionMr: 'महावितरण नेट मीटरिंग, इन्स्पेक्शन, मीटर बसवणे',
      category: 'Operations',
      icon: Icons.electric_meter_outlined,
    ),
    AppModuleDefinition(
      key: 'subsidy',
      nameEn: 'Government Subsidy Processing',
      nameMr: 'शासकीय सबसिडी प्रक्रिया',
      descriptionEn: 'National Portal subsidy claim, verification & credit tracking',
      descriptionMr: 'नॅशनल पोर्टल सबसिडी दावा, व्हेरिफिकेशन व जमा स्थिती',
      category: 'Operations',
      icon: Icons.verified_user_outlined,
    ),
    AppModuleDefinition(
      key: 'followup',
      nameEn: 'Follow-ups & Calling Schedules',
      nameMr: 'फॉलो-अप व कॉलिंग शेड्युल',
      descriptionEn: 'Call logs, pending follow-ups, date-wise scheduling',
      descriptionMr: 'कॉल नोंदी, प्रलंबित फॉलो-अप व शेड्युलिंग',
      category: 'Operations',
      icon: Icons.schedule_outlined,
    ),
    AppModuleDefinition(
      key: 'general_issue',
      nameEn: 'Customer Issues & Complaints',
      nameMr: 'तक्रारी व समस्या निवारण',
      descriptionEn: 'Ticketing system for plant issues, inverter/generation defects',
      descriptionMr: 'ग्राहक तक्रारी, इन्व्हर्टर समस्या व निवारण व्यवस्था',
      category: 'Operations',
      icon: Icons.report_problem_outlined,
    ),
    AppModuleDefinition(
      key: 'leads',
      nameEn: 'CRM / Leads Management',
      nameMr: 'नवीन लीड्स व चौकशी व्यवस्थापन',
      descriptionEn: 'Capture leads, source tracking, status conversion',
      descriptionMr: 'नवीन ग्राहक चौकशी व लीड्स नोंदणी',
      category: 'Operations',
      icon: Icons.leaderboard_outlined,
    ),

    // --- 2. FINANCE ---
    AppModuleDefinition(
      key: 'payment',
      nameEn: 'Payments & Receipts',
      nameMr: 'पेमेंट्स व पावत्या (Margin, Cash, Bank)',
      descriptionEn: 'Customer receipts, margin collection, money receipts',
      descriptionMr: 'ग्राहक जमा रक्कम, मार्जिन पावती व बँक नोंदी',
      category: 'Finance',
      icon: Icons.payments_outlined,
    ),
    AppModuleDefinition(
      key: 'invoices',
      nameEn: 'Tax Invoices & Billing',
      nameMr: 'टॅक्स इनव्हॉइस व बिलिंग',
      descriptionEn: 'Generate and manage customer tax invoices & bill books',
      descriptionMr: 'टॅक्स इनव्हॉइस तयार करणे व व्यवस्थापन',
      category: 'Finance',
      icon: Icons.receipt_long_outlined,
    ),
    AppModuleDefinition(
      key: 'customer_hishob',
      nameEn: 'Customer Hishob & Balances',
      nameMr: 'ग्राहक हिशोब व बाकी रकमा',
      descriptionEn: 'Customer ledger balance, pending collections, share hishob',
      descriptionMr: 'ग्राहक बाकी हिशोब व लेजर स्टेटमेंट',
      category: 'Finance',
      icon: Icons.account_balance_wallet_outlined,
    ),
    AppModuleDefinition(
      key: 'sub_vendor',
      nameEn: 'Sub-Vendor Management',
      nameMr: 'सब-व्हेंडर व्यवस्थापन (लेजर, सेटलमेंट, पेआउट)',
      descriptionEn: 'Vendor sites, inventory issues, Passbook ledger, payouts',
      descriptionMr: 'व्हेंडर साईट्स, मटेरियल, बँक पासबुक लेजर व पेआउट',
      category: 'Finance',
      icon: Icons.engineering_outlined,
    ),
    AppModuleDefinition(
      key: 'commission',
      nameEn: 'Channel Partner & Commissions',
      nameMr: 'कमिशन व एजंट व्यवस्थापन',
      descriptionEn: 'Agent commission tracking, rate per kW, payout approvals',
      descriptionMr: 'एजंट कमिशन ट्रॅकिंग, प्रति किलोवॅट दर व मंजुरी',
      category: 'Finance',
      icon: Icons.monetization_on_outlined,
    ),

    // --- 3. TOOLS ---
    AppModuleDefinition(
      key: 'solar_quotation',
      nameEn: 'Solar Quotation Generator',
      nameMr: 'सोलर कोटेशन जनरेटर (७-पेज व बँक प्रपोजल)',
      descriptionEn: 'Generate 7-page Marathi/English proposals & bank EMI sheets',
      descriptionMr: '७ पानांचे मराठी/इंग्रजी प्रपोजल व बँक ईएमआय कोटेशन',
      category: 'Tools',
      icon: Icons.solar_power_outlined,
    ),
    AppModuleDefinition(
      key: 'solar_cost_calculator',
      nameEn: 'Solar Site Cost Calculator',
      nameMr: 'सोलर साईट खर्च कॅल्क्युलेटर (BOM & Margins)',
      descriptionEn: 'Material cost, labor, statutory GST, profit margins',
      descriptionMr: 'मटेरियल खर्च, मजुरी, जीएसटी व नफा कॅल्क्युलेटर',
      category: 'Tools',
      icon: Icons.calculate_outlined,
    ),
    AppModuleDefinition(
      key: 'whatsapp',
      nameEn: 'WhatsApp Automation',
      nameMr: 'व्हॉट्सॲप ऑटोमेशन व मेसेजिंग',
      descriptionEn: 'Send updates, stage alerts, and payment reminders via WhatsApp',
      descriptionMr: 'व्हॉट्सॲप मेसेज व अपडेट्स पाठवणे',
      category: 'Tools',
      icon: Icons.share_rounded,
    ),
    AppModuleDefinition(
      key: 'import',
      nameEn: 'Excel / CSV Import',
      nameMr: 'एक्सेल डेटा इम्पोर्ट',
      descriptionEn: 'Bulk import records and consumer spreadsheets',
      descriptionMr: 'एक्सेल फाईलमधून डेटा आयात करणे',
      category: 'Tools',
      icon: Icons.upload_file_outlined,
    ),
    AppModuleDefinition(
      key: 'reports',
      nameEn: 'Reports & Analytics',
      nameMr: 'अहवाल, आकडेवारी व एक्सपोर्ट',
      descriptionEn: 'Business summaries, stage analytics, Excel/PDF exports',
      descriptionMr: 'बिझनेस रिपोर्ट व ॲनालिटिक्स',
      category: 'Tools',
      icon: Icons.bar_chart_outlined,
    ),

    // --- 4. SYSTEM ---
    AppModuleDefinition(
      key: 'user_management',
      nameEn: 'User & Staff Management',
      nameMr: 'कर्मचारी व युझर व्यवस्थापन',
      descriptionEn: 'Create logins, set passwords, manage roles & permissions',
      descriptionMr: 'कर्मचारी लॉगिन, पासवर्ड व परवानग्या व्यवस्थापन',
      category: 'System',
      icon: Icons.group_outlined,
    ),
    AppModuleDefinition(
      key: 'settings',
      nameEn: 'System Settings & Audit',
      nameMr: 'सिस्टीम सेटिंग्ज व ऑडिट लॉग्स',
      descriptionEn: 'Audit trails, bank defaults, company profile, app configs',
      descriptionMr: 'ऑडिट लॉग्स व सिस्टीम कॉन्फिगरेशन',
      category: 'System',
      icon: Icons.settings_outlined,
    ),
  ];

  static List<String> get categories => ['All', 'Operations', 'Finance', 'Tools', 'System'];

  /// Check if user has View permission for a module
  static bool hasView(Map<String, List<String>> perms, String moduleKey) {
    final list = perms[moduleKey.toLowerCase()];
    if (list == null) return false;
    return list.contains('*') || list.contains('view');
  }

  /// Check if user has Edit / Create permission for a module
  static bool hasEdit(Map<String, List<String>> perms, String moduleKey) {
    final list = perms[moduleKey.toLowerCase()];
    if (list == null) return false;
    return list.contains('*') ||
        list.contains('edit') ||
        list.contains('create') ||
        list.contains('update');
  }

  /// Check if user has Delete permission for a module
  static bool hasDelete(Map<String, List<String>> perms, String moduleKey) {
    final list = perms[moduleKey.toLowerCase()];
    if (list == null) return false;
    return list.contains('*') || list.contains('delete');
  }

  /// Generate a clean Map with View, Edit, Delete toggles applied logically
  static Map<String, List<String>> setModulePermission({
    required Map<String, List<String>> currentPerms,
    required String moduleKey,
    required String action, // 'view', 'edit', 'delete'
    required bool enabled,
  }) {
    final copy = Map<String, List<String>>.from(
      currentPerms.map((k, v) => MapEntry(k, List<String>.from(v))),
    );

    final mKey = moduleKey.toLowerCase();
    var actions = List<String>.from(copy[mKey] ?? []);

    if (action == 'view') {
      if (enabled) {
        if (!actions.contains('view')) actions.add('view');
      } else {
        // If view is disabled, all permissions for this module are revoked
        actions.clear();
      }
    } else if (action == 'edit') {
      if (enabled) {
        if (!actions.contains('view')) actions.add('view');
        if (!actions.contains('create')) actions.add('create');
        if (!actions.contains('edit')) actions.add('edit');
      } else {
        actions.remove('edit');
        actions.remove('create');
        actions.remove('update');
      }
    } else if (action == 'delete') {
      if (enabled) {
        if (!actions.contains('view')) actions.add('view');
        if (!actions.contains('delete')) actions.add('delete');
      } else {
        actions.remove('delete');
      }
    }

    if (actions.isEmpty) {
      copy.remove(mKey);
    } else {
      copy[mKey] = actions;
    }

    return copy;
  }

  /// Full Access Preset: Grants View, Edit, Delete across all modules
  static Map<String, List<String>> fullAccessPermissions() {
    final map = <String, List<String>>{};
    for (final mod in allModules) {
      map[mod.key] = ['view', 'create', 'edit', 'delete'];
    }
    return map;
  }

  /// Read Only Preset: Grants View only across all modules
  static Map<String, List<String>> readOnlyPermissions() {
    final map = <String, List<String>>{};
    for (final mod in allModules) {
      map[mod.key] = ['view'];
    }
    return map;
  }

  /// No Access Preset: Clears all permissions
  static Map<String, List<String>> noAccessPermissions() {
    return <String, List<String>>{};
  }

  /// Reset to standard Role Defaults
  static Map<String, List<String>> roleDefaultPermissions(String role) {
    return UserRole.defaultPermissions(role);
  }
}
