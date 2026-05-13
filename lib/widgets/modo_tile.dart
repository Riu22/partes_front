import 'package:flutter/material.dart';

class ModoTile extends StatelessWidget {
  final String label;
  final String subtitulo;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const ModoTile({
    super.key,
    required this.label,
    required this.subtitulo,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? const Color(0xFF1565C0) : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado ? const Color(0xFFE3EDFF) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: seleccionado ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
