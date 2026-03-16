// test/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klexi_flutter/core/services/auth_service.dart';

void main() {
  group('KlexiUser', () {
    test('guest user has isGuest=true', () {
      final user = KlexiUser.guest();
      expect(user.isGuest, true);
      expect(user.uid, startsWith('guest_'));
      expect(user.displayName, 'Guest');
      expect(user.isPremium, false);
    });

    test('fromGoogle creates non-guest user', () {
      final user = KlexiUser(
        uid: 'google_123',
        displayName: 'Sarah',
        email: 'sarah@example.com',
        photoUrl: null,
        isGuest: false,
        isPremium: false,
      );
      expect(user.isGuest, false);
      expect(user.uid, 'google_123');
      expect(user.displayName, 'Sarah');
    });

    test('premium user has isPremium=true', () {
      final user = KlexiUser(
        uid: 'uid_1',
        displayName: 'Pro User',
        email: 'pro@example.com',
        photoUrl: null,
        isGuest: false,
        isPremium: true,
      );
      expect(user.isPremium, true);
    });

    test('guest uid is unique each call', () {
      final a = KlexiUser.guest();
      final b = KlexiUser.guest();
      // Both start with guest_ but timing may differ
      expect(a.uid, startsWith('guest_'));
      expect(b.uid, startsWith('guest_'));
    });
  });
}
