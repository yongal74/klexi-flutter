// test/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klexi_flutter/core/services/auth_service.dart';

void main() {
  group('KlexiUser', () {
    test('guest user has isGuest=true', () {
      const user = KlexiUser(id: 'guest_123', isGuest: true);
      expect(user.isGuest, true);
      expect(user.id, 'guest_123');
    });

    test('google user has isGuest=false', () {
      const user = KlexiUser(
        id: 'google_123',
        displayName: 'Sarah',
        email: 'sarah@example.com',
        isGuest: false,
      );
      expect(user.isGuest, false);
      expect(user.id, 'google_123');
      expect(user.displayName, 'Sarah');
    });

    test('KlexiUser has correct fields', () {
      const user = KlexiUser(
        id: 'uid_1',
        displayName: 'Pro User',
        email: 'pro@example.com',
        isGuest: false,
      );
      expect(user.id, 'uid_1');
      expect(user.email, 'pro@example.com');
    });
  });
}
