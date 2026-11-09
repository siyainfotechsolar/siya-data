import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/user_profile.dart';
import 'package:admin_panel/models/app_module_permission.dart';

void main() {
  group('Phase 9: User & Permission Management Tests', () {
    test('UserProfile model deserialization and getters', () {
      final json = {
        'id': 'user-123',
        'email': 'staff@siya.com',
        'full_name': 'Rohan Patil',
        'role': 'staff',
        'mobile': '9876543210',
        'employee_id': 'SIYA-101',
        'department': 'Operations',
        'status': 'Active',
        'is_active': true,
        'can_delete': false,
        'created_at': '2026-09-01T10:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.email, 'staff@siya.com');
      expect(profile.fullName, 'Rohan Patil');
      expect(profile.role, 'staff');
      expect(profile.mobile, '9876543210');
      expect(profile.employeeId, 'SIYA-101');
      expect(profile.department, 'Operations');
      expect(profile.status, 'Active');
      expect(profile.isStaff, isTrue);
      expect(profile.isAdmin, isFalse);
      expect(profile.isActive, isTrue);
      expect(profile.canDelete, isFalse);
    });

    test('UserProfile copyWith updates permissions accurately', () {
      final profile = UserProfile(
        id: 'admin-1',
        email: 'admin@siya.com',
        role: 'admin',
        isActive: true,
        canDelete: true,
      );

      final updated = profile.copyWith(canDelete: false, role: 'staff');

      expect(updated.id, 'admin-1');
      expect(updated.role, 'staff');
      expect(updated.isStaff, isTrue);
      expect(updated.canDelete, isFalse);
      expect(updated.isActive, isTrue);
    });

    test('UserProfile serialization matches Supabase profiles table schema', () {
      final profile = UserProfile(
        id: 'u-99',
        email: 'test@siya.com',
        fullName: 'Test User',
        role: 'admin',
        mobile: '9123456789',
        employeeId: 'SIYA-99',
        department: 'Management',
        status: 'Inactive',
        isActive: false,
        canDelete: true,
      );

      final json = profile.toJson();

      expect(json['id'], 'u-99');
      expect(json['email'], 'test@siya.com');
      expect(json['full_name'], 'Test User');
      expect(json['role'], 'admin');
      expect(json['mobile'], '9123456789');
      expect(json['employee_id'], 'SIYA-99');
      expect(json['department'], 'Management');
      expect(json['status'], 'Inactive');
      expect(json['is_active'], isFalse);
      expect(json['can_delete'], isTrue);
    });

    test('Granular permissions evaluation works accurately', () {
      final officeStaff = UserProfile(
        id: 'u-1',
        email: 'office@siya.com',
        role: UserRole.officeStaff,
      );

      expect(officeStaff.hasPermission('customer', 'view'), isTrue);
      expect(officeStaff.hasPermission('customer', 'edit'), isTrue);
      expect(officeStaff.hasPermission('customer', 'delete'), isFalse);
      expect(officeStaff.hasPermission('user_management', 'create'), isFalse);

      final admin = UserProfile(
        id: 'u-admin',
        email: 'admin@siya.com',
        role: UserRole.admin,
      );

      expect(admin.hasPermission('customer', 'delete'), isTrue);
      expect(admin.hasPermission('user_management', 'create'), isTrue);
      expect(admin.hasPermission('settings', 'edit'), isTrue);
    });

    test('AppModuleRegistry catalogs all 20 ERP modules with categories and bilingual labels', () {
      final all = AppModuleRegistry.allModules;
      expect(all.length, 20);

      final keys = all.map((m) => m.key).toSet();
      expect(keys.contains('customer'), isTrue);
      expect(keys.contains('loan'), isTrue);
      expect(keys.contains('installation'), isTrue);
      expect(keys.contains('rts'), isTrue);
      expect(keys.contains('subsidy'), isTrue);
      expect(keys.contains('payment'), isTrue);
      expect(keys.contains('invoices'), isTrue);
      expect(keys.contains('customer_hishob'), isTrue);
      expect(keys.contains('sub_vendor'), isTrue);
      expect(keys.contains('commission'), isTrue);
      expect(keys.contains('solar_quotation'), isTrue);
      expect(keys.contains('solar_cost_calculator'), isTrue);
      expect(keys.contains('followup'), isTrue);
      expect(keys.contains('general_issue'), isTrue);
      expect(keys.contains('leads'), isTrue);
      expect(keys.contains('whatsapp'), isTrue);
      expect(keys.contains('import'), isTrue);
      expect(keys.contains('reports'), isTrue);
      expect(keys.contains('user_management'), isTrue);
      expect(keys.contains('settings'), isTrue);

      for (final mod in all) {
        expect(mod.nameMr.isNotEmpty, isTrue);
        expect(mod.nameEn.isNotEmpty, isTrue);
        expect(mod.descriptionMr.isNotEmpty, isTrue);
        expect(mod.descriptionEn.isNotEmpty, isTrue);
        expect(
          ['Operations', 'Finance', 'Tools', 'System'].contains(mod.category),
          isTrue,
          reason: '${mod.key} has invalid category ${mod.category}',
        );
      }
    });

    test('AppModuleRegistry Presets: Full Access, Read Only, No Access, and Role Default', () {
      // 1. Full Access
      final full = AppModuleRegistry.fullAccessPermissions();
      expect(full.length, 20);
      for (final mod in AppModuleRegistry.allModules) {
        expect(AppModuleRegistry.hasView(full, mod.key), isTrue);
        expect(AppModuleRegistry.hasEdit(full, mod.key), isTrue);
        expect(AppModuleRegistry.hasDelete(full, mod.key), isTrue);
      }

      // 2. Read Only
      final ro = AppModuleRegistry.readOnlyPermissions();
      expect(ro.length, 20);
      for (final mod in AppModuleRegistry.allModules) {
        expect(AppModuleRegistry.hasView(ro, mod.key), isTrue);
        expect(AppModuleRegistry.hasEdit(ro, mod.key), isFalse);
        expect(AppModuleRegistry.hasDelete(ro, mod.key), isFalse);
      }

      // 3. No Access
      final noAcc = AppModuleRegistry.noAccessPermissions();
      expect(noAcc.isEmpty, isTrue);
      for (final mod in AppModuleRegistry.allModules) {
        expect(AppModuleRegistry.hasView(noAcc, mod.key), isFalse);
        expect(AppModuleRegistry.hasEdit(noAcc, mod.key), isFalse);
        expect(AppModuleRegistry.hasDelete(noAcc, mod.key), isFalse);
      }
    });

    test('Permission toggle logic: turning off View cascades to Edit & Delete; turning on Edit/Delete grants View', () {
      var perms = <String, List<String>>{};

      // Initially no access
      expect(AppModuleRegistry.hasView(perms, 'sub_vendor'), isFalse);
      expect(AppModuleRegistry.hasEdit(perms, 'sub_vendor'), isFalse);
      expect(AppModuleRegistry.hasDelete(perms, 'sub_vendor'), isFalse);

      // Turn ON Edit directly -> should also automatically grant View
      perms = AppModuleRegistry.setModulePermission(
        currentPerms: perms,
        moduleKey: 'sub_vendor',
        action: 'edit',
        enabled: true,
      );
      expect(AppModuleRegistry.hasView(perms, 'sub_vendor'), isTrue);
      expect(AppModuleRegistry.hasEdit(perms, 'sub_vendor'), isTrue);
      expect(AppModuleRegistry.hasDelete(perms, 'sub_vendor'), isFalse);

      // Turn ON Delete directly -> should grant Delete while keeping View & Edit
      perms = AppModuleRegistry.setModulePermission(
        currentPerms: perms,
        moduleKey: 'sub_vendor',
        action: 'delete',
        enabled: true,
      );
      expect(AppModuleRegistry.hasView(perms, 'sub_vendor'), isTrue);
      expect(AppModuleRegistry.hasEdit(perms, 'sub_vendor'), isTrue);
      expect(AppModuleRegistry.hasDelete(perms, 'sub_vendor'), isTrue);

      // Turn OFF View -> should automatically revoke all actions
      perms = AppModuleRegistry.setModulePermission(
        currentPerms: perms,
        moduleKey: 'sub_vendor',
        action: 'view',
        enabled: false,
      );
      expect(AppModuleRegistry.hasView(perms, 'sub_vendor'), isFalse);
      expect(AppModuleRegistry.hasEdit(perms, 'sub_vendor'), isFalse);
      expect(AppModuleRegistry.hasDelete(perms, 'sub_vendor'), isFalse);
      expect(perms.containsKey('sub_vendor'), isFalse);
    });

    test('Granular permissions across newly introduced modules (sub_vendor, solar_quotation, etc.)', () {
      final customStaff = UserProfile(
        id: 'u-vendor-officer',
        email: 'officer@siya.com',
        role: 'staff',
        permissions: {
          'sub_vendor': ['view', 'edit'],
          'solar_quotation': ['view'],
          'solar_cost_calculator': ['view', 'edit', 'delete'],
        },
      );

      // sub_vendor checks
      expect(customStaff.canView('sub_vendor'), isTrue);
      expect(customStaff.canEdit('sub_vendor'), isTrue);
      expect(customStaff.canDeleteFrom('sub_vendor'), isFalse);

      // solar_quotation checks
      expect(customStaff.canView('solar_quotation'), isTrue);
      expect(customStaff.canEdit('solar_quotation'), isFalse);
      expect(customStaff.canDeleteFrom('solar_quotation'), isFalse);

      // solar_cost_calculator checks
      expect(customStaff.canView('solar_cost_calculator'), isTrue);
      expect(customStaff.canEdit('solar_cost_calculator'), isTrue);
      expect(customStaff.canDeleteFrom('solar_cost_calculator'), isTrue);

      // unassigned module
      expect(customStaff.canView('customer_hishob'), isFalse);
    });
  });
}

