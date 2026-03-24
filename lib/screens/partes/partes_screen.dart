import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';

class PartesScreen extends ConsumerWidget {
  const PartesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Partes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(partesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/partes/nuevo'),
        child: const Icon(Icons.add),
      ),
      body: partesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (partes) => partes.isEmpty
            ? const Center(child: Text('No hay partes registrados'))
            : ListView.builder(
                itemCount: partes.length,
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemBuilder: (context, index) {
                  final parte = partes[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      leading: Icon(
                        parte.firmado ? Icons.verified : Icons.pending_actions,
                        color: parte.firmado ? Colors.green : Colors.orange,
                        size: 30,
                      ),
                      title: Text(
                        parte.obraNombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${parte.operarioNombre} • ${DateFormat('dd/MM/yyyy').format(parte.fecha)}",
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${parte.horasNormales}h",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            parte.firmado ? "FIRMADO" : "PENDIENTE",
                            style: TextStyle(
                              fontSize: 10,
                              color: parte.firmado
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Descripción:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(parte.descripcion),
                              const SizedBox(height: 8),
                              Text(
                                "Horas extra: ${parte.horasExtra}h",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 15),
                              // Botón firmar — solo si no está firmado
                              // y el usuario no es operario
                              if (!parte.firmado &&
                                  perfil != null &&
                                  !perfil.esOperario)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _validarParte(context, ref, parte.id),
                                    icon: const Icon(Icons.edit_note),
                                    label: const Text("FIRMAR PARTE"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _validarParte(BuildContext context, WidgetRef ref, int parteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Validar parte?"),
        content: const Text(
          "Al firmar confirmas que las horas y tareas son correctas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(apiServiceProvider).validarParte(parteId);
                ref.invalidate(partesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al firmar: $e')),
                  );
                }
              }
            },
            child: const Text("CONFIRMAR FIRMA"),
          ),
        ],
      ),
    );
  }
}
