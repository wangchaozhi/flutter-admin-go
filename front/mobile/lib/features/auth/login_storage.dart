import 'package:shared_preferences/shared_preferences.dart';

class SavedLogin {
  const SavedLogin({
    required this.username,
    required this.password,
    required this.remember,
    required this.token,
  });

  final String username;
  final String password;
  final bool remember;
  final String token;
}

class LoginStorage {
  static const _rememberKey = 'mobile.remember';
  static const _usernameKey = 'mobile.username';
  static const _passwordKey = 'mobile.password';
  static const _tokenKey = 'mobile.token';

  Future<SavedLogin> load() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;

    return SavedLogin(
      username: prefs.getString(_usernameKey) ?? 'user',
      password: remember ? prefs.getString(_passwordKey) ?? '' : '',
      remember: remember,
      token: prefs.getString(_tokenKey) ?? '',
    );
  }

  Future<void> save({
    required String username,
    required String password,
    required bool remember,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);

    if (!remember) {
      await prefs.remove(_usernameKey);
      await prefs.remove(_passwordKey);
    } else {
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_passwordKey, password);
    }

    if (token != null) {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<String> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) ?? '';
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
