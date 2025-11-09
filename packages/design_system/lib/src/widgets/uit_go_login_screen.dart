import 'package:flutter/material.dart';

import 'uit_primary_button.dart';

class UitGoLoginScreen extends StatelessWidget {
  const UitGoLoginScreen({
    super.key,
    required this.logo,
    required this.appName,
    required this.tagline,
    required this.accentColor,
    required this.onLogin,
    required this.onForgotPassword,
    this.onRegister,
    this.showRegister = true,
    this.loginButtonLabel = 'Đăng nhập',
    this.registerLabel = 'Đăng ký',
    this.registerMessage = 'Chưa có tài khoản?',
    this.forgotPasswordLabel = 'Quên mật khẩu?',
    this.failureMessage = 'Đăng nhập thất bại. Vui lòng thử lại.',
    this.initialEmail,
    this.initialPassword,
    this.themeMode,
    this.onToggleTheme,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  final Widget logo;
  final String appName;
  final String tagline;
  final Color accentColor;
  final Future<bool> Function(String email, String password) onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback? onRegister;
  final bool showRegister;
  final String loginButtonLabel;
  final String registerLabel;
  final String registerMessage;
  final String forgotPasswordLabel;
  final String failureMessage;
  final String? initialEmail;
  final String? initialPassword;
  final ThemeMode? themeMode;
  final VoidCallback? onToggleTheme;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ThemeToggleButton(
                        onToggleTheme: onToggleTheme,
                        themeMode: themeMode,
                        accent: accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LoginHeader(
                      logo: logo,
                      appName: appName,
                      tagline: tagline,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 32),
                    _LoginCard(
                      accentColor: accentColor,
                      onLogin: onLogin,
                      onForgotPassword: onForgotPassword,
                      onRegister: onRegister,
                      showRegister: showRegister,
                      registerLabel: registerLabel,
                      loginButtonLabel: loginButtonLabel,
                      registerMessage: registerMessage,
                      forgotPasswordLabel: forgotPasswordLabel,
                      failureMessage: failureMessage,
                      initialEmail: initialEmail,
                      initialPassword: initialPassword,
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

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({
    required this.logo,
    required this.appName,
    required this.tagline,
    required this.accentColor,
  });

  final Widget logo;
  final String appName;
  final String tagline;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Semantics(
          label: '$appName logo',
          child: Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(
                theme.brightness == Brightness.dark ? 0.18 : 0.12,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(child: logo),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard({
    required this.accentColor,
    required this.onLogin,
    required this.onForgotPassword,
    this.onRegister,
    required this.showRegister,
    required this.registerLabel,
    required this.loginButtonLabel,
    required this.registerMessage,
    required this.forgotPasswordLabel,
    required this.failureMessage,
    this.initialEmail,
    this.initialPassword,
  });

  final Color accentColor;
  final Future<bool> Function(String email, String password) onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback? onRegister;
  final bool showRegister;
  final String registerLabel;
  final String loginButtonLabel;
  final String registerMessage;
  final String forgotPasswordLabel;
  final String failureMessage;
  final String? initialEmail;
  final String? initialPassword;

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  static final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController(text: widget.initialPassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (!success) {
        setState(() => _errorMessage = widget.failureMessage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = '${widget.failureMessage}\n${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = Color.alphaBlend(
      widget.accentColor.withOpacity(isDark ? 0.08 : 0.04),
      colorScheme.surface,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, 18),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'your.email@example.com',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        semanticLabel: 'Email icon',
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!_emailRegex.hasMatch(value)) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      hintText: '••••••••',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        semanticLabel: 'Password icon',
                      ),
                      suffixIcon: IconButton(
                        tooltip:
                            _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          semanticLabel: _obscurePassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu',
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : widget.onForgotPassword,
                      child: Text(
                        widget.forgotPasswordLabel,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _errorMessage == null ? 0 : 1,
                    child: _errorMessage == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  UitPrimaryButton(
                    label: widget.loginButtonLabel,
                    loading: _loading,
                    onPressed: _loading ? null : _handleLogin,
                    color: widget.accentColor,
                  ),
                  if (widget.showRegister && widget.onRegister != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.registerMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: _loading ? null : widget.onRegister,
                            child: Text(
                              widget.registerLabel,
                              style: TextStyle(
                                color: widget.accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({
    this.onToggleTheme,
    this.themeMode,
    required this.accent,
  });

  final VoidCallback? onToggleTheme;
  final ThemeMode? themeMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (onToggleTheme == null) {
      return const SizedBox(height: 48);
    }

    final brightness = Theme.of(context).brightness;
    final resolvedMode = themeMode ??
        (brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
    final icon = resolvedMode == ThemeMode.dark
        ? Icons.dark_mode_rounded
        : Icons.light_mode_rounded;
    final tooltip =
        resolvedMode == ThemeMode.dark ? 'Chuyển sang sáng' : 'Chuyển sang tối';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withOpacity(0.08),
      ),
      child: IconButton(
        onPressed: onToggleTheme,
        splashRadius: 24,
        tooltip: tooltip,
        icon: Icon(icon, color: accent),
      ),
    );
  }
}
