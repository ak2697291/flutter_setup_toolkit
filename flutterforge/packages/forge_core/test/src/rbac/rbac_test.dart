import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_core/forge_core.dart';

void main() {
  group('ForgeRole', () {
    test('equality should work', () {
      expect(ForgeRole.admin, equals(const ForgeRole('admin')));
      expect(ForgeRole.user, equals(const ForgeRole('user')));
      expect(ForgeRole.admin, isNot(equals(ForgeRole.user)));
    });

    test('custom roles should work', () {
      const editor = ForgeRole('editor');
      expect(editor.value, 'editor');
    });
  });

  group('ForgeRoleGuard', () {
    test('should allow access when role matches', () {
      final redirect = ForgeRoleGuard.redirect(
        currentRole: ForgeRole.admin,
        allowedRoles: [ForgeRole.admin, ForgeRole.user],
      );
      expect(redirect, isNull);
    });

    test('should deny access and redirect when role does not match', () {
      final redirect = ForgeRoleGuard.redirect(
        currentRole: ForgeRole.user,
        allowedRoles: [ForgeRole.admin],
        redirectLocation: '/unauthorized',
      );
      expect(redirect, '/unauthorized');
    });

    test('should deny access when role is null', () {
      final redirect = ForgeRoleGuard.redirect(
        currentRole: null,
        allowedRoles: [ForgeRole.admin],
      );
      expect(redirect, '/');
    });
  });

  group('RBACGate Widget Tests', () {
    testWidgets('should show child when role is allowed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RBACGate(
            currentRole: ForgeRole.admin,
            allowedRoles: [ForgeRole.admin],
            child: Text('Admin Content'),
          ),
        ),
      );

      expect(find.text('Admin Content'), findsOneWidget);
    });

    testWidgets('should show fallback when role is denied', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RBACGate(
            currentRole: ForgeRole.user,
            allowedRoles: [ForgeRole.admin],
            fallback: Text('Access Denied'),
            child: Text('Admin Content'),
          ),
        ),
      );

      expect(find.text('Admin Content'), findsNothing);
      expect(find.text('Access Denied'), findsOneWidget);
    });

    testWidgets('should show nothing when role is denied and no fallback provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RBACGate(
            currentRole: ForgeRole.user,
            allowedRoles: [ForgeRole.admin],
            child: Text('Admin Content'),
          ),
        ),
      );

      expect(find.text('Admin Content'), findsNothing);
    });

    testWidgets('should show nothing when role is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RBACGate(
            currentRole: null,
            allowedRoles: [ForgeRole.admin],
            child: Text('Admin Content'),
          ),
        ),
      );

      expect(find.text('Admin Content'), findsNothing);
    });

    testWidgets('should work with custom roles', (tester) async {
      const editor = ForgeRole('editor');
      await tester.pumpWidget(
        const MaterialApp(
          home: RBACGate(
            currentRole: editor,
            allowedRoles: [editor],
            child: Text('Editor Content'),
          ),
        ),
      );

      expect(find.text('Editor Content'), findsOneWidget);
    });
  });
}
