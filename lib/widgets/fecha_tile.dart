import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RangoFechaTile extends StatelessWidget {
  final DateTime desde;
  final DateTime hasta;
  final ValueChanged<DateTimeRange> onChanged;

  const RangoFechaTile({
    super.key,
    required this.desde,
    required this.hasta,
    required this.onChanged,
  });

  Future<void> _pickRango(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: desde, end: hasta),
    );
    if (picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickRango(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Color(0xFF1565C0),
            ),
            const SizedBox(width: 10),
            Text(
              '${DateFormat('dd/MM/yyyy').format(desde)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '→',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(hasta),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
