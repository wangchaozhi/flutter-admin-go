import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import 'login_storage.dart';
import 'widgets/login_header.dart';

class MobileLoginPage extends StatefulWidget {
  const MobileLoginPage({super.key});

  @override
  State<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends State<MobileLoginPage> {
  final _storage = LoginStorage();
  final _usernameController = TextEditingController(text: '13800000000');
  final _passwordController = TextEditingController(text: '123456');

  bool _loading = false;
  bool _remember = false;
  bool _ready = false;
  bool _registerMode = false;
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
    final saved = await _storage.load();
    if (!mounted) return;

    _usernameController.text = saved.username == 'user'
        ? '13800000000'
        : saved.username;
    _passwordController.text = saved.password.isEmpty
        ? '123456'
        : saved.password;
    setState(() {
      _remember = saved.remember;
      _ready = true;
    });
  }

  Future<void> _enterApp() async {
    if (!_validate()) return;

    setState(() => _loading = true);
    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      final resp = await ApiClient().post(
        _registerMode ? '/api/mobile/register' : '/api/mobile/login',
        {'username': username, 'password': password},
      );
      if (!mounted) return;
      if (resp['code'] != 0) {
        _showMessage(resp['msg']?.toString() ?? '登录失败');
        return;
      }
      final data = resp['data'] as Map<String, dynamic>? ?? {};
      final token = data['token']?.toString() ?? '';

      await _storage.save(
        username: username,
        password: password,
        remember: _remember,
        token: token,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _validate() {
    final usernameError = _usernameController.text.trim().isEmpty
        ? '请输入手机号'
        : '';
    final passwordError = _passwordController.text.isEmpty ? '请输入密码' : '';
    setState(() {
      _usernameError = usernameError;
      _passwordError = passwordError;
    });
    return usernameError.isEmpty && passwordError.isEmpty;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFBF7), Color(0xFFFFEEF2), Color(0xFFF4F8FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _LoginCard(
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  usernameError: _usernameError,
                  passwordError: _passwordError,
                  remember: _remember,
                  registerMode: _registerMode,
                  loading: _loading,
                  onRememberChanged: (value) =>
                      setState(() => _remember = value),
                  onModeChanged: (value) =>
                      setState(() => _registerMode = value),
                  onLogin: _enterApp,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.usernameController,
    required this.passwordController,
    required this.usernameError,
    required this.passwordError,
    required this.remember,
    required this.registerMode,
    required this.loading,
    required this.onRememberChanged,
    required this.onModeChanged,
    required this.onLogin,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String usernameError;
  final String passwordError;
  final bool remember;
  final bool registerMode;
  final bool loading;
  final ValueChanged<bool> onRememberChanged;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 18,
      shadowColor: const Color(0x1F0F172A),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LoginHeader(),
            const SizedBox(height: 26),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('登录')),
                ButtonSegment(value: true, label: Text('注册')),
              ],
              selected: {registerMode},
              onSelectionChanged: loading
                  ? null
                  : (values) => onModeChanged(values.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                label: '手机号',
                hint: '请输入手机号',
                icon: Icons.phone_iphone_rounded,
                error: usernameError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!loading) onLogin();
              },
              decoration: _fieldDecoration(
                label: '密码',
                hint: '请输入密码',
                icon: Icons.lock_outline_rounded,
                error: passwordError,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: remember,
              contentPadding: EdgeInsets.zero,
              title: const Text('记住登录信息'),
              subtitle: const Text('下次打开自动回填账号和密码'),
              onChanged: loading ? null : onRememberChanged,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: loading ? null : onLogin,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(loading ? '处理中...' : (registerMode ? '注册并进入' : '登录')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required String error,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error.isEmpty ? null : error,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFFAF7F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE7E2DE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE7E2DE)),
      ),
    );
  }
}
