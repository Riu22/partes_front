/// =============================================================================
/// PROVEEDOR DE PERFILES DE USUARIO (perfiles_provider.dart)
/// =============================================================================
///
/// QUE ES UN PROVIDER (Riverpod)?
/// -----------------------------------------------------------------------------
/// Un Provider es como un altavoz central. Gestiona datos (estado) y notifica
/// automaticamente a todas las pantallas que estan escuchando. Cuando el dato
/// cambia, las pantallas se actualizan solas.
///
/// Imagina un altavoz en una fabrica:
///   - El altavoz (Provider) tiene la informacion (ej. lista de usuarios).
///   - Los trabajadores (Widgets) escuchan el altavoz.
///   - Cuando la informacion cambia, todos se actualizan al instante.
///
/// CONCEPTOS FUNDAMENTALES DE RIVERPOD:
///
///   ref.watch(provider)
///     Suscribe al widget al provider. El widget se reconstruye cuando
///     el provider cambia. Ej: ref.watch(perfilesProvider)
///
///   ref.read(provider)
///     Lee el valor una sola vez sin suscribirse. No causa reconstruccion.
///     Ej: ref.read(apiServiceProvider) para obtener el servicio de API.
///
///   .when() (AsyncValue.when)
///     Renderiza segun el estado del provider: data, loading, error.
///     Es la forma RECOMENDADA de consumir providers en la UI.
///     Ejemplo:
///       ref.watch(perfilesProvider).when(
///         data: (perfiles) => ListaPerfiles(perfiles),
///         loading: () => Spinner(),
///         error: (e, _) => MensajeError(e.toString()),
///       );
///
///   FutureProvider<List<Perfil>>
///     Provider asincrono que ejecuta una funcion UNA VEZ.
///     Ideal para llamadas a la API que obtienen datos y no necesitan
///     actualizacion constante.
///     Estado: AsyncLoading (cargando), AsyncData (datos), AsyncError.
///
/// OFFLINE / ONLINE:
///   Este provider SOLO funciona online. No tiene cache local.
///   Si no hay internet, el estado sera AsyncError y la UI mostrara
///   el mensaje de error correspondiente.
///   La lista de usuarios se necesita solo en pantallas de
///   administracion que requieren conexion activa.
///
/// QUE HACE ESTE ARCHIVO:
///   Obtiene la lista de todos los usuarios registrados en el sistema
///   desde el endpoint /api/usuarios/ del servidor.
///   Se usa para mostrar la lista de trabajadores en las pantallas
///   de administracion (asignar obras, ver perfiles, etc.).
///   Es un archivo pequeno porque solo tiene un provider simple.
/// =============================================================================

/// Proveedor de perfiles de usuario.
///
/// Obtiene la lista de todos los usuarios del sistema
/// desde el servidor. Se usa para mostrar la lista de
/// trabajadores y sus datos.
import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod: gestion de estado con providers, ref, AsyncValue, etc.

import '../models/perfil.dart';
// Modelo Perfil: representa un usuario del sistema con sus datos personales.

import 'auth_provider.dart';
// auth_provider: necesario para acceder a apiServiceProvider, que es el
// servicio HTTP que incluye el token de autenticacion en las peticiones.

/// Provee la lista de todos los perfiles de usuario registrados en el sistema.
///
/// Es un FutureProvider que hace una peticion HTTP al servidor y convierte
/// la respuesta JSON en una lista de objetos [Perfil].
///
/// FLUJO DETALLADO:
///   1. Widget llama a ref.watch(perfilesProvider) -> se suscribe.
///   2. El provider ejecuta la funcion async de abajo.
///   3. Estado pasa a AsyncLoading -> UI muestra spinner.
///   4. api.getUsuarios() hace GET a /api/usuarios/.
///   5. La respuesta (List<dynamic> de JSON) se mapea a List<Perfil>.
///   6. Estado pasa a AsyncData(perfiles) -> UI muestra la lista.
///   7. Si hay error (sin internet, timeout), estado -> AsyncError.
///
/// Uso:
/// ```dart
///   final perfilesAsync = ref.watch(perfilesProvider);
///   perfilesAsync.when(
///     data: (perfiles) => ListView.builder(
///       itemCount: perfiles.length,
///       itemBuilder: (_, i) => Text(perfiles[i].nombre),
///     ),
///     loading: () => const Center(child: CircularProgressIndicator()),
///     error: (e, _) => Center(child: Text('Error al cargar: $e')),
///   );
/// ```
final perfilesProvider = FutureProvider<List<Perfil>>((ref) async {
  // Obtener el servicio de API desde el provider de autenticacion.
  // Usamos ref.read() (no ref.watch()) porque apiServiceProvider es un
  // Provider simple que no cambia durante la vida de la app.
  final api = ref.read(apiServiceProvider);

  // Llamar al servidor: GET /api/usuarios/
  // Devuelve una lista de Map<String, dynamic> con los datos de cada usuario.
  final data = await api.getUsuarios();

  // Convertir cada JSON (Map) en un objeto Perfil usando fromJson().
  // map() transforma cada elemento, toList() materializa la nueva lista.
  return data.map((e) => Perfil.fromJson(e)).toList();
});
