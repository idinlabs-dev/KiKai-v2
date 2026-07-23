import 'package:flutter/material.dart';

import 'core/constants/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';

/// Global theme mode controller — di-toggle dari SettingsScreen.
/// KiKai = light-first (monokrom).
final ValueNotifier<ThemeMode> kThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.light);

class KiKaiApp extends StatelessWidget {
  const KiKaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: kThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const AuthGate(child: HomeShell()),
          routes: const {},
        );
      },
    );
  }
}
