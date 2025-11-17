import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../driver/models/driver_models.dart';
import '../controllers/driver_profile_controller.dart';
import '../models/profile_models.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  static const routeName = '/profile';

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  bool _didFill = false;
  String? _avatarPath;
  DriverProfileController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<DriverProfileController>();
      _controller = controller;
      controller.addListener(_handleControllerChange);
      if (!controller.initialized) {
        controller.bootstrap();
      } else if (controller.profile != null && !_didFill) {
        _fillFields(controller.profile!);
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChange);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.profile != null && !_didFill) {
      _fillFields(controller.profile!);
    }
    if (controller.profile == null) {
      setState(() => _didFill = false);
    }
  }

  void _fillFields(DriverProfile profile) {
    _nameCtrl.text = profile.fullName;
    _phoneCtrl.text = profile.phone;
    _plateCtrl.text = profile.licenseNumber;
    _vehicleCtrl.text = profile.vehicleType ?? profile.vehicle?.model ?? '';
    setState(() => _didFill = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DriverProfileController>();
    if (controller.loading && controller.profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = controller.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ tài xế'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadProfile,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AvatarSection(
                profile: profile,
                avatarPath: _avatarPath,
                onChangeTap: _handleChangeAvatar,
              ),
              const SizedBox(height: 16),
              _buildForm(controller),
              const SizedBox(height: 16),
              UitPrimaryButton(
                onPressed: controller.saving ? null : _saveProfile,
                loading: controller.saving,
                label: 'Lưu thay đổi',
                icon: const Icon(Icons.save_outlined),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: controller.changingPassword
                    ? null
                    : () => _openChangePasswordSheet(controller),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Đổi mật khẩu'),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  controller.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(DriverProfileController controller) {
    return Form(
      key: _formKey,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông tin cá nhân',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  final regex = RegExp(r'^(0|\+84)[0-9]{8,10}$');
                  if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
                  if (!regex.hasMatch(phone)) {
                    return 'Số điện thoại không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Biển số xe',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập biển số';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Loại xe',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập loại xe';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = context.read<DriverProfileController>();
    final success = await controller.updateProfile(
      DriverProfileUpdateRequest(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        licensePlate: _plateCtrl.text.trim(),
        vehicleType: _vehicleCtrl.text.trim(),
        avatarFilePath: _avatarPath,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đã cập nhật hồ sơ.'
              : 'Không thể cập nhật. Vui lòng thử lại.',
        ),
      ),
    );
  }

  void _handleChangeAvatar() {
    // Placeholder for actual image picker integration.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('TODO: Cập nhật avatar sau khi có API tải ảnh.'),
      ),
    );
  }

  Future<void> _openChangePasswordSheet(
    DriverProfileController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ChangePasswordSheet(controller: controller),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.profile,
    required this.avatarPath,
    required this.onChangeTap,
  });

  final DriverProfile? profile;
  final String? avatarPath;
  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    final initials = profile?.fullName.isNotEmpty == true
        ? profile!.fullName[0].toUpperCase()
        : 'D';
    final avatar = avatarPath ?? profile?.avatarUrl;
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.15),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: onChangeTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onChangeTap,
            child: const Text('Thay ảnh đại diện'),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key, required this.controller});

  final DriverProfileController controller;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 16,
        right: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đổi mật khẩu',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentCtrl,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu hiện tại',
              ),
              obscureText: true,
              validator: (value) => value == null || value.isEmpty
                  ? 'Nhập mật khẩu hiện tại'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nhập mật khẩu mới';
                }
                if (value.length < 6) {
                  return 'Mật khẩu phải có ít nhất 6 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
              obscureText: true,
              validator: (value) {
                if (value != _newCtrl.text) {
                  return 'Mật khẩu không khớp';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            UitPrimaryButton(
              onPressed: _submitting ? null : _handleSubmit,
              loading: _submitting,
              label: 'Cập nhật mật khẩu',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final success = await widget.controller.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Đổi mật khẩu thành công.'
            : 'Không thể đổi mật khẩu. Vui lòng kiểm tra lại.'),
      ),
    );
    if (success) Navigator.pop(context);
  }
}
