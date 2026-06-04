// =============================================================================
// buscador_obras_modal.dart  -  Modal para buscar y seleccionar obra
// =============================================================================
// ASPECTO EN PANTALLA:
//   Panel que sube desde abajo (bottom sheet) ocupando ~80% de la pantalla.
//   Arriba tiene una barra de arrastre (handle), luego un campo de texto con
//   icono de lupa y placeholder "Nombre, municipio o calle...", y debajo una
//   lista filtrable de obras con avatar + nombre + ubicacion.
//
// USO:
//   Seleccionar una obra al crear/editar un parte de trabajo. Se abre desde
//   cualquier pantalla llamando a [abrirBuscadorObras()].
//
// DATOS QUE NECESITA:
//   - obras: lista de objetos con campos nombre, municipio, ubicacion
//   - alSeleccionar: callback cuando el usuario elige una obra
//
// INTERACCION DEL USUARIO:
//   - Escribir en el campo de texto filtra la lista en tiempo real
//   - Tocar una obra la selecciona, ejecuta alSeleccionar y cierra el modal
//   - Arrastrar hacia abajo cierra el panel
// =============================================================================

/// Ventana modal que permite buscar y seleccionar una obra.
/// Muestra un campo de texto para filtrar por nombre, municipio o calle,
/// y una lista con los resultados.
import 'package:flutter/material.dart';

/// Funcion global que abre el modal de busqueda de obras.
///
/// [context] debe ser un BuildContext valido.
/// [obras] es la lista completa de obras disponibles.
/// [alSeleccionar] recibe la obra elegida como dynamic.
void abrirBuscadorObras(
  BuildContext context,
  List obras,
  Function(dynamic) alSeleccionar,
) {
  // [showModalBottomSheet] muestra un panel que sube desde abajo.
  // isScrollControlled: true permite que el modal ocupe mas de media pantalla.
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // Fondo transparente para ver esquinas redondeadas
    builder: (context) => DraggableScrollableSheet(
      // [DraggableScrollableSheet] permite arrastrar para cambiar el tamano.
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        // Contenedor principal con esquinas superiores redondeadas.
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

/// Cuerpo interno del buscador de obras (campo de texto + lista filtrada).
///
/// [StatefulWidget] porque mantiene el estado del filtro de busqueda (_filtro).
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
  // Almacena el texto del filtro de busqueda.
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    // Filtra obras por nombre, municipio o ubicacion (case-insensitive)
    // Se recalcula en cada rebuild por el setState de onChanged.
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
        // ── BARRA DE ARRASTRE (handle) ────────────────────────
        // Pequena linea horizontal que indica que se puede arrastrar.
        const SizedBox(height: 12),
        Container(
          width: 50,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),

        // ── CAMPO DE BUSQUEDA ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            autofocus: true, // Enfoca automaticamente al abrir el modal.
            decoration: InputDecoration(
              hintText: 'Nombre, municipio o calle...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            // onChanged se dispara en cada tecla; setState reconstruye.
            onChanged: (v) => setState(() => _filtro = v),
          ),
        ),

        // ── LISTA DE RESULTADOS ──────────────────────────────
        Expanded(
          child: filtradas.isEmpty
              ? const Center(child: Text('No se han encontrado obras'))
              : ListView.separated(
                  controller: widget.scrollController,
                  itemCount: filtradas.length,
                  // Divider entre cada elemento.
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
                        // Muestra ubicacion y municipio separados por un punto.
                        [
                          o.ubicacion,
                          o.municipio,
                        ].where((s) => s != null && s.isNotEmpty).join(' · '),
                      ),
                      // Al tocar una obra: ejecuta callback y cierra modal.
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
