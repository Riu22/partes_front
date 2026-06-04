/// =============================================================================
/// PROVEEDOR DE AUTENTICACION (auth_provider.dart)
/// =============================================================================
///
/// QUE ES UN PROVIDER (Riverpod)?
/// -----------------------------------------------------------------------------
/// Un Provider es como un altavoz central. Gestiona datos (estado) y notifica
/// automaticamente a todas las pantallas que estan escuchando. Cuando el dato
/// cambia, las pantallas se actualizan solas.
///
/// Imagina un altavoz en una fabrica:
///   - El altavoz (Provider) tiene la informacion (ej. perfil del usuario).
///   - Los trabajadores (Widgets) escuchan el altavoz.
///   - Cuando la informacion cambia, el altavoz anuncia el cambio.
///   - Todos los trabajadores que escuchaban se actualizan al instante.
///
/// CONCEPTOS FUNDAMENTALES DE RIVERPOD:
///
///   ref.watch(provider)
///     Suscribe al widget al provider. Cada vez que el provider cambia su
///     valor, el widget se reconstruye. Ej: ref.watch(authProvider)
///
///   ref.read(provider)
///     Lee el valor actual una sola vez. No se suscribe. No causa
///     reconstruccion. Ej: ref.read(apiServiceProvider)
///
///   ref.read(provider.notifier).metodo()
///     Accede al notifier para llamar metodos que modifican el estado.
///     Ej: ref.read(authProvider.notifier).login()
///
///   ref.invalidate(provider)
///     Marca al provider como desactualizado. La proxima vez que alguien
///     lo escuche, se ejecutara de nuevo. Sirve para refrescar datos.
///
///   .future (propiedad de AsyncValue)
///     Obtiene el Future del valor final. Permite esperar datos en codigo.
///     Ej: await ref.watch(authProvider.future)
///
///   .valueOrNull (propiedad de AsyncValue)
///     Obtiene el valor actual si el estado es AsyncData, o null si esta
///     cargando o en error. Sirve para lecturas rapidas.
///
///   .when() (metodo de AsyncValue)
///     Recibe tres callbacks: data, loading, error. Renderiza diferente
///     segun el estado. Es la forma RECOMENDADA de consumir providers:
///       provider.when(
///         data: (valor) => WidgetExitoso(),
///         loading: () => WidgetCargando(),
///         error: (e, st) => WidgetError(),
///       );
///
///   AsyncNotifier<Perfil?>
///     Clase base para providers con estado mutable asincrono. Tiene un
///     metodo build() que se ejecuta al inicio y metodos personalizados
///     que modifican this.state. El estado siempre es un AsyncValue.
///
///   AsyncLoading / AsyncData / AsyncError
///     Los tres estados posibles de un AsyncValue:
///     - AsyncLoading: el provider esta obteniendo datos.
///     - AsyncData:    el provider tiene datos exitosamente.
///     - AsyncError:   el provider fallo al obtener datos.
///
/// OFFLINE / ONLINE:
///   - Con internet: llama al servidor para autenticar, guarda copia local.
///   - Sin internet: usa la copia local del perfil si existe.
///   - Si no hay copia local ni internet, el usuario no puede acceder.
///   - Al recuperar la conexion, el usuario debe hacer login de nuevo
///     si quiere actualizar su perfil.
///
/// QUE HACE ESTE ARCHIVO:
///   Maneja todo el ciclo de vida de la autenticacion:
///   1. Iniciar sesion (login) con email y contrasena.
///   2. Cerrar sesion (logout) borrando tokens.
///   3. Cargar el perfil del usuario desde el servidor o local.
///   4. Cambiar la contrasena.
///   5. Recuperar contrasena olvidada via email.
///   6. Funcionar sin internet con datos cacheados.
/// =============================================================================

/// Proveedor de autenticacion.
///
/// Maneja todo lo relacionado con la sesion del usuario:
/// iniciar sesion, cerrar sesion, cargar el perfil, cambiar la contrasena,
/// y recuperar la contrasena olvidada.
/// Cuando no hay internet, usa los datos guardados en el telefono
/// para que la app siga funcionando sin conexion.
import 'package:connectivity_plus/connectivity_plus.dart';
// connectivity_plus: detecta el estado de la red (wifi, datos moviles, etc.).

import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod: gestion de estado con providers, ref, AsyncNotifier, etc.

import '../models/perfil.dart';
// Modelo Perfil: datos del usuario (id, nombre, email, rol, etc.).

import '../services/auth_service.dart';
// AuthService: maneja tokens, login/logout con el servidor, y almacenamiento local.

import '../services/api_service.dart';
// ApiService: llama a los endpoints REST del servidor.

import 'package:flutter/foundation.dart';
// debugPrint: imprime logs solo en modo debug (no en produccion).

/// Provee el servicio de autenticacion.
///
/// Es un Provider simple (no Future, no Stream). Crea la instancia de
/// AuthService UNA SOLA VEZ y la reutiliza en toda la app.
///
/// Uso desde otros providers:
///   ref.read(authServiceProvider).login(email, password)
///   ref.read(authServiceProvider).getToken()
///
/// Provider<Tipo>: el callback recibe (ref) y debe retornar el valor.
final authServiceProvider = Provider((ref) => AuthService());

/// Provee el servicio de API principal.
///
/// Necesita AuthService para incluir el token de autenticacion en cada
/// peticion HTTP. Tambien es un Provider simple de una sola instancia.
///
/// NOTA: se usa ref.read() en lugar de ref.watch() porque AuthService
/// no cambia durante la vida de la app. No necesitamos suscribirnos.
final apiServiceProvider = Provider((ref) {
  final authService = ref.read(authServiceProvider);
  return ApiService(authService);
});

// ===========================================================================
// AuthNotifier: notifier que maneja la sesion del usuario
// ===========================================================================
//
// AsyncNotifier<Perfil?>:
//   - Tipo de estado: Perfil? (el perfil del usuario, o null sin sesion).
//   - El estado siempre es un AsyncValue (loading, data, error).
//   - build() se ejecuta una vez al crear el provider.
//   - Los metodos (login, logout, etc.) modifican this.state.
//   - Cualquier cambio en this.state notifica a todos los widgets
//     que estan haciendo ref.watch(authProvider).
//
// El signo ? en Perfil? significa que el perfil puede ser null.
// null = no hay sesion activa.
// Perfil = hay sesion activa con datos del usuario.
// ===========================================================================

/// Controla el estado de la sesion del usuario.
///
/// Este notifier mantiene el perfil del usuario que inicio sesion,
/// y provee metodos para iniciar sesion, cerrarla, y manejar
/// la autenticacion incluso cuando no hay conexion a internet.
///
/// Estados posibles:
///   AsyncLoading        -> cargando perfil inicial (al abrir la app)
///   AsyncData(null)     -> sin sesion activa
///   AsyncData(Perfil)   -> sesion activa con datos del usuario
///   AsyncError          -> error al cargar el perfil
class AuthNotifier extends AsyncNotifier<Perfil?> {
  @override
  /// Construye el estado inicial al abrir la app.
  ///
  /// Se ejecuta automaticamente cuando el provider se usa por primera vez.
  /// Decide si hay sesion activa revisando si existe un token guardado.
  ///
  /// Retorna:
  ///   - Perfil: si hay token valido y se pudo cargar el perfil.
  ///   - null: si no hay token (nadie ha iniciado sesion).
  ///
  /// build() solo se ejecuta UNA VEZ. Para cambiar el estado despues,
  /// se usan login(), logout(), etc.
  Future<Perfil?> build() async {
    // Obtener el token JWT guardado en el almacenamiento interno del telefono.
    // Si no hay token, significa que el usuario nunca inicio sesion o
    // ya cerro sesion previamente.
    final token = await ref.read(authServiceProvider).getToken();
    if (token == null) return null;

    // Hay token guardado. Verificar si tenemos conexion a internet.
    final hayRed = await _checkRed();

    // MODO OFFLINE: no hay internet, usar copia local del perfil.
    // Si no hay copia local, retornar null (no se puede recuperar sesion).
    if (!hayRed) {
      final perfilLocal = await ref.read(authServiceProvider).getPerfilLocal();
      if (perfilLocal != null) return Perfil.fromJson(perfilLocal);
      return null;
    }

    // MODO ONLINE: hay internet, cargar perfil fresco desde el servidor.
    return await _cargarPerfilServidor();
  }

  /// Carga el perfil del usuario desde el servidor.
  ///
  /// Hace una peticion HTTP a la API para obtener los datos del perfil.
  /// Si la peticion falla (error de red, timeout, servidor caido), usa
  /// la copia guardada localmente como respaldo (fallback).
  ///
  /// Retorna:
  ///   - Perfil: si se pudo obtener (del servidor o del cache local).
  ///   - null: si no se pudo obtener de ninguna fuente.
  Future<Perfil?> _cargarPerfilServidor() async {
    try {
      // Llamar a GET /api/profile/ en el servidor.
      // El ApiService ya incluye el token JWT en el header Authorization.
      final data = await ref.read(apiServiceProvider).getMyProfile();

      // Guardar una copia local del perfil para uso offline futuro.
      // Esto permite que la proxima vez que no haya internet, el usuario
      // pueda ver sus datos sin conexion.
      await ref.read(authServiceProvider).guardarPerfilLocal(data);

      // Convertir el JSON (Map<String, dynamic>) a un objeto Perfil.
      return Perfil.fromJson(data);
    } catch (e, stackTrace) {
      // Si falla la peticion al servidor, intentar usar copia local.
      debugPrint(' Error cargando perfil: $e');
      debugPrint(' STACK TRACE: $stackTrace');

      // Fallback: cargar el perfil desde almacenamiento local.
      final perfilLocal = await ref.read(authServiceProvider).getPerfilLocal();
      if (perfilLocal != null) return Perfil.fromJson(perfilLocal);
      return null;
    }
  }

  /// Inicia sesion con correo electronico y contrasena.
  ///
  /// Parametros:
  ///   - [email]: el correo electronico del usuario.
  ///   - [password]: la contrasena del usuario.
  ///
  /// FLUJO COMPLETO:
  ///   1. Poner estado en AsyncLoading (la UI muestra spinner).
  ///   2. Verificar si hay conexion a internet.
  ///   3. Sin internet -> buscar perfil guardado localmente.
  ///      - Si existe: cargarlo y permitir acceso offline.
  ///      - Si no existe: denegar acceso.
  ///   4. Con internet -> llamar al servidor para autenticar.
  ///      - Si credenciales validas: obtener token, cargar perfil.
  ///      - Si credenciales invalidas: retornar false.
  ///
  /// Retorna:
  ///   - true: login exitoso (perfil cargado en el estado).
  ///   - false: login fallo (credenciales invalidas o sin datos offline).
  Future<bool> login(String email, String password) async {
    // Poner el estado en AsyncLoading. Esto hace que la UI muestre
    // un indicador de carga (CircularProgressIndicator) automaticamente.
    state = const AsyncLoading();

    try {
      // Verificar si el telefono tiene conexion a internet.
      final hayRed = await _checkRed();

      // MODO OFFLINE: sin conexion a internet.
      if (!hayRed) {
        // Solo se permite login offline si hay un perfil previamente cacheado.
        debugPrint(' Intento de login sin red. Buscando perfil local...');
        final perfilLocal = await ref
            .read(authServiceProvider)
            .getPerfilLocal();

        if (perfilLocal != null) {
          // Cargar el perfil desde la copia local y permitir acceso.
          state = AsyncData(Perfil.fromJson(perfilLocal));
          return true;
        }

        // No hay copia local: no se puede acceder sin internet.
        state = const AsyncData(null);
        return false;
      }

      // MODO ONLINE: llamar al servidor para autenticar.
      // El metodo login() de AuthService ya maneja internamente:
      //   - Llamar al endpoint de login.
      //   - Recibir JWT y refresh_token.
      //   - Guardar ambos en almacenamiento local via _guardarSesion().
      final token = await ref.read(authServiceProvider).login(email, password);

      if (token != null) {
        // Login exitoso. Cargar el perfil completo desde el servidor.
        final perfil = await _cargarPerfilServidor();
        state = AsyncData(perfil);
        return perfil != null;
      }

      // Credenciales invalidas: el servidor rechazo el login.
      state = const AsyncData(null);
      return false;
    } catch (e, stackTrace) {
      // Error inesperado (timeout de red, servidor caido, excepcion, etc.).
      debugPrint(' Error en login: $e');
      debugPrint(' STACK TRACE: $stackTrace');
      state = const AsyncData(null);
      return false;
    }
  }

  /// Cambia la contrasena del usuario que tiene la sesion activa.
  ///
  /// [newPassword] es la nueva contrasena que se quiere establecer.
  /// Retorna true si el cambio fue exitoso.
  ///
  /// No modifica el estado del provider porque cambiar la contrasena
  /// no afecta al perfil del usuario que mostramos en la UI.
  Future<bool> changePassword(String newPassword) async {
    try {
      await ref.read(authServiceProvider).cambiarPassword(newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cierra la sesion del usuario.
  ///
  /// Elimina el token JWT y el refresh_token del almacenamiento local,
  /// y resetea el estado del provider a null (sin sesion).
  ///
  /// Consecuencias:
  ///   - Todas las pantallas que escuchan authProvider se reconstruyen.
  ///   - La app redirige automaticamente a la pantalla de login.
  ///   - Los datos offline del perfil se conservan (por si se necesita
  ///     login offline mas tarde).
  Future<void> logout() async {
    // AuthService.logout() borra tokens del almacenamiento local.
    await ref.read(authServiceProvider).logout();

    // Resetear el estado a "sin sesion". Esto activa la notificacion
    // a todos los widgets que estan haciendo ref.watch(authProvider).
    state = const AsyncData(null);
  }

  /// Revisa si el telefono tiene conexion a internet.
  ///
  /// Usa el paquete connectivity_plus para detectar si hay Wi-Fi,
  /// datos moviles, ethernet, o cualquier tipo de conexion de red.
  ///
  /// Retorna:
  ///   - true: hay al menos un tipo de conexion activa.
  ///   - false: no hay ninguna conexion (offline total).
  Future<bool> _checkRed() async {
    // checkConnectivity() devuelve una lista de ConnectivityResult.
    // Cada elemento representa el estado de un tipo de red.
    // Si todos los elementos son ConnectivityResult.none, no hay red.
    final resultado = await Connectivity().checkConnectivity();
    return resultado.any((r) => r != ConnectivityResult.none);
  }

  /// Solicita un correo para recuperar la contrasena olvidada.
  ///
  /// [email] es el correo con el que se registro el usuario.
  /// Retorna true si el correo de recuperacion se envio correctamente.
  ///
  /// El servidor envia un email con un enlace o token de recuperacion.
  /// El usuario usa ese token para establecer una nueva contrasena.
  Future<bool> resetPassword(String email) async {
    return await ref.read(authServiceProvider).solicitarRecuperacion(email);
  }

  /// Cambia la contrasena usando un token de recuperacion.
  ///
  /// Se usa cuando el usuario hace clic en el enlace de recuperacion
  /// que llego a su correo electronico.
  ///
  /// Parametros:
  ///   - [token]: codigo de recuperacion enviado por email.
  ///   - [newPassword]: la nueva contrasena a establecer.
  ///
  /// Retorna true si el cambio fue exitoso.
  Future<bool> changePasswordConToken(String token, String newPassword) async {
    try {
      await ref.read(authServiceProvider).cambiarPasswordConToken(token, newPassword);
      return true;
    } catch (e) {
      debugPrint(' Error changePasswordConToken: $e');
      return false;
    }
  }
}

/// Provee el estado de autenticacion de la app.
///
/// Este es el provider principal que las pantallas usan para:
///   1. Saber si el usuario esta logueado (perfil != null).
///   2. Obtener los datos del usuario actual.
///   3. Llamar a metodos de autenticacion (login, logout, etc.).
///
/// Uso tipico en una pantalla:
/// ```dart
///   // Escuchar cambios en la autenticacion:
///   final authState = ref.watch(authProvider);
///
///   // Renderizar segun el estado:
///   authState.when(
///     data: (perfil) => perfil != null ? HomeScreen() : LoginScreen(),
///     loading: () => SplashScreen(),
///     error: (err, _) => ErrorScreen(err.toString()),
///   );
///
///   // Llamar a metodos del notifier:
///   ref.read(authProvider.notifier).login('correo', 'pass');
///   ref.read(authProvider.notifier).logout();
/// ```
///
/// AsyncNotifierProvider<AuthNotifier, Perfil?>:
///   - AuthNotifier: la clase que maneja la logica de autenticacion.
///   - Perfil?: el tipo de dato que maneja (puede ser null).
///   - Siempre expone el estado como AsyncValue (loading/data/error).
final authProvider = AsyncNotifierProvider<AuthNotifier, Perfil?>(
  AuthNotifier.new,
);
