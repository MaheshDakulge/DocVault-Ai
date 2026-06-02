import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/remote/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase before the widget tree mounts.
  // Replace YOUR_PROJECT_ID and YOUR_ANON_KEY in supabase_client.dart.
  await SupabaseClientWrapper.init();

  runApp(
    const ProviderScope(
      child: DocsVaultApp(),
    ),
  );
}

class DocsVaultApp extends StatelessWidget {
  const DocsVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DocsVault AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
