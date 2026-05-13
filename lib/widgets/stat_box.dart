import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';

class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgStat,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: valueColor ?? textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
