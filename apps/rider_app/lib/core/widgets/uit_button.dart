import 'package:flutter/material.dart';

class UITButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const UITButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
