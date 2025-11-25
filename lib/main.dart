import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fyp_project/routes/app_routes.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const JobSeekApp());
}

class JobSeekApp extends StatelessWidget {
  const JobSeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'JobSeek',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false, // Remove DEBUG banner
        initialRoute: AppRoutes.userLogin, // Default to user login page
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}

