import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_project/main.dart';

void main() {
  testWidgets('Login page renders correctly', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const JobSeekAdminApp());

    // Wait for widgets to build
    await tester.pumpAndSettle();

    // Check if the login page is visible
    expect(find.text('JobSeek Admin'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // email & password fields
    expect(find.byType(ElevatedButton), findsOneWidget);  // login button
  });
}
