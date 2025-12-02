import 'package:flutter/material.dart';

class UitPrimaryButton extends StatefulWidget {
  const UitPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
    this.foregroundColor,
    this.semanticLabel,
    this.expand = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final Color? color;
  final Color? foregroundColor;
  final String? semanticLabel;
  final bool expand;
  final EdgeInsetsGeometry padding;

  @override
  State<UitPrimaryButton> createState() => _UitPrimaryButtonState();
}

class _UitPrimaryButtonState extends State<UitPrimaryButton> {
  bool _pressed = false;

  void _updatePressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handlePointerDown(PointerDownEvent _) => _updatePressed(true);
  void _handlePointerUp(PointerUpEvent _) => _updatePressed(false);
  void _handlePointerCancel(PointerCancelEvent _) => _updatePressed(false);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = widget.color ?? colorScheme.primary;
    final pressedColor = Color.lerp(baseColor, Colors.black, 0.08)!;
    final effectiveColor = _pressed ? pressedColor : baseColor;
    final foreground = widget.foregroundColor ?? colorScheme.onPrimary;

    final button = Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: widget.loading || widget.onPressed == null
          ? null
          : _handlePointerDown,
      onPointerUp:
          widget.loading || widget.onPressed == null ? null : _handlePointerUp,
      onPointerCancel: widget.loading || widget.onPressed == null
          ? null
          : _handlePointerCancel,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: widget.padding,
          elevation: _pressed ? 1.0 : 4.0,
          animationDuration: const Duration(milliseconds: 150),
        ),
        onPressed: widget.loading ? null : widget.onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: widget.loading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );

    final semanticsLabel = widget.semanticLabel ?? widget.label;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
