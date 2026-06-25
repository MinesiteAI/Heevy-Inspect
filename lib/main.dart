import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/entitlement_gate.dart';
import 'config/heevy_brand.dart';
import 'config/supabase_config.dart';
import 'deep_link_handler.dart';
import 'theme/theme_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadThemeMode();
  await Supabase.initialize(
    url: SupabaseConfig.url.trim(),
    anonKey: SupabaseConfig.anonKey.trim(),
  );
  await DeepLinkHandler.init();
  runApp(const InspectApp());
}

class InspectApp extends StatelessWidget {
  const InspectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: HeevyBrand.appTitle,
          themeMode: mode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
