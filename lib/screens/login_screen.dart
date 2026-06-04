// =============================================================================
// PANTALLA: LoginScreen
// -----------------------------------------------------------------------------
// QUE ES: Pantalla de inicio de sesion de la aplicacion.
// PARA QUE SIRVE: Permite al usuario autenticarse con email y contrasena.
// QUIEN LA VE (rol): Todos los usuarios sin sesion activa (publica).
// COMO SE LLEGA: Ruta inicial '/' o '/login' del enrutador.
// A DONDE VA DESPUES: A '/partes' si el login es exitoso.
// QUE DATOS NECESITA: Email y contrasena del usuario.
// OFFLINE: No, requiere conexion para autenticar.
// =============================================================================

/// Pantalla de inicio de sesion.
/// Permite al usuario introducir su email y contrasena para acceder.
/// Tambien incluye un enlace para recuperar contrasena si la ha olvidado,
/// y una seccion para descargar la app Android desde la version web.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../config/env.dart';
import '../services/update_service.dart';

/// Pantalla principal de inicio de sesion.
/// Muestra los campos de email y contrasena, boton de "Entrar",
/// enlace para recuperar contrasena y, en web, descarga de la app.
///
/// Flutter concept: ConsumerStatefulWidget es un widget que puede
/// escuchar cambios en los providers de Riverpod y mantener estado
/// mutable interno a traves de su clase State asociada.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// Estado interno del login: controla los textos, la carga, los errores
/// y la visibilidad de la contrasena.
///
/// Lifecycle:
/// 1. initState: se ejecuta una vez al crear el widget. Aqui se inicia
///    la comprobacion de actualizaciones en dispositivos moviles.
/// 2. build: se ejecuta cada vez que el estado cambia (setState).
///    Construye la interfaz grafica completa.
/// 3. dispose: se ejecuta al destruir el widget. Libera controladores.
class _LoginScreenState extends ConsumerState<LoginScreen> {
  // TextEditingController: controla el texto ingresado en un TextField.
  // Debe ser inicializado una vez y liberado en dispose.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false; // Indica si hay una peticion de login en curso
  String? _error; // Mensaje de error a mostrar al usuario
  bool _verPassword = false; // Alterna visibilidad de la contrasena
  final _updateService = UpdateService(); // Servicio para verificar actualizaciones

  @override
  void dispose() {
    // Libera los controladores para evitar fugas de memoria
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Solo comprueba actualizaciones en dispositivos moviles (no en web)
    // addPostFrameCallback ejecuta el callback despues del primer frame
    // para evitar llamar al API antes de que el widget este montado.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
    }
  }

  /// Comprueba si hay una version mas reciente de la app disponible.
  /// Solo se ejecuta en dispositivos moviles (no en web).
  /// Utiliza el servicio UpdateService para consultar el backend.
  /// Si hay actualizacion, muestra un AlertDialog con opciones.
  Future<void> _checkUpdate() async {
    // Consulta al backend si hay actualizacion disponible
    final update = await _updateService.hayActualizacion();
    if (update != null && mounted) {
      // mounted verifica que el widget aun esta en el arbol
      // showDialog: funcion de Flutter que muestra un dialogo modal
      showDialog(
        context: context,
        barrierDismissible: false, // No permite cerrar tocando fuera
        builder: (context) => AlertDialog(
          title: const Text('Nueva version disponible'),
          content: Text(
            'Hay una actualizacion a la version ${update['version']}.\n\n'
            'Descargala para tener las ultimas mejoras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _updateService.abrirDescarga(update['url']!);
              },
              child: const Text('Descargar'),
            ),
          ],
        ),
      );
    }
  }

  // --- FUNCION PARA DESCARGAR EL ZIP (Solo se llama desde Web) ---
  /// Abre la URL de descarga del APK en el navegador.
  /// Solo visible y util cuando la app se ejecuta en entorno web.
  /// Usa url_launcher para abrir el enlace externo.
  Future<void> _descargarApp() async {
    final Uri url = Uri.parse(Env.apkUrl);

    try {
      // launchUrl abre la URL en el navegador externo
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir la URL de descarga');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar: muestra un mensaje
        // temporal en la parte inferior de la pantalla
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar descarga: $e')),
        );
      }
    }
  }

  /// Intenta iniciar sesion llamando al proveedor de autenticacion.
  /// Muestra un mensaje de error si las credenciales son incorrectas.
  ///
  /// Flujo:
  /// 1. Valida que los campos no esten vacios
  /// 2. Activa el indicador de carga
  /// 3. Llama a authProvider.notifier.login()
  /// 4. Si ok es false, muestra error de credenciales
  /// 5. Si hay excepcion, muestra error de conexion
  /// 6. En ambos casos, desactiva el indicador de carga en finally
  Future<void> _login() async {
    // Validacion basica de campos obligatorios
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Por favor, rellena todos los campos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null; // Limpia errores anteriores
    });

    try {
      // ref.read(authProvider.notifier) obtiene el notifier del provider
      // que contiene la logica de negocio para autenticar
      final ok = await ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text.trim());

      // Si login devuelve false, las credenciales son incorrectas
      if (!ok && mounted) {
        setState(() {
          _error = 'Email o contrasena incorrectos';
        });
      }
    } catch (e) {
      // Captura errores de red o del servidor
      if (mounted) {
        setState(() {
          _error = 'Error de conexion: $e';
        });
      }
    } finally {
      // finally se ejecuta siempre, haya error o no
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Abre un dialogo para que el usuario introduzca su email
  /// y reciba un enlace para restablecer su contrasena.
  ///
  /// Flutter concept: StatefulBuilder permite tener estado mutable
  /// dentro de un showDialog sin necesidad de crear una clase separada.
  /// El parametro setStateDialog solo afecta al contenido del dialogo.
  Future<void> _mostrarDialogoRecuperacion() async {
  final recoverEmailController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) {
      bool sendingEmail = false;
      
      // StatefulBuilder permite usar setState dentro del dialogo
      return StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Recuperar contrasena'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Introduce tu email y te enviaremos un enlace.'),
              const SizedBox(height: 16),
              TextField(
                controller: recoverEmailController,
                keyboardType: TextInputType.emailAddress,
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
  onPressed: sendingEmail
      ? null // Deshabilita el boton mientras se envia
      : () async {
          final email = recoverEmailController.text.trim();
          if (email.isEmpty) return;

          setStateDialog(() => sendingEmail = true);

          // Llama al provider para enviar el email de recuperacion
          final ok = await ref
              .read(authProvider.notifier)
              .resetPassword(email);

          if (context.mounted) {
            Navigator.pop(context); // Cierra el dialogo
            // SnackBar: notificacion temporal en la parte inferior
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok
                    ? 'Email enviado, revisa tu bandeja de entrada'
                    : 'Error al enviar el email'),
                backgroundColor: ok ? Colors.green : Colors.red,
              ),
            );
          }
        },
  child: sendingEmail
      ? const SizedBox(
          height: 16, width: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
      : const Text('Enviar enlace'),
),
          ],
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    // build se ejecuta cada vez que se llama a setState
    // Construye la interfaz completa del login
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400), // Limita el ancho maximo en pantallas grandes
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.engineering, size: 72, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Gestion de Partes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress, // Teclado con @
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !_verPassword, // Oculta el texto si _verPassword es false
                  decoration: InputDecoration(
                    labelText: 'Contrasena',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      // Icono de ojo para alternar visibilidad
                      icon: Icon(
                        _verPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _verPassword = !_verPassword),
                    ),
                  ),
                  onSubmitted: (_) => _login(), // Envia al pulsar Enter
                ),
                // Muestra el mensaje de error si existe
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _mostrarDialogoRecuperacion,
                    child: const Text('Has olvidado tu contrasena?'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _login, // null deshabilita el boton
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

                // --- SECCION DE DESCARGA APK (SOLO VISIBLE SI ES WEB) ---
                // kIsWeb es una constante de Flutter que indica si la app
                // se ejecuta en un navegador web
                if (kIsWeb) ...[
                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 20),
                  const Text(
                    'Eres operario y no tienes la App?',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
