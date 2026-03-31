import 'package:flutter/material.dart';

class BuscadorObrasFiltro extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const BuscadorObrasFiltro({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<BuscadorObrasFiltro> createState() => _BuscadorObrasFiltroState();
}

class _BuscadorObrasFiltroState extends State<BuscadorObrasFiltro> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: 'Buscar por obra',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.business),
        isDense: true,
        // Botón para limpiar el texto rápidamente
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged();
                },
              )
            : null,
      ),
      // Actualiza el estado del sufijo (limpiar) mientras escribes
      onChanged: (value) {
        setState(() {});
        widget.onChanged();
      },
      onSubmitted: (_) => widget.onChanged(),
    );
  }
}
