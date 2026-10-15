import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase & Auth session (with graceful offline/mock fallback)
  await FirebaseService().initialize();

  runApp(const FluxShareApp());
}

class FluxShareApp extends StatelessWidget {
  const FluxShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FluxShare — Convert & Share Files',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
