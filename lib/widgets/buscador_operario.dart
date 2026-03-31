import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/partes_provider.dart';

class BuscadorOperario extends StatefulWidget {
  final Function(String) onBuscar;
  final VoidCallback onLimpiar;

  const BuscadorOperario({
    super.key,
    required this.onBuscar,
    required this.onLimpiar,
  });

  @override
  State<BuscadorOperario> createState() => _BuscadorOperarioState();
}

class _BuscadorOperarioState extends State<BuscadorOperario> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: 'Buscar por nombre...',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onLimpiar();
                    setState(() {});
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {}); // Actualiza para mostrar/ocultar la 'X'
          if (value.isEmpty) widget.onLimpiar();
          widget.onBuscar(value);
        },
      ),
    );
  }
}
