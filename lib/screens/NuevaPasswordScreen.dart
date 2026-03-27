import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class NuevaPasswordScreen extends ConsumerStatefulWidget {
  const NuevaPasswordScreen({super.key});

  @override
  ConsumerState<NuevaPasswordScreen> createState() =>
      _NuevaPasswordScreenState();
}

class _NuevaPasswordScreenState extends ConsumerState<NuevaPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;

  Future<void> _actualizarContrasena() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Llamamos al método que añadimos antes a tu AuthNotifier
      final success = await ref
          .read(authProvider.notifier)
          .changePassword(_passController.text.trim());

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Contraseña actualizada con éxito!')),
          );
          // Redirigir al login o al perfil
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar la contraseña')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer Contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Introduce tu nueva contraseña para el sistema de obras.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (value) {
                  if (value != _passController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _actualizarContrasena,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Nueva Contraseña'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }
}
