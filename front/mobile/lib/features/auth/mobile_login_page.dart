import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';

class MobileLoginPage extends StatefulWidget {
  const MobileLoginPage({super.key});

  @override
  State<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends State<MobileLoginPage> {
  static const _rememberKey = 'mobile.remember';
  static const _usernameKey = 'mobile.username';
  static const _passwordKey = 'mobile.password';

  final _usernameController = TextEditingController(text: 'user');
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _remember = false;
  bool _ready = false;
  String _usernameError = '';
  String _passwordError = '';

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final remember = prefs.getBool(_rememberKey) ?? false;
    _usernameController.text = prefs.getString(_usernameKey) ?? 'user';
    _passwordController.text = remember
        ? prefs.getString(_passwordKey) ?? ''
        : '';

    setState(() {
      _remember = remember;
      _ready = true;
    });
  }

  Future<void> _login() async {
    if (!_validate()) return;

    setState(() => _loading = true);
    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final resp = await ApiClient().post('/api/mobile/login', {
        'username': username,
        'password': password,
      });

      if (!mounted) return;
      if (resp['code'] != 0) {
        _showMessage(resp['msg']?.toString() ?? '登录失败');
        return;
      }

      await _saveRememberedLogin(username, password);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      _showMessage('登录失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _validate() {
    final usernameError = _usernameController.text.trim().isEmpty
        ? '请输入用户名'
        : '';
    final passwordError = _passwordController.text.isEmpty ? '请输入密码' : '';
    setState(() {
      _usernameError = usernameError;
      _passwordError = passwordError;
    });
    return usernameError.isEmpty && passwordError.isEmpty;
  }

  Future<void> _saveRememberedLogin(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_remember) {
      await prefs.setBool(_rememberKey, true);
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_passwordKey, password);
      return;
    }

    await prefs.setBool(_rememberKey, false);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FScaffold(
      child: ColoredBox(
        color: theme.colors.muted,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FCard.raw(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LoginHeader(),
                        const SizedBox(height: 24),
                        FTextField(
                          control: FTextFieldControl.managed(
                            controller: _usernameController,
                          ),
                          label: const Text('用户名'),
                          hint: '请输入用户名',
                          error: _usernameError.isEmpty
                              ? null
                              : Text(_usernameError),
                          textInputAction: TextInputAction.next,
                          prefixBuilder: (fieldContext, style, variants) =>
                              FTextField.prefixIconBuilder(
                                fieldContext,
                                style,
                                variants,
                                const Icon(FIcons.user),
                              ),
                          onSubmit: (_) => FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 14),
                        FTextField.password(
                          control: FTextFieldControl.managed(
                            controller: _passwordController,
                          ),
                          label: const Text('密码'),
                          hint: '请输入密码',
                          error: _passwordError.isEmpty
                              ? null
                              : Text(_passwordError),
                          textInputAction: TextInputAction.done,
                          prefixBuilder: (fieldContext, style, _, variants) =>
                              FTextField.prefixIconBuilder(
                                fieldContext,
                                style,
                                variants,
                                const Icon(FIcons.lock),
                              ),
                          onSubmit: (_) => _loading ? null : _login(),
                        ),
                        const SizedBox(height: 16),
                        FCheckbox(
                          value: _remember,
                          onChange: (value) =>
                              setState(() => _remember = value),
                          label: const Text('记住密码'),
                          description: const Text('下次打开自动回填账号和密码'),
                        ),
                        const SizedBox(height: 18),
                        FButton(
                          onPress: _loading ? null : _login,
                          size: FButtonSizeVariant.lg,
                          child: Text(_loading ? '登录中...' : '登录'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(
              FIcons.smartphone,
              color: theme.colors.primaryForeground,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Mobile',
          style: theme.typography.xl3.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '手机端登录',
          style: theme.typography.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
