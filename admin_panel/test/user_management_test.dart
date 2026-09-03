import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/user_profile.dart';

void main() {
  group('Phase 9: User & Permission Management Tests', () {
    test('UserProfile model deserialization and getters', () {
      final json = {
        'id': 'user-123',
        'email': 'staff@siya.com',
        'full_name': 'Rohan Patil',
        'role': 'staff',
        'is_active': true,
        'can_delete': false,
        'created_at': '2026-09-01T10:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.email, 'staff@siya.com');
      expect(profile.fullName, 'Rohan Patil');
      expect(profile.role, 'staff');
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
        isActive: false,
        canDelete: true,
      );

      final json = profile.toJson();

      expect(json['id'], 'u-99');
      expect(json['email'], 'test@siya.com');
      expect(json['full_name'], 'Test User');
      expect(json['role'], 'admin');
      expect(json['is_active'], isFalse);
      expect(json['can_delete'], isTrue);
    });
  });
}
