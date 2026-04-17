import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  // --- FUNCIÓN PARA DESCARGAR EL ZIP ---
  Future<void> _descargarApp() async {
    final String path =
        '${Env.supabaseUrl}/storage/v1/object/public/app/app-release.zip';
    final Uri url = Uri.parse(path);

    try {
      print('intentando descargar desde: $url'); // Para debug
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir la URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar descarga: $e')),
        );
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ok = await ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text.trim());

      if (!ok && mounted) {
        setState(() {
          _error = 'Email o contraseña incorrectos';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: $e';
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // (Tu función _mostrarDialogoRecuperacion se mantiene igual...)
  Future<void> _mostrarDialogoRecuperacion() async {
    final recoverEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Introduce tu email y te enviaremos un enlace.'),
            const SizedBox(height: 16),
            TextField(
              controller: recoverEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context), // Simplificado para el ejemplo
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            // Añadido para evitar error de píxeles en pantallas pequeñas
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.engineering, size: 72, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Gestión de Partes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _mostrarDialogoRecuperacion,
                    child: const Text('¿Has olvidado tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Entrar'),
                  ),
                ),

                // --- SECCIÓN DE DESCARGA APK ---
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  '¿Eres operario y no tienes la App?',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _descargarApp,
                  icon: const Icon(Icons.android, color: Colors.green),
                  label: const Text('Descargar App Android (ZIP)'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
