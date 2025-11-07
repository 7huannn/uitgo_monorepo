import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
        ),
        onPressed: effectiveOnPressed,
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label),
      ),
    );
  }
}
