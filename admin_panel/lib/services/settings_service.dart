import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siya_shared/siya_shared.dart';
import 'supabase_service.dart';

/// Central service for loading, caching, synchronizing, and persisting
/// application settings, company profile, GST configuration, and bank accounts.
class SettingsService {
  static const String _settingsPrefKey = 'siya_company_settings_cache_v1';
  static const String _bankAccountsPrefKey = 'siya_company_bank_accounts_cache_v1';

  static CompanySettings _currentSettings = CompanySettings.defaultSettings();
  static List<CompanyBankAccount> _bankAccounts = [CompanyBankAccount.defaultAccount()];
  static bool _isInitialized = false;

  /// Global ValueNotifier so widgets can reactively re-render when settings update
  static final ValueNotifier<CompanySettings> settingsNotifier =
      ValueNotifier<CompanySettings>(CompanySettings.defaultSettings());

  static CompanySettings get currentSettings => _currentSettings;
  static List<CompanyBankAccount> get bankAccounts => List.unmodifiable(_bankAccounts);

  /// Active default company bank account
  static CompanyBankAccount get defaultBankAccount {
    try {
      return _bankAccounts.firstWhere(
        (a) => a.isDefault && a.isActive,
        orElse: () => _bankAccounts.firstWhere(
          (a) => a.isActive,
          orElse: () => CompanyBankAccount.defaultAccount(),
        ),
      );
    } catch (_) {
      return CompanyBankAccount.defaultAccount();
    }
  }

  /// Initialize and hydrate settings from local cache and remote database
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Instant hydration from SharedPreferences (0 ms latency)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSettingsStr = prefs.getString(_settingsPrefKey);
      if (cachedSettingsStr != null && cachedSettingsStr.isNotEmpty) {
        _currentSettings = CompanySettings.fromJsonString(cachedSettingsStr);
      }

      final cachedBanksStr = prefs.getString(_bankAccountsPrefKey);
      if (cachedBanksStr != null && cachedBanksStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cachedBanksStr);
        final parsed = list.map((e) => CompanyBankAccount.fromJson(e as Map<String, dynamic>)).toList();
        if (parsed.isNotEmpty) {
          _bankAccounts = parsed;
        }
      }
    } catch (e) {
      debugPrint('Error reading cached settings: $e');
    }

    _syncToMasterDataHub();
    settingsNotifier.value = _currentSettings;
    _isInitialized = true;

    // 2. Background sync with Supabase
    await syncWithDatabase();
  }

  /// Synchronize with Supabase database (pulls latest master data)
  static Future<void> syncWithDatabase() async {
    try {
      final client = SupabaseService.client;

      // Fetch company settings
      final settingsResp = await client
          .from('company_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();

      if (settingsResp != null) {
        _currentSettings = CompanySettings.fromJson(settingsResp);
        await _saveSettingsToLocalCache(_currentSettings);
      } else {
        // If row doesn't exist, try to seed default row
        try {
          await client.from('company_settings').upsert(_currentSettings.toJson());
        } catch (_) {}
      }

      // Fetch bank accounts
      final List<dynamic> banksResp = await client
          .from('company_bank_accounts')
          .select()
          .order('is_default', ascending: false)
          .order('created_at', ascending: true);

      if (banksResp.isNotEmpty) {
        _bankAccounts = banksResp
            .map((e) => CompanyBankAccount.fromJson(e as Map<String, dynamic>))
            .toList();
        await _saveBanksToLocalCache(_bankAccounts);
      } else {
        // Seed default bank account if none exists
        try {
          await client.from('company_bank_accounts').upsert(CompanyBankAccount.defaultAccount().toJson());
        } catch (_) {}
      }

      _syncToMasterDataHub();
      settingsNotifier.value = _currentSettings;
    } catch (e) {
      debugPrint('SettingsService database sync notice: $e (running with local cached settings)');
    }
  }

  /// Save settings permanently to local cache and Supabase
  static Future<bool> saveSettings(CompanySettings newSettings) async {
    _currentSettings = newSettings.copyWith(updatedAt: DateTime.now());
    await _saveSettingsToLocalCache(_currentSettings);
    _syncToMasterDataHub();
    settingsNotifier.value = _currentSettings;

    bool remoteSuccess = false;
    try {
      final client = SupabaseService.client;
      await client.from('company_settings').upsert(_currentSettings.toJson());
      remoteSuccess = true;
    } catch (e) {
      debugPrint('Remote settings save error: $e');
    }

    return remoteSuccess;
  }

  /// Add or update a bank account
  static Future<bool> saveBankAccount(CompanyBankAccount account) async {
    final list = List<CompanyBankAccount>.from(_bankAccounts);
    final idx = list.indexWhere((a) => a.id == account.id);

    // If new account is marked default, unset isDefault on others
    if (account.isDefault) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].id != account.id) {
          list[i] = list[i].copyWith(isDefault: false);
        }
      }
    }

    if (idx >= 0) {
      list[idx] = account.copyWith(updatedAt: DateTime.now());
    } else {
      list.add(account.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    _bankAccounts = list;
    await _saveBanksToLocalCache(_bankAccounts);
    _syncToMasterDataHub();

    bool remoteSuccess = false;
    try {
      final client = SupabaseService.client;
      // If default changed, update all modified rows
      if (account.isDefault) {
        for (final acc in _bankAccounts) {
          await client.from('company_bank_accounts').upsert(acc.toJson());
        }
      } else {
        await client.from('company_bank_accounts').upsert(account.toJson());
      }
      remoteSuccess = true;
    } catch (e) {
      debugPrint('Remote bank account save error: $e');
    }

    return remoteSuccess;
  }

  /// Deactivates a bank account (preserving historical references)
  static Future<bool> deactivateBankAccount(String accountId) async {
    final list = List<CompanyBankAccount>.from(_bankAccounts);
    final idx = list.indexWhere((a) => a.id == accountId);
    if (idx < 0) return false;

    // Do not deactivate if it's the only active default account
    if (list[idx].isDefault && list.where((a) => a.isActive).length == 1) {
      return false;
    }

    list[idx] = list[idx].copyWith(isActive: false, isDefault: false, updatedAt: DateTime.now());
    _bankAccounts = list;
    await _saveBanksToLocalCache(_bankAccounts);
    _syncToMasterDataHub();

    try {
      final client = SupabaseService.client;
      await client.from('company_bank_accounts').upsert(list[idx].toJson());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Converts image bytes into a data URI or uploads to storage
  static Future<String> processImageForStorage(Uint8List bytes, String mimeType) async {
    // We store images as compact Base64 Data URIs: 'data:image/png;base64,...'
    // This provides 100% reliability in Flutter Web, Desktop, offline mode, and in pdf package.
    final base64Str = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64Str';
  }

  /// Helper to convert base64 Data URI to raw Uint8List for PDF printing
  static Uint8List? decodeImageFromDataUri(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) return null;
    try {
      if (dataUri.startsWith('data:')) {
        final commaIdx = dataUri.indexOf(',');
        if (commaIdx >= 0) {
          final cleanBase64 = dataUri.substring(commaIdx + 1);
          return base64Decode(cleanBase64);
        }
      }
      return base64Decode(dataUri);
    } catch (_) {
      return null;
    }
  }

  /// Synchronize the central MasterDataHub singleton so all downstream documents use the latest info
  static void _syncToMasterDataHub() {
    final defBank = defaultBankAccount;
    final master = _currentSettings.toCompanyMaster(
      bankName: defBank.bankName,
      branch: defBank.branch,
      accountNo: defBank.accountNo,
      ifscCode: defBank.ifscCode,
      accountType: defBank.accountType,
      upiId: defBank.upiId.isNotEmpty ? defBank.upiId : '${defBank.accountNo}@sbi',
    );
    MasterDataHub.setCompanyMaster(master);
  }

  static Future<void> _saveSettingsToLocalCache(CompanySettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsPrefKey, settings.toJsonString());
    } catch (_) {}
  }

  static Future<void> _saveBanksToLocalCache(List<CompanyBankAccount> banks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(banks.map((e) => e.toJson()).toList());
      await prefs.setString(_bankAccountsPrefKey, str);
    } catch (_) {}
  }

  /// Checks if current user has permission to manage settings
  static bool canManageSettings(Map<String, dynamic>? profile, String role) {
    final r = role.toLowerCase().trim();
    if (r == 'admin' || r == 'super_admin' || r == 'owner') return true;

    final perms = profile?['permissions'];
    if (perms is Map && perms['settings'] is List) {
      final actions = (perms['settings'] as List).map((e) => e.toString()).toList();
      return actions.contains('manage') || actions.contains('edit') || actions.contains('write');
    }
    return false;
  }

  /// Checks if current user can view unmasked sensitive bank details
  static bool canViewSensitiveBankDetails(Map<String, dynamic>? profile, String role) {
    final r = role.toLowerCase().trim();
    if (r == 'admin' || r == 'super_admin' || r == 'owner' || r == 'accounts') return true;
    return false;
  }
}
