import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harassment_app/auth/login_screen.dart';

void main() {
  testWidgets('login screen shows all three role choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.byType(RoleSelector), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Committee'), findsOneWidget);
  });

  testWidgets('user can select the committee portal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    final committeeChip = find.ancestor(
      of: find.text('Committee'),
      matching: find.byType(ChoiceChip),
    );

    expect(tester.widget<ChoiceChip>(committeeChip).selected, isFalse);

    await tester.tap(find.text('Committee'));
    await tester.pump();

    expect(tester.widget<ChoiceChip>(committeeChip).selected, isTrue);
  });
}