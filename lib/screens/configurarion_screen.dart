import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;

    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const SizedBox(height: 16),
          const Center(
            child: CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              perfil.nombreCompleto,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Chip(
              label: Text(perfil.rol.replaceAll('_', ' ')),
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Correo electrónico'),
            subtitle: Text(perfil.email),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.orange),
            title: const Text('Seguridad'),
            subtitle: const Text('Cambiar mi contraseña'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _mostrarDialogoCambioPassword(context, ref),
          ),
          ListTile(
            leading: Icon(
              perfil.activo ? Icons.check_circle : Icons.cancel,
              color: perfil.activo ? Colors.green : Colors.red,
            ),
            title: const Text('Estado de la cuenta'),
            subtitle: Text(perfil.activo ? 'Activo' : 'Inactivo'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Permisos y accesos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Nivel de acceso'),
            subtitle: Text(perfil.nivelAcceso),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCambioPassword(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nueva contraseña',
              hintText: 'Mínimo 6 caracteres',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: enviando
                  ? null
                  : () async {
                      if (controller.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mínimo 6 caracteres')),
                        );
                        return;
                      }
                      setState(() => enviando = true);
                      try {
                        await ref
                            .read(authServiceProvider)
                            .cambiarPassword(controller.text);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Contraseña actualizada correctamente',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => enviando = false);
                      }
                    },
              child: enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ACTUALIZAR'),
            ),
          ],
        ),
      ),
    );
  }
}
