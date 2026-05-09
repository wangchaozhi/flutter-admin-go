import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../features/auth/mobile_login_page.dart';
import '../features/home/mobile_home_page.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final foruiTheme = FThemes.zinc.light.touch;

    return MaterialApp(
      title: '心遇',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      theme: foruiTheme.toApproximateMaterialTheme().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE85D75),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F5),
      ),
      builder: (context, child) => FTheme(data: foruiTheme, child: child!),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const MobileLoginPage(),
        '/home': (_) => const MobileHomePage(),
      },
    );
  }
}
