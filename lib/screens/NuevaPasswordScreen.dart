// =============================================================================
// PANTALLA: NuevaPasswordScreen
// -----------------------------------------------------------------------------
// QUE ES: Pantalla para restablecer la contrasena desde un enlace recibido por email.
// PARA QUE SIRVE: Verifica el token del enlace y permite escribir nueva contrasena.
// QUIEN LA VE (rol): Usuarios que han solicitado recuperacion de contrasena.
// COMO SE LLEGA: Desde un enlace enviado por email (deep link).
// A DONDE VA DESPUES: A '/login' si el cambio es exitoso.
// QUE DATOS NECESITA: Token de recuperacion de la URL, nueva contrasena.
// OFFLINE: No, requiere conexion para verificar token y cambiar contrasena.
// =============================================================================

/// Pantalla para restablecer la contrasena desde un enlace recibido por email.
/// Verifica que el token del enlace sea valido y permite escribir una nueva
/// contrasena con confirmacion.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Recibe un token de recuperacion desde la URL, lo verifica y
/// muestra un formulario para establecer una nueva contrasena.
///
/// Flutter concept: ConsumerStatefulWidget permite estado mutable
/// y acceso a providers de Riverpod mediante ref.
class NuevaPasswordScreen extends ConsumerStatefulWidget {
  const NuevaPasswordScreen({super.key});

  @override
  ConsumerState<NuevaPasswordScreen> createState() =>
      _NuevaPasswordScreenState();
}

/// Estado interno: gestiona el token de recuperacion, la validacion
/// del formulario y el envio de la nueva contrasena.
///
/// Lifecycle:
/// 1. initState: inicia la verificacion del token de la URL.
/// 2. build: muestra formulario o pantalla de error segun el estado.
/// 3. dispose: libera los controladores de texto.
class _NuevaPasswordScreenState extends ConsumerState<NuevaPasswordScreen> {
  // GlobalKey<FormState>: clave global para identificar y validar el Form.
  // Permite acceder al estado del Form desde cualquier parte del widget.
  final _formKey = GlobalKey<FormState>();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _tokenVerificado = false; // Indica si el token es valido
  String? _errorToken; // Mensaje de error del token
  String? _accessToken; // Token de acceso recuperado

  @override
  void initState() {
    super.initState();
    // Al iniciar, verifica el token de la URL actual
    _verificarToken();
  }

  /// Lee el token de recuperacion de la URL actual y lo valida con el backend.
  /// Si es invalido o ha expirado, muestra un mensaje de error.
  ///
  /// Uri.base contiene la URL actual de la aplicacion, de donde se extrae
  /// el token de recuperacion.
  Future<void> _verificarToken() async {
    try {
      // Llama al servicio que analiza Uri.base y valida el token
      _accessToken = await ref
          .read(authServiceProvider)
          .verificarTokenRecuperacion(Uri.base);

      if (_accessToken == null) {
        // Token invalido o expirado
        setState(() => _errorToken = 'Enlace invalido o expirado.');
      } else {
        setState(() => _tokenVerificado = true);
      }
    } catch (e) {
      debugPrint('Error verificando token: $e');
      setState(() => _errorToken = 'Error al procesar el enlace.');
    }
  }

  /// Envia la nueva contrasena al servidor junto con el token de recuperacion.
  /// Si es exitoso, redirige al login.
  ///
  /// Flujo:
  /// 1. Valida el formulario (minimo 6 caracteres, coincidencia)
  /// 2. Llama al provider para cambiar la contrasena con token
  /// 3. Si ok, muestra SnackBar verde y redirige a /login
  /// 4. Si falla, muestra SnackBar de error
  Future<void> _actualizarContrasena() async {
    // _formKey.currentState!.validate() ejecuta los validators de cada TextFormField
    if (!_formKey.currentState!.validate()) return;
    if (_accessToken == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref
          .read(authProvider.notifier)
          .changePasswordConToken(_accessToken!, _passController.text.trim());

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contrasena actualizada con exito!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/login'); // Redirige al login
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar la contrasena')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si hay error de token, muestra pantalla de error con boton de retorno
    if (_errorToken != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restablecer Contrasena')),
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

    // Mientras se verifica el token, muestra un indicador de carga
    if (!_tokenVerificado) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Token verificado: muestra el formulario para nueva contrasena
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer Contrasena')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey, // Asocia el GlobalKey para validacion
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'Introduce tu nueva contrasena',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  // TextFormField: igual que TextField pero integrado con Form
                  TextFormField(
                    controller: _passController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva Contrasena',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      // Validador: minimo 6 caracteres
                      if (value == null || value.length < 6) {
                        return 'Minimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Contrasena',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                    validator: (value) {
                      // Validador: debe coincidir con la primera contrasena
                      if (value != _passController.text) {
                        return 'Las contrasenas no coinciden';
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
                          : const Text('Guardar Nueva Contrasena'),
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
    // Libera los controladores para evitar fugas de memoria
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }
}
