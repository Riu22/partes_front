import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onSubmit;

  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: textSecondary),
        filled: true,
        fillColor: bgCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: blue),
        ),
        isDense: true,
      ),
      onSubmitted: onSubmit,
    );
  }
}
