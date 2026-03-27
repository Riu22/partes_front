import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

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

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ref
        .read(authProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text.trim());
    if (!ok && mounted) {
      setState(() {
        _error = 'Email o contraseña incorrectos';
        _loading = false;
      });
    }
  }

  // --- NUEVA FUNCIÓN PARA RECUPERAR CONTRASEÑA ---
  Future<void> _mostrarDialogoRecuperacion() async {
    final recoverEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Introduce tu email y te enviaremos un enlace para restablecer tu contraseña.',
            ),
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
            onPressed: () async {
              final email = recoverEmailController.text.trim();
              if (email.isEmpty) return;

              // LLAMADA A TU SERVICIO CON DIO
              final ok = await ref
                  .read(authServiceProvider)
                  .solicitarRecuperacion(email);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Correo enviado con éxito'
                          : 'Error al enviar el correo',
                    ),
                  ),
                );
              }
            },
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
          child: Padding(
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

                // --- BOTÓN OLVIDÉ MI CONTRASEÑA ---
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
                  height: 48, // Un poco más de altura para el botón
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Entrar'),
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
