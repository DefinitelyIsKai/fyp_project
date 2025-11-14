import 'package:flutter/material.dart';
import 'package:fyp_project/routes/app_routes.dart';
import 'package:fyp_project/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const JobSeekAdminApp());
}

class JobSeekAdminApp extends StatelessWidget {
  const JobSeekAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'JobSeek Admin',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.login,
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}

