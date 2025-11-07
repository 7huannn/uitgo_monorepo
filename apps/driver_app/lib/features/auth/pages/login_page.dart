import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/primary_button.dart';
import '../controllers/auth_controller.dart';
import 'sign_up_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const route = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final success =
        await auth.login(_emailController.text.trim(), _passwordController.text);
    if (!success) {
      setState(() => _error = 'Sai thông tin đăng nhập.');
    }
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UIT-Go Driver',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nhập email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Mật khẩu tối thiểu 6 ký tự';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Đăng nhập',
                    loading: _submitting,
                    onPressed: _submitting ? null : _handleLogin,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Chưa có tài khoản?"),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () async {
                                final created = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpPage(),
                                  ),
                                );
                                if (created == true && mounted) {
                                  setState(() => _error = null);
                                }
                              },
                        child: const Text('Đăng ký'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}
