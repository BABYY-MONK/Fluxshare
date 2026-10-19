import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/shared_file_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }
  final shareId = Uri.base.queryParameters['share'];
  runApp(FluxShareApp(
    supabase: configured ? SupabaseService(Supabase.instance.client) : null,
    shareId: shareId,
  ));
}

class FluxShareApp extends StatelessWidget {
  const FluxShareApp({super.key, required this.supabase, this.shareId});

  final SupabaseService? supabase;
  final String? shareId;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FluxShare',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.futuristic(),
        home: shareId == null
            ? HomeScreen(supabase: supabase)
            : SharedFileScreen(supabase: supabase, shareId: shareId!),
      );
}
