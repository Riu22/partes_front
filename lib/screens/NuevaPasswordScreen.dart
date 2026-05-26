import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../config/env.dart';

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
  bool _tokenVerificado = false;
  String? _errorToken;
  String? _accessToken; // ← token guardado localmente

  @override
  void initState() {
    super.initState();
    _verificarToken();
  }

  Future<void> _verificarToken() async {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final type = uri.queryParameters['type'];

    debugPrint('🔗 URI completa: $uri');
    debugPrint('🔑 token: $token | type: $type');

    if (token == null || type != 'recovery') {
      setState(() => _errorToken = 'Enlace inválido o expirado.');
      return;
    }

    try {
      final dio = Dio();
      final response = await dio.post(
        '${Env.supabaseUrl}/auth/v1/verify',
        data: {'token': token, 'type': 'recovery'},
        options: Options(
          headers: {
            'apikey': Env.supabaseAnonKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      _accessToken = response.data['access_token'] as String?;
      debugPrint('✅ accessToken obtenido: ${_accessToken?.substring(0, 20)}...');

      if (_accessToken == null) {
        setState(() => _errorToken = 'No se pudo obtener la sesión.');
        return;
      }

      setState(() => _tokenVerificado = true);
    } catch (e) {
      debugPrint('❌ Error verificando token: $e');
      setState(() => _errorToken = 'El enlace ha expirado o ya fue usado.');
    }
  }

  Future<void> _actualizarContrasena() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accessToken == null) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('🔑 Usando accessToken: ${_accessToken!.substring(0, 20)}...');

      final success = await ref
          .read(authProvider.notifier)
          .changePasswordConToken(_accessToken!, _passController.text.trim());

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Contraseña actualizada con éxito!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/login');
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
    if (_errorToken != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restablecer Contraseña')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorToken!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_tokenVerificado) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer Contraseña')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Introduce tu nueva contraseña',
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