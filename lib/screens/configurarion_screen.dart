// =============================================================================
// PANTALLA: ConfiguracionScreen
// -----------------------------------------------------------------------------
// QUE ES: Pantalla de configuracion del perfil del usuario.
// PARA QUE SIRVE: Muestra datos personales, permite cambiar email y contrasena.
// QUIEN LA VE (rol): Cualquier usuario autenticado.
// COMO SE LLEGA: Desde el menu lateral (AppDrawer) o boton de configuracion.
// A DONDE VA DESPUES: Vuelve a '/partes' al cerrar.
// QUE DATOS NECESITA: El perfil del usuario desde authProvider.
// OFFLINE: No, requiere conexion para cambiar contrasena o email.
// =============================================================================

/// Pantalla de configuracion del perfil del usuario.
/// Muestra los datos personales, permite cambiar el email y la contrasena,
/// e indica el estado de la cuenta y el nivel de acceso.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Muestra la informacion del perfil: nombre, email, rol, estado.
/// Permite cambiar la contrasena y el correo electronico mediante dialogos.
///
/// Flutter concept: ConsumerWidget es un widget sin estado mutable
/// que puede leer providers de Riverpod mediante el parametro WidgetRef ref.
/// Se reconstruye cuando el provider que observa cambia.
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch(authProvider).valueOrNull: observa el provider de autenticacion
    // valueOrNull devuelve null si el provider esta cargando o tiene error
    final perfil = ref.watch(authProvider).valueOrNull;

    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion del Perfil'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/partes'), // Navegacion con go_router
        ),
      ),
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

          // Correo electronico con opcion de edicion
          // ListTile: widget de Material Design con icono, titulo y subtitulo
          ListTile(
            leading: const Icon(Icons.email_outlined, color: Colors.blue),
            title: const Text('Correo electronico'),
            subtitle: Text(perfil.email),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: () => _mostrarDialogoCambioEmail(context, ref),
          ),

          const Divider(),

          // Seguridad y Cambio de Contrasena
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.orange),
            title: const Text('Seguridad'),
            subtitle: const Text('Cambiar mi contrasena'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _mostrarDialogoCambioPassword(context, ref),
          ),

          // Estado de la cuenta
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
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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

  // --- METODOS DE DIALOGOS ---

  /// Muestra un dialogo para que el usuario introduzca y confirme
  /// una nueva contrasena. Valida que tenga al menos 6 caracteres.
  ///
  /// Flutter concept: showDialog muestra un dialogo modal.
  /// StatefulBuilder permite mantener estado local dentro del dialogo
  /// (como el estado de carga y los controladores).
  void _mostrarDialogoCambioPassword(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cambiar contrasena'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nueva contrasena',
              hintText: 'Minimo 6 caracteres',
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
                      // Validacion: minimo 6 caracteres
                      if (controller.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Minimo 6 caracteres')),
                        );
                        return;
                      }
                      setState(() => enviando = true);
                      try {
                        // Llama al servicio de autenticacion para cambiar la contrasena
                        await ref
                            .read(authServiceProvider)
                            .cambiarPassword(controller.text);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Contrasena actualizada correctamente',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        // Manejo de errores: muestra el error en un SnackBar
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

  /// Muestra un dialogo para cambiar el correo electronico.
  /// Se envia un mensaje de confirmacion a la nueva direccion.
  ///
  /// Incluye validacion basica de formato de email (contiene @).
  /// El cambio requiere confirmacion por email.
  void _mostrarDialogoCambioEmail(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cambiar correo electronico'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Se enviara un mensaje de confirmacion a la nueva direccion para validar el cambio.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Nuevo correo',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
                      // Validacion basica: debe contener @
                      if (!controller.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email no valido')),
                        );
                        return;
                      }
                      setState(() => enviando = true);
                      try {
                        await ref
                            .read(authServiceProvider)
                            .cambiarEmail(controller.text.trim());

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Revisa tu bandeja de entrada para confirmar el cambio',
                              ),
                              duration: Duration(seconds: 5),
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
                  : const Text('CAMBIAR CORREO'),
            ),
          ],
        ),
      ),
    );
  }
}
