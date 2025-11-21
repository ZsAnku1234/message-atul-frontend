import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:message_app_frontend/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton renders label and handles disabled state',
      (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PrimaryButton(
              label: 'Send',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Send'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    expect(pressed, isTrue);
  });
}
