import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../../../core/widgets/primary_button.dart';

class SignUpStepperPage extends StatefulWidget {
  const SignUpStepperPage({super.key});

  @override
  State<SignUpStepperPage> createState() => _SignUpStepperPageState();
}

class _SignUpStepperPageState extends State<SignUpStepperPage> {
  int _currentStep = 0;
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  // Step 1: Personal Info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 2: Vehicle Info
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();

  // Step 3: Documents (placeholders for file paths)
  String? _licensePath;
  String? _idCardPath;
  String? _registrationPath;

  // Step 4: Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKeys[_currentStep].currentState!.validate()) return;
    
    // Last step validation
    if (_currentStep == 3) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _error = 'Mật khẩu không khớp.');
        return;
      }
      if (_licensePath == null || _idCardPath == null || _registrationPath == null) {
        setState(() => _error = 'Vui lòng tải lên tất cả các tài liệu.');
        return;
      }
    }
    
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
            licenseNumber: 'DOC_UPLOADED', // Placeholder
            vehicleMake: _vehicleMakeController.text.trim(),
            vehicleModel: _vehicleModelController.text.trim(),
            vehicleColor: _vehicleColorController.text.trim(),
            plateNumber: _vehiclePlateController.text.trim(),
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

  void _nextStep() {
    if (_formKeys[_currentStep].currentState!.validate()) {
      if (_currentStep < 3) {
        setState(() => _currentStep++);
      } else {
        _handleSubmit();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _buildPersonalInfoStep(),
      _buildVehicleInfoStep(),
      _buildDocumentsStep(),
      _buildPasswordStep(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký tài xế'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / steps.length,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: steps,
            ),
          ),
          _buildNavigation(),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bước 1: Thông tin cá nhân', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Họ tên'),
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.isEmpty || !v.contains('@') ? 'Email không hợp lệ' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bước 2: Thông tin xe', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextFormField(
              controller: _vehicleMakeController,
              decoration: const InputDecoration(labelText: 'Hãng xe (VD: Toyota)'),
               validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleModelController,
              decoration: const InputDecoration(labelText: 'Dòng xe (VD: Vios)'),
               validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleColorController,
              decoration: const InputDecoration(labelText: 'Màu xe (VD: Bạc)'),
               validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehiclePlateController,
              decoration: const InputDecoration(labelText: 'Biển số xe (VD: 51F-123.45)'),
               validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bước 3: Tải lên tài liệu', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            _buildFileUploadTile(
              'Giấy phép lái xe',
              _licensePath,
              () async => setState(() => _licensePath = 'gplx.jpg'),
            ),
            _buildFileUploadTile(
              'Chứng minh nhân dân / CCCD',
              _idCardPath,
              () async => setState(() => _idCardPath = 'cccd.jpg'),
            ),
            _buildFileUploadTile(
              'Giấy đăng ký xe',
              _registrationPath,
              () async => setState(() => _registrationPath = 'dkx.jpg'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileUploadTile(String title, String? filePath, VoidCallback onUpload) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(filePath != null ? Icons.check_circle : Icons.upload_file, color: filePath != null ? Colors.green : null),
        title: Text(title),
        subtitle: Text(filePath ?? 'Chưa có tệp nào'),
        trailing: TextButton(
          onPressed: onUpload,
          child: const Text('Tải lên'),
        ),
      ),
    );
  }

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bước 4: Tạo mật khẩu', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
              validator: (v) => v!.length < 6 ? 'Mật khẩu phải có ít nhất 6 ký tự' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
              obscureText: true,
              validator: (v) => v != _passwordController.text ? 'Mật khẩu không khớp' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Quay lại'),
            ),
          const Spacer(),
          Expanded(
            child: PrimaryButton(
              label: _currentStep == 3 ? 'Hoàn tất' : 'Tiếp theo',
              onPressed: _nextStep,
              loading: _submitting,
            ),
          ),
        ],
      ),
    );
  }
}
