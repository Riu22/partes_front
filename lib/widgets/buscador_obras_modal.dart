import 'package:flutter/material.dart';

void abrirBuscadorObras(
  BuildContext context,
  List obras,
  Function(dynamic) alSeleccionar,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: CuerpoBuscadorObras(
          obras: obras,
          alSeleccionar: alSeleccionar,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class CuerpoBuscadorObras extends StatefulWidget {
  final List obras;
  final Function(dynamic) alSeleccionar;
  final ScrollController scrollController;

  const CuerpoBuscadorObras({
    super.key,
    required this.obras,
    required this.alSeleccionar,
    required this.scrollController,
  });

  @override
  State<CuerpoBuscadorObras> createState() => _CuerpoBuscadorObrasState();
}

class _CuerpoBuscadorObrasState extends State<CuerpoBuscadorObras> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    // Filtra obras por nombre, municipio o ubicación (case-insensitive)
    final filtradas = widget.obras
        .where(
          (o) =>
              (o.nombre ?? '').toLowerCase().contains(_filtro.toLowerCase()) ||
              (o.municipio ?? '').toLowerCase().contains(
                _filtro.toLowerCase(),
              ) ||
              (o.ubicacion ?? '').toLowerCase().contains(_filtro.toLowerCase()),
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
              hintText: 'Nombre, municipio o calle...',
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
          child: filtradas.isEmpty
              ? const Center(child: Text('No se han encontrado obras'))
              : ListView.separated(
                  controller: widget.scrollController,
                  itemCount: filtradas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final o = filtradas[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.business, color: Colors.white),
                      ),
                      title: Text(
                        o.nombre ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          o.ubicacion,
                          o.municipio,
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                      ),
                      onTap: () {
                        widget.alSeleccionar(o);
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
