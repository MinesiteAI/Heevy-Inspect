import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/entitlement_gate.dart';
import 'config/heevy_brand.dart';
import 'config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url.trim(),
    anonKey: SupabaseConfig.anonKey.trim(),
  );
  runApp(const InspectApp());
}

class InspectApp extends StatelessWidget {
  const InspectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: HeevyBrand.appTitle,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: HeevyBrand.accent),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: HeevyBrand.accent,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
