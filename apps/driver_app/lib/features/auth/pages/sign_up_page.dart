import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/primary_button.dart';
import '../controllers/auth_controller.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final success = await context.read<AuthController>().registerDriver(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            licenseNumber: _licenseController.text.trim(),
            vehicleMake: _vehicleMakeController.text.trim().isEmpty
                ? null
                : _vehicleMakeController.text.trim(),
            vehicleModel: _vehicleModelController.text.trim().isEmpty
                ? null
                : _vehicleModelController.text.trim(),
            vehicleColor: _vehicleColorController.text.trim().isEmpty
                ? null
                : _vehicleColorController.text.trim(),
            plateNumber: _vehiclePlateController.text.trim().isEmpty
                ? null
                : _vehiclePlateController.text.trim(),
          );
      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Đăng ký thất bại. Thử lại.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo tài khoản tài xế'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin cá nhân',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Họ tên'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Nhập họ tên' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        value == null || !value.contains('@') ? 'Email không hợp lệ' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Số điện thoại'),
                    validator: (value) =>
                        value == null || value.length < 8 ? 'Nhập số điện thoại' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    obscureText: true,
                    validator: (value) =>
                        value == null || value.length < 6 ? 'Tối thiểu 6 ký tự' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(labelText: 'Giấy phép / biển số'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Nhập giấy phép' : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Thông tin xe (tùy chọn)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vehicleMakeController,
                    decoration: const InputDecoration(labelText: 'Hãng xe'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vehicleModelController,
                    decoration: const InputDecoration(labelText: 'Dòng xe'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vehicleColorController,
                    decoration: const InputDecoration(labelText: 'Màu sắc'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vehiclePlateController,
                    decoration: const InputDecoration(labelText: 'Biển số'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Đăng ký',
                    loading: _submitting,
                    onPressed: _submitting ? null : _handleSubmit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
