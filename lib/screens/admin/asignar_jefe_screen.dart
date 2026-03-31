import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class AsignarJefeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> usuario; // El "Jefe" al que le asignaremos gente
  final List<dynamic> todos; // Lista completa de usuarios para el dropdown

  const AsignarJefeScreen({
    super.key,
    required this.usuario,
    required this.todos,
  });

  @override
  ConsumerState<AsignarJefeScreen> createState() => _AsignarJefeScreenState();
}

class _AsignarJefeScreenState extends ConsumerState<AsignarJefeScreen> {
  String? _subordinadoSeleccionado;
  bool _enviando = false;
  bool _cargandoLista = true;
  List<dynamic> _subordinadosActuales = [];

  @override
  void initState() {
    super.initState();
    _cargarSubordinados();
  }

  // Carga los usuarios que ya tienen a este perfil como jefeDirecto
  Future<void> _cargarSubordinados() async {
    setState(() => _cargandoLista = true);
    try {
      final api = ref.read(apiServiceProvider);
      // Este endpoint debe retornar List<perfil> desde el backend
      final lista = await api.getSubordinadosDe(widget.usuario['id']);
      setState(() {
        _subordinadosActuales = lista;
        _cargandoLista = false;
      });
    } catch (e) {
      debugPrint('Error cargando subordinados: $e');
      setState(() => _cargandoLista = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtramos los posibles candidatos:
    // 1. Que no sea él mismo.
    // 2. Que no esté ya asignado en la lista de abajo.
    final posiblesSubordinados = widget.todos.where((u) {
      final yaAsignado = _subordinadosActuales.any((s) => s['id'] == u['id']);
      final esElMismo = u['id'] == widget.usuario['id'];

      // Lógica de roles: Si el jefe es JEFE_DE_OBRA, solo mostramos ENCARGADOS.
      // Si el jefe es ENCARGADO, solo mostramos OPERARIOS.
      bool rolValido = false;
      if (widget.usuario['rol'] == 'JEFE_DE_OBRA') {
        rolValido = u['rol'] == 'ENCARGADO';
      } else if (widget.usuario['rol'] == 'ENCARGADO' ||
          widget.usuario['rol'] == 'GESTION') {
        rolValido = u['rol'] == 'OPERARIO';
      }

      return !yaAsignado && !esElMismo && rolValido;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Equipo de ${widget.usuario['name']}')),
      body: Column(
        children: [
          // --- SECCIÓN 1: FORMULARIO DE ASIGNACIÓN ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asignar nuevo subordinado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _subordinadoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar personal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_add),
                      ),
                      items: posiblesSubordinados.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['id'],
                          child: Text('${u['name']} (${u['rol']})'),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _subordinadoSeleccionado = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_subordinadoSeleccionado == null || _enviando)
                            ? null
                            : _confirmarAsignacion,
                        icon: _enviando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('AÑADIR AL EQUIPO'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 32, thickness: 1),

          // --- SECCIÓN 2: LISTA DE SUBORDINADOS ACTUALES ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subordinados actuales (${_subordinadosActuales.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_cargandoLista)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _subordinadosActuales.isEmpty && !_cargandoLista
                ? const Center(child: Text('No hay personal asignado todavía.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _subordinadosActuales.length,
                    itemBuilder: (context, index) {
                      final sub = _subordinadosActuales[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(sub['name'] ?? 'Sin nombre'),
                          subtitle: Text(sub['rol'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _confirmarEliminacion(sub),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Lógica para enviar la asignación al backend
  Future<void> _confirmarAsignacion() async {
    setState(() => _enviando = true);
    try {
      final api = ref.read(apiServiceProvider);
      // Usamos el ID del subordinado seleccionado y el ID del jefe (widget.usuario)
      await api.asignarJefe(
        _subordinadoSeleccionado!,
        widget.usuario['id'],
        widget.usuario['rol'],
      );

      _subordinadoSeleccionado = null;
      await _cargarSubordinados(); // Refrescar lista local
      ref.invalidate(
        usuariosProvider,
      ); // Refrescar lista global si es necesario

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asignación realizada con éxito')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // Lógica para eliminar la asignación (limpiar jefeDirecto)
  Future<void> _confirmarEliminacion(Map<String, dynamic> subordinado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar del equipo'),
        content: Text(
          '¿Deseas desvincular a ${subordinado['name']} de este jefe?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('QUITAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await ref.read(apiServiceProvider).quitarSubordinado(subordinado['id']);
        _cargarSubordinados();
        ref.invalidate(usuariosProvider);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
