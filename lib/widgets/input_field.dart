import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Widget reusable TextField dengan dukungan status error (border merah)
class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final bool isError;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color? fillColor;

  const InputField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.isError = false,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    // Border merah jika terdapat error login, atau border kaca default
    final borderColor = isError ? c.danger : c.glassBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isError ? c.danger : c.text,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(color: c.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.textMuted),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: isError ? c.danger : c.textMuted)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            // Jika ada fillColor khusus dari layar pemanggil gunakan itu, jika tidak pakai c.glass (default)
            fillColor: fillColor ?? c.glass,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusField),
              borderSide:
                  BorderSide(color: borderColor, width: isError ? 1.5 : 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusField),
              borderSide:
                  BorderSide(color: borderColor, width: isError ? 1.5 : 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusField),
              borderSide: BorderSide(
                color: isError ? c.danger : c.accent,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

