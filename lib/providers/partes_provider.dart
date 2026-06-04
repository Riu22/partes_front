/// =============================================================================
/// PROVEEDOR DE PARTES DE TRABAJO (partes_provider.dart)
/// =============================================================================
///
/// QUE ES UN PROVIDER (Riverpod)?
/// -----------------------------------------------------------------------------
/// Un Provider es como un altavoz central. Gestiona datos (estado) y notifica
/// automaticamente a todas las pantallas que estan escuchando. Cuando el dato
/// cambia, las pantallas se actualizan solas.
///
/// Imagina un altavoz en una fabrica:
///   - El altavoz (Provider) tiene informacion (ej. lista de partes).
///   - Los trabajadores (Widgets) escuchan el altavoz.
///   - Cuando la informacion cambia, todos se actualizan al instante.
///
/// CONCEPTOS FUNDAMENTALES DE RIVERPOD:
///
///   ref.watch(provider)
///     Suscribe al widget al provider. El widget se reconstruye cuando el
///     provider cambia. Es la forma principal de conectar UI con datos.
///
///   ref.read(provider)
///     Lee el valor una sola vez sin suscribirse. No causa reconstruccion.
///
///   ref.invalidate(provider)
///     Marca al provider como desactualizado. Se recargara la proxima vez
///     que alguien lo use con ref.watch(). Sirve para refrescar datos
///     despues de crear o modificar un parte.
///
///   .future (AsyncValue.future)
///     Obtiene el Future del provider. Sirve para esperar datos en codigo.
///
///   .valueOrNull (AsyncValue.valueOrNull)
///     Obtiene el valor actual o null si esta cargando/en error.
///
///   .when() (AsyncValue.when)
///     Renderiza segun el estado: data, loading, error.
///     Forma RECOMENDADA de consumir providers en la UI.
///
///   FutureProvider<T>
///     Ejecuta una funcion async UNA VEZ. Ideal para llamadas a la API.
///     Estado: AsyncLoading, AsyncData, AsyncError.
///
///   FutureProvider.family<T, Arg>
///     Variante de FutureProvider que acepta un argumento (family).
///     Cada combinacion de argumento crea un provider independiente.
///     Ej: FutureProvider.family<List<dynamic>, int> para cargar
///     datos de un usuario especifico segun su ID.
///
///   keepAlive()
///     Evita que el provider sea destruido aunque no tenga oyentes.
///     Sirve para mantener datos cacheados en memoria.
///
/// OFFLINE / ONLINE:
///   - Con internet: llama a la API, guarda respuesta en cache local.
///   - Sin internet: usa los datos de cache local (SharedPreferences).
///   - Si no hay cache ni conexion: devuelve lista vacia.
///   - Los partes CREADOS sin internet se guardan en una cola offline
///     (OfflineQueueService) y se envian al servidor cuando se
///     recupera la conexion (syncProvider se encarga de eso).
///
/// QUE HACE ESTE ARCHIVO:
///   Obtiene y expone los partes de trabajo del usuario desde el servidor.
///   Incluye:
///   1. partesProvider:       lista de partes del usuario actual.
///   2. partesJefeProvider:   lista de partes del jefe (vista supervisor).
///   3. busquedaPartesProvider: busqueda con filtros (obra, operario, etc.).
///   4. fechasPermitidasProvider: fechas en que se puede registrar trabajo.
///   5. resumenMensualJefeProvider: resumen mensual para el jefe.
///   6. resumenMensualPorUsuarioProvider: resumen desglosado por usuario.
/// =============================================================================

/// Proveedor de partes de trabajo.
///
/// Obtiene la lista de partes de trabajo desde el servidor.
/// Si no hay conexion, usa los datos guardados en el telefono
/// para que el usuario pueda ver sus partes sin internet.
import 'dart:convert';
// dart:convert: proporciona jsonEncode y jsonDecode para manejar caché local.

import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod: gestion de estado con providers, ref, AsyncValue, etc.

import 'package:shared_preferences/shared_preferences.dart';
// shared_preferences: almacenamiento local simple (clave-valor) en el telefono.
// Se usa para guardar la cache de partes y poder verlos sin internet.

import '../models/parte_trabajo.dart';
// Modelo ParteTrabajo: representa un parte de trabajo con todos sus campos.

import 'auth_provider.dart';
// auth_provider: necesario para acceder a apiServiceProvider.

// Clave usada en SharedPreferences para guardar la cache de partes.
// El prefijo 'cache_' identifica que es un dato de respaldo offline.
const _cacheKeyPartes = 'cache_partes_lista';

/// Provee la lista de partes de trabajo del usuario actual.
///
/// Es un FutureProvider que:
///   1. Intenta cargar los partes desde el servidor (API).
///   2. Si falla, usa la copia guardada en cache local.
///   3. Si no hay cache ni conexion, devuelve lista vacia.
///
/// Uso desde una pantalla:
/// ```dart
///   final partesAsync = ref.watch(partesProvider);
///   partesAsync.when(
///     data: (partes) => ListView.builder(
///       itemCount: partes.length,
///       itemBuilder: (_, i) => ParteCard(partes[i]),
///     ),
///     loading: () => const Center(child: CircularProgressIndicator()),
///     error: (e, _) => Text('Error: $e'),
///   );
/// ```
///
/// FLUJO DETALLADO:
///   1. Obtener el servicio de API (ref.read(apiServiceProvider)).
///   2. Obtener SharedPreferences para leer/escribir cache.
///   3. Intentar GET a /api/partes/.
///   4. Si EXITO: guardar en cache y convertir JSON a modelos.
///   5. Si FALLA: leer cache guardado previamente.
///   6. Si HAY CACHE: devolver datos cacheados.
///   7. Si NO HAY CACHE: devolver lista vacia.
final partesProvider = FutureProvider<List<ParteTrabajo>>((ref) async {
  // Obtener el servicio de API principal (con token de autenticacion).
  final api = ref.read(apiServiceProvider);

  // Obtener el almacenamiento local del telefono.
  final prefs = await SharedPreferences.getInstance();

  try {
    // Intentar obtener los partes desde el servidor (GET /api/partes/).
    final data = await api.getPartes();

    // Guardar en cache local para uso offline futuro.
    // jsonEncode convierte la lista de Maps a un String JSON.
    await prefs.setString(_cacheKeyPartes, jsonEncode(data));

    // Convertir cada elemento JSON a un objeto ParteTrabajo.
    return data.map((e) => ParteTrabajo.fromJson(e)).toList();
  } catch (e) {
    // Fallo la conexion al servidor. Intentar leer cache local.
    final cache = prefs.getString(_cacheKeyPartes);
    if (cache != null) {
      // Hay datos cacheados: convertirlos de vuelta a objetos.
      final List<dynamic> lista = jsonDecode(cache);
      return lista.map((e) => ParteTrabajo.fromJson(e)).toList();
    }

    // No hay cache ni conexion: devolver lista vacia.
    return [];
  }
});

/// Provee la lista de partes de trabajo del jefe (vista de supervisor).
///
/// Muestra los partes de todos los trabajadores a cargo del jefe.
/// A diferencia de partesProvider, este NO tiene cache offline porque
/// los datos del jefe cambian constantemente y siempre requieren
/// conexion para ser utiles.
///
/// Retorna List<dynamic> (no usa ParteTrabajo.fromJson) porque el
/// formato de datos del jefe puede ser diferente al del trabajador.
final partesJefeProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  // Llamar a GET /api/partes/jefe/ del servidor.
  final data = await api.getPartesJefe();
  return data;
});

/// Busca partes de trabajo aplicando filtros.
///
/// Parametros:
///   - [filtros]: mapa con los filtros a aplicar.
///     Claves posibles: 'obra', 'operario', 'especialidad'.
///     Valores: String con el valor del filtro, o null si no se filtra.
///
/// Es un FutureProvider.family: cada combinacion unica de filtros crea
/// su propio provider independiente. Asi la cache de Riverpod funciona
/// por separado para cada busqueda.
///
/// Uso:
///   ref.watch(busquedaPartesProvider({'obra': '123', 'operario': null}));
final busquedaPartesProvider =
    FutureProvider.family<List<dynamic>, Map<String, String?>>((
      ref,
      filtros,
    ) async {
      // Extraer cada filtro del mapa. Si no existe la clave, se pasa null.
      // Esto permite llamar a la API solo con los filtros que tiene valor.
      return await ref
          .read(apiServiceProvider)
          .buscarPartes(
            obra: filtros['obra'],
            operario: filtros['operario'],
            especialidad: filtros['especialidad'],
          );
    });

/// Obtiene las fechas en las que el usuario puede registrar partes.
///
/// Viene del servidor y muestra los dias disponibles para trabajar.
/// Si falla la conexion, devuelve lista vacia para no bloquear la UI.
///
/// Uso:
///   final fechasAsync = ref.watch(fechasPermitidasProvider);
final fechasPermitidasProvider = FutureProvider<List<DateTime>>((ref) async {
  try {
    // Llamar a GET /api/mis-fechas-libres/ del servidor.
    return await ref.read(apiServiceProvider).getMisFechasLibres();
  } catch (_) {
    // Error de conexion: devolver lista vacia.
    // La UI mostrara "no hay fechas disponibles" en lugar de romperse.
    return [];
  }
});

/// Obtiene un resumen mensual de partes para el jefe.
///
/// Parametros:
///   - [params.anio]: el ano del resumen (ej. 2025).
///   - [params.mes]: el mes del resumen (1-12).
///
/// Retorna un mapa con datos resumidos del mes (totales, horas, etc.).
///
/// Es un FutureProvider.family que usa un record como argumento.
/// ({int anio, int mes}) es un record de Dart 3 con campos nombrados.
final resumenMensualJefeProvider =
    FutureProvider.family<Map<String, dynamic>, ({int anio, int mes})>((
      ref,
      params,
    ) async {
      final api = ref.read(apiServiceProvider);
      // Llamar a GET /api/resumen-mensual-jefe/?anio=X&mes=Y
      return api.getResumenMensualJefe(params.anio, params.mes);
    });

/// Obtiene el resumen mensual de partes desglosado por cada usuario.
///
/// Similar a resumenMensualJefeProvider pero devuelve una lista con
/// el desglose individual de cada trabajador a cargo del jefe.
///
/// Parametros:
///   - [params.anio]: el ano del resumen.
///   - [params.mes]: el mes del resumen.
///
/// Retorna una lista de mapas, cada uno con el resumen de un usuario.
final resumenMensualPorUsuarioProvider =
    FutureProvider.family<List<dynamic>, ({int anio, int mes})>((
      ref,
      params,
    ) async {
      final api = ref.read(apiServiceProvider);
      // Llamar a GET /api/resumen-mensual-por-jefe/?anio=X&mes=Y
      return api.getResumenMensualPorJefe(params.anio, params.mes);
    });
