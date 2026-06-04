/// =============================================================================
/// PROVEEDOR DE OBRAS (obras_provider.dart)
/// =============================================================================
///
/// QUE ES UN PROVIDER (Riverpod)?
/// -----------------------------------------------------------------------------
/// Un Provider es como un altavoz central. Gestiona datos (estado) y notifica
/// automaticamente a todas las pantallas que estan escuchando. Cuando el dato
/// cambia, las pantallas se actualizan solas.
///
/// Imagina un altavoz en una fabrica:
///   - El altavoz (Provider) tiene la informacion (ej. lista de obras).
///   - Los trabajadores (Widgets) escuchan el altavoz.
///   - Cuando la informacion cambia, todos se actualizan al instante.
///
/// CONCEPTOS FUNDAMENTALES DE RIVERPOD:
///
///   ref.watch(provider)
///     Suscribe al widget al provider. El widget se reconstruye cuando
///     el provider cambia. Es la forma principal de conectar UI con datos.
///
///   ref.read(provider)
///     Lee el valor una sola vez sin suscribirse. No causa reconstruccion.
///
///   ref.invalidate(provider)
///     Marca al provider como desactualizado. Se recargara la proxima vez
///     que alguien lo use. Sirve para refrescar datos.
///
///   ref.watch(provider.future)
///     Espera a que el provider termine de cargar y devuelve el valor.
///     Util para obtener datos en el build de otro provider.
///     Ejemplo: await ref.watch(authProvider.future)
///
///   .future (AsyncValue.future)
///     Obtiene el Future del provider. Sirve para esperar datos en codigo.
///
///   .valueOrNull (AsyncValue.valueOrNull)
///     Obtiene el valor actual o null si esta cargando o en error.
///
///   .when() (AsyncValue.when)
///     Renderiza segun el estado: data, loading, error.
///     Forma RECOMENDADA de consumir providers en la UI.
///
///   FutureProvider<T>
///     Ejecuta una funcion async UNA VEZ al ser usado por primera vez.
///     Ideal para llamadas a la API. Estado: AsyncLoading, AsyncData,
///     AsyncError.
///
///   keepAlive()
///     Metodo de Ref que evita que el provider sea destruido aunque no
///     tenga oyentes. Sirve para mantener datos cacheados en memoria
///     aunque ninguna pantalla los este viendo en ese momento.
///     Ejemplo: ref.keepAlive() al inicio del build del provider.
///
/// OFFLINE / ONLINE:
///   - Con internet: llama a la API, guarda respuesta en cache local.
///   - Sin internet: usa los datos de cache local (SharedPreferences).
///   - Si no hay cache ni conexion: devuelve lista vacia.
///   - keepAlive() mantiene los datos en memoria aunque el usuario
///     navegue a otras pantallas y vuelva, evitando recargas innecesarias.
///
/// QUE HACE ESTE ARCHIVO:
///   Obtiene y expone las obras de construccion del sistema:
///   1. obrasProvider:          lista completa de obras.
///   2. obrasActivasProvider:   solo obras en estado activo.
///   3. misAsignacionesProvider: obras asignadas al usuario actual.
/// =============================================================================

/// Proveedor de obras.
///
/// Obtiene la lista de obras desde el servidor.
/// Si falla la conexion, usa los datos guardados en el telefono
/// (cache) para mostrar las obras sin necesidad de internet.
import 'dart:convert';
// dart:convert: proporciona jsonEncode y jsonDecode para la cache local.

import 'package:shared_preferences/shared_preferences.dart';
// shared_preferences: almacenamiento local clave-valor en el telefono.
// Se usa para guardar las obras en cache y poder verlas sin internet.

import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod: gestion de estado con providers, ref, AsyncValue, etc.

import '../models/obra.dart';
// Modelo Obra: representa una obra de construccion con todos sus campos.

import 'auth_provider.dart';
// auth_provider: necesario para acceder a apiServiceProvider y al perfil.

/// Provee la lista completa de obras.
///
/// Carga las obras desde el servidor (GET /api/obras/).
/// Si falla la conexion, usa la copia guardada en cache local.
/// Si no hay cache ni conexion, devuelve lista vacia.
///
/// Usa ref.keepAlive() para que los datos no se destruyan al navegar
/// entre pantallas. Si el usuario ya cargo las obras una vez, al volver
/// a la pantalla de obras los datos estan disponibles inmediatamente.
///
/// Tambien depende del perfil del usuario: si no hay sesion activa
/// (perfil == null), devuelve lista vacia directamente.
///
/// Uso:
///   final obrasAsync = ref.watch(obrasProvider);
///   obrasAsync.when(
///     data: (obras) => ListView(...),
///     loading: () => CircularProgressIndicator(),
///     error: (e, _) => Text('Error: $e'),
///   );
final obrasProvider = FutureProvider<List<Obra>>((ref) async {
  // Evitar que el provider sea eliminado aunque no tenga oyentes.
  // Esto mantiene los datos cacheados en memoria RAM para acceso rapido.
  ref.keepAlive();

  // Esperar a que el perfil del usuario este cargado.
  // ref.watch(authProvider.future) devuelve el Future del perfil.
  // Si no hay sesion activa (perfil == null), no tiene sentido cargar obras.
  final perfil = await ref.watch(authProvider.future);
  if (perfil == null) return [];

  // Obtener el servicio de API principal.
  final api = ref.read(apiServiceProvider);

  // Obtener acceso al almacenamiento local del telefono.
  final prefs = await SharedPreferences.getInstance();
  const cacheKey = 'cache_obras_lista';

  try {
    // Intentar obtener las obras desde el servidor (GET /api/obras/).
    final data = await api.getObras();

    // Guardar las obras en cache local para uso offline futuro.
    // jsonEncode convierte la lista de Map a String JSON.
    await prefs.setString(cacheKey, jsonEncode(data));

    // Convertir cada JSON (Map<String, dynamic>) a un objeto Obra.
    return data.map((e) => Obra.fromJson(e)).toList();
  } catch (e) {
    // Fallo la conexion al servidor. Intentar leer cache local.
    final cacheGuardada = prefs.getString(cacheKey);
    if (cacheGuardada != null) {
      // Hay datos cacheados: decodificar y convertir a objetos Obra.
      final List<dynamic> lista = jsonDecode(cacheGuardada);
      return lista.map((e) => Obra.fromJson(e)).toList();
    }

    // No hay cache ni conexion: devolver lista vacia.
    return [];
  }
});

/// Provee solo las obras que estan activas actualmente.
///
/// Similar a [obrasProvider] pero filtra las obras que estan en estado
/// activo (en progreso, no finalizadas ni canceladas).
/// Tambien tiene cache local y keepAlive() para rendimiento.
///
/// Uso tipico:
///   Mostrar solo las obras activas en las que el usuario puede
///   registrar partes de trabajo.
final obrasActivasProvider = FutureProvider<List<Obra>>((ref) async {
  // Mantener en memoria aunque no haya oyentes activos.
  ref.keepAlive();

  // Depende del perfil del usuario: sin sesion no hay obras.
  final perfil = await ref.watch(authProvider.future);
  if (perfil == null) return [];

  // Obtener servicios y almacenamiento local.
  final api = ref.read(apiServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  const cacheKey = 'cache_obras_activas';

  try {
    // Intentar obtener obras activas desde el servidor.
    final data = await api.getObrasActivas();

    // Guardar en cache local.
    await prefs.setString(cacheKey, jsonEncode(data));

    // Convertir JSON a objetos Obra.
    return data.map((e) => Obra.fromJson(e)).toList();
  } catch (e) {
    // Fallback a cache local si falla la conexion.
    final cacheGuardada = prefs.getString(cacheKey);
    if (cacheGuardada != null) {
      final List<dynamic> lista = jsonDecode(cacheGuardada);
      return lista.map((e) => Obra.fromJson(e)).toList();
    }
    return [];
  }
});

/// Provee las obras asignadas al usuario actual.
///
/// Obtiene del servidor las obras donde el usuario esta asignado
/// como trabajador. A diferencia de los providers anteriores, este
/// NO tiene cache local ni keepAlive() porque las asignaciones
/// cambian con frecuencia y siempre requieren datos frescos.
///
/// Retorna List<dynamic> (no usa Obra.fromJson) porque el formato
/// de asignaciones puede incluir datos adicionales (fecha de
/// asignacion, rol, etc.) que no estan en el modelo Obra.
final misAsignacionesProvider = FutureProvider<List<dynamic>>((ref) async {
  // Llamar a GET /api/mis-obras/ del servidor.
  return await ref.read(apiServiceProvider).getMisObras();
});
