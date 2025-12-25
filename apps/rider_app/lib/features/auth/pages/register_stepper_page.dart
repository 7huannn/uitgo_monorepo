import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/core/widgets/uit_button.dart';
import 'package:rider_app/features/auth/services/auth_service.dart';

class RegisterStepperPage extends StatefulWidget {
  const RegisterStepperPage({super.key});

  @override
  State<RegisterStepperPage> createState() => _RegisterStepperPageState();
}

class _RegisterStepperPageState extends State<RegisterStepperPage> {
  int _currentStep = 0;
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (_loading) return;
    if (!(_formKeys[_currentStep].currentState?.validate() ?? false)) return;

    if (!_agreedToTerms) {
      _showErrorDialog('Lỗi', 'Vui lòng đồng ý với điều khoản sử dụng');
      return;
    }

    setState(() => _loading = true);

    try {
      final success = await _authService.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        context.goNamed(AppRouteNames.home);
      } else {
        _showErrorDialog('Đăng ký thất bại', 'Vui lòng thử lại sau');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Không thể đăng ký', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Lỗi', 'Có lỗi xảy ra: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final steps = [
      _buildStep1(theme, colorScheme),
      _buildStep2(theme, colorScheme),
      _buildStep3(theme, colorScheme),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo tài khoản'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / steps.length,
            backgroundColor: colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: steps,
              ),
            ),
            _buildNavigation(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thông tin cá nhân', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Xác thực số điện thoại', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 32),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tạo mật khẩu', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 32),
            TextFormField(
              controller: _passCtrl,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) => v!.length < 6 ? 'Mật khẩu quá ngắn' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPassCtrl,
              decoration: InputDecoration(
                labelText: 'Xác nhận mật khẩu',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              obscureText: _obscureConfirmPassword,
              validator: (v) => v != _passCtrl.text ? 'Mật khẩu không khớp' : null,
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: (value) => setState(() => _agreedToTerms = value!),
              title: const Text('Đồng ý với điều khoản dịch vụ'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Quay lại'),
            ),
          const Spacer(),
          UITButton(
            label: _currentStep == 2 ? 'Đăng ký' : 'Tiếp tục',
            onPressed: () {
              if (_formKeys[_currentStep].currentState!.validate()) {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  _onRegister();
                }
              }
            },
            loading: _loading,
          ),
        ],
      ),
    );
  }
}
