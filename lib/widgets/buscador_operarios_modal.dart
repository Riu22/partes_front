// =============================================================================
// buscador_operarios_modal.dart  -  Modal para buscar y seleccionar operario
// =============================================================================
// ASPECTO EN PANTALLA:
//   Panel que sube desde abajo con fondo blanco y esquinas redondeadas.
//   Arriba una barra de arrastre, luego campo de texto "Buscar por nombre
//   o apellido..." con lupa, y debajo lista filtrable de operarios con
//   avatar (inicial del apellido), nombre completo y email.
//
// USO:
//   Seleccionar un operario al asignar partes o configurar permisos.
//   Los datos se obtienen del [usuariosProvider] de Riverpod.
//
// DATOS QUE NECESITA:
//   - alSeleccionar: Function(Perfil) que se ejecuta al elegir un operario
//   - Internamente usa usuariosProvider para obtener la lista de perfiles
//
// INTERACCION DEL USUARIO:
//   - Escribir filtra por nombre, apellido o email en tiempo real
//   - Tocar un operario lo selecciona y cierra el modal
//   - Arrastrar hacia abajo o tocar fuera cierra el modal sin seleccionar
// =============================================================================

/// Ventana modal para buscar y seleccionar un operario.
/// Abre un panel deslizable con lista filtrable de todos los usuarios.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/perfil.dart';
import '../providers/admin_provider.dart';

/// Cuerpo del buscador de operarios: campo de texto + lista filtrable.
///
/// [StatefulWidget] porque mantiene el estado _filtro para la busqueda.
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
  // Texto del filtro de busqueda.
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    // Filtra perfiles por nombre, apellido o email (case-insensitive).
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
        // ── BARRA DE ARRASTRE ─────────────────────────────────
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

        // ── LISTA DE RESULTADOS ──────────────────────────────
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
                      // Avatar circular con la inicial del apellido.
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

/// Funcion global que abre el modal de busqueda de operarios.
///
/// Usa [Consumer] de Riverpod para leer [usuariosProvider] y obtener la
/// lista completa de perfiles. [Consumer] es un widget que expone [WidgetRef]
/// sin necesidad de convertir toda la pantalla en ConsumerWidget.
void abrirBuscadorOperarios(
  BuildContext context,
  void Function(Perfil) alSeleccionar,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Consumer(
        // [Consumer] es un widget de Riverpod que proporciona [WidgetRef].
        // Se usa aqui para no tener que convertir el builder del modal en
        // un ConsumerWidget completo.
        builder: (context, ref, _) {
          // Lee el provider de usuarios de forma reactiva.
          // Cuando los datos cambian, este widget se reconstruye.
          final usuariosAsync = ref.watch(usuariosProvider);
          return usuariosAsync.when(
            // Mientras carga: indicador de progreso.
            loading: () => const Center(child: CircularProgressIndicator()),
            // Si hay error: mensaje de error.
            error: (e, _) => Center(child: Text('Error: $e')),
            // Datos cargados: construye la lista de perfiles.
            data: (lista) {
              // Convierte cada mapa JSON a un objeto Perfil.
              final perfiles = lista
                  .map((e) => Perfil.fromJson(e as Map<String, dynamic>))
                  .toList();
              return CuerpoBuscadorOperarios(
                perfiles: perfiles,
                alSeleccionar: alSeleccionar,
                scrollController: scrollController,
              );
            },
          );
        },
      ),
    ),
  );
}
