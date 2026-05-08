import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'features/auth/mobile_login_page.dart';

void main() {
  runApp(const MobileApp());
}

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final foruiTheme = FThemes.zinc.light.touch;
    return MaterialApp(
      title: 'Mobile',
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      theme: foruiTheme.toApproximateMaterialTheme(),
      builder: (context, child) => FTheme(data: foruiTheme, child: child!),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const MobileLoginPage(),
        '/home': (_) => const MobileHomePage(),
      },
    );
  }
}

class MobileHomePage extends StatelessWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手机端首页')),
      body: const Center(child: Text('登录成功，欢迎使用手机端')),
    );
  }
}
