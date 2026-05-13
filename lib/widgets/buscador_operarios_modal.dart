import 'package:flutter/material.dart';
import '../models/perfil.dart';

class CuerpoBuscadorOperarios extends StatefulWidget {
  final List<Perfil> perfiles;
  final Function(Perfil) alSeleccionar;
  final ScrollController scrollController;

  const CuerpoBuscadorOperarios({
    super.key,
    required this.perfiles,
    required this.alSeleccionar,
    required this.scrollController,
  });

  @override
  State<CuerpoBuscadorOperarios> createState() =>
      _CuerpoBuscadorOperariosState();
}

class _CuerpoBuscadorOperariosState extends State<CuerpoBuscadorOperarios> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.perfiles
        .where(
          (p) =>
              p.apellidos.toLowerCase().contains(_filtro.toLowerCase()) ||
              p.nombre.toLowerCase().contains(_filtro.toLowerCase()) ||
              p.email.toLowerCase().contains(_filtro.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 50,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o apellido...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (v) => setState(() => _filtro = v),
          ),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? const Center(child: Text('No se han encontrado operarios'))
              : ListView.separated(
                  controller: widget.scrollController,
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = filtrados[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Text(
                          p.apellidos.isNotEmpty
                              ? p.apellidos[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        p.nombreApellidoCompleto,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(p.email),
                      onTap: () {
                        widget.alSeleccionar(p);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
