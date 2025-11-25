import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_project/main.dart';
import 'package:fyp_project/routes/app_routes.dart';

void main() {
  testWidgets('Admin login page renders correctly', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const JobSeekApp());

    // Wait for initial build
    await tester.pumpAndSettle();

    // Navigate to admin login page using the Navigator
    final context = tester.element(find.byType(MaterialApp));
    Navigator.of(context).pushNamed(AppRoutes.adminLogin);
    await tester.pumpAndSettle();

    // Check if the admin login page is visible
    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // email & password fields
    expect(find.byType(ElevatedButton), findsOneWidget);  // login button
  });
}
