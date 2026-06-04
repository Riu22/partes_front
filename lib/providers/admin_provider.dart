/// =============================================================================
/// PROVEEDOR DE DATOS DE ADMINISTRACION (admin_provider.dart)
/// =============================================================================
///
/// QUE ES UN PROVIDER (Riverpod)?
/// -----------------------------------------------------------------------------
/// Un Provider es como un altavoz central. Gestiona datos (estado) y notifica
/// automaticamente a todas las pantallas que estan escuchando. Cuando el dato
/// cambia, las pantallas se actualizan solas.
///
/// CONCEPTOS FUNDAMENTALES DE RIVERPOD:
///
///   ref.watch(provider)
///     Suscribe al widget al provider. Se reconstruye cuando cambia.
///
///   ref.read(provider)
///     Lee el valor una vez sin suscribirse.
///
///   ref.invalidate(provider)
///     Marca provider como desactualizado. Se recargara al acceder.
///
///   .valueOrNull (AsyncValue.valueOrNull)
///     Obtiene el valor actual, o null si loading/error.
///     Util para actualizaciones optimistas en notifiers.
///
///   FutureProvider<T>
///     Provider asincrono que se ejecuta una vez. Ideal para APIs.
///
///   FutureProvider.family<T, Arg>
///     Provider asincrono que acepta un argumento. Cada combinacion
///     de argumento crea un provider independiente.
///
///   AsyncNotifierProvider.autoDispose
///     Variante de AsyncNotifier que se auto-destruye cuando no tiene
///     oyentes. Ahorra memoria. El notifier extiende
///     AutoDisposeAsyncNotifier en lugar de AsyncNotifier.
///
///   AsyncValue<T>
///     Envuelve un valor asincrono con tres estados:
///     - AsyncLoading: cargando.
///     - AsyncData(T): datos exitosos.
///     - AsyncError: error.
///
/// ACTUALIZACIONES OPTIMISTAS:
///   Es una tecnica donde la UI se actualiza INMEDIATAMENTE antes de
///   esperar la confirmacion del servidor. Si el servidor falla, el
///   cambio se revierte al recargar los datos.
///
///   En este archivo, eliminarAusenciaLocal() aplica actualizacion
///   optimista: elimina la ausencia de la UI inmediatamente sin
///   esperar al servidor. Esto evita pantallas en blanco o
///   parpadeos (efecto "flash") al recargar todo el provider.
///
/// OFFLINE / ONLINE:
///   La mayoria de providers aqui SOLO funcionan online (no tienen
///   cache local). El modulo de administracion requiere datos
///   actualizados del servidor.
///
///   La excepcion es diasSinParteProvider que usa AsyncNotifier para
///   mantener el estado en memoria y permitir actualizaciones
///   optimistas sin recargar del servidor constantemente.
///
/// QUE HACE ESTE ARCHIVO:
///   1. usuariosProvider: lista de todos los usuarios del sistema.
///   2. asignacionesObraProvider: trabajadores asignados a una obra.
///   3. misObrasProvider: obras del administrador actual.
///   4. historialAusenciasProvider: ausencias de un trabajador.
///   5. diasSinParteProvider: dias sin parte + ausencias combinados,
///      con capacidad de eliminacion optimista.
/// =============================================================================

/// Proveedor de datos de administracion.
///
/// Maneja la informacion de administracion del sistema:
/// lista de usuarios, asignaciones a obras, historial de ausencias
/// y dias sin parte registrado. Se usa en las pantallas de
/// administracion y supervision.
import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod: gestion de estado con providers, ref, AsyncNotifier, etc.

import '../models/ausencia_info.dart';
// AusenciaInfo: modelo que combina los dias sin parte de un trabajador
// con sus ausencias activas y fechas habilitadas.

import '../models/obra.dart';
// Obra: modelo de obra de construccion.

import 'auth_provider.dart';
// auth_provider: necesario para acceder a apiServiceProvider.

/// Provee la lista de todos los usuarios registrados en el sistema.
///
/// Es un FutureProvider simple: llama a la API y devuelve los datos.
/// No tiene cache offline porque la lista de usuarios se usa en
/// pantallas de administracion que requieren datos actualizados.
///
/// Retorna List<dynamic> (datos sin transformar de la API).
final usuariosProvider = FutureProvider<List<dynamic>>((ref) async {
  // Llamar a GET /api/usuarios/.
  return await ref.read(apiServiceProvider).getUsuarios();
});

/// Obtiene las asignaciones de trabajadores para una obra especifica.
///
/// Es un FutureProvider.family: recibe el ID de la obra como argumento
/// y devuelve la lista de trabajadores asignados.
///
/// Parametros:
///   - [obraId]: el identificador unico de la obra.
///
/// Uso:
///   ref.watch(asignacionesObraProvider(obraId));
final asignacionesObraProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  obraId,
) async {
  // Llamar a GET /api/obras/:id/asignaciones/ (o similar).
  return await ref.read(apiServiceProvider).getAsignacionesObra(obraId);
});

/// Provee las obras asignadas al usuario administrador actual.
///
/// Obtiene del servidor las obras donde el administrador tiene
/// asignaciones (es responsable o supervisor).
///
/// A diferencia de las asignaciones normales, este provider EXTRAE
/// los datos de la obra desde la respuesta JSON. La API devuelve
/// la obra anidada dentro de un campo 'obra'.
///
/// FLUJO:
///   1. Llamar a GET /api/mis-obras/.
///   2. Cada elemento debe tener un campo 'obra' (mapa).
///   3. Filtrar elementos que no tengan obra (where).
///   4. Convertir cada mapa de obra a objeto Obra (fromJson).
final misObrasProvider = FutureProvider<List<Obra>>((ref) async {
  final data = await ref.read(apiServiceProvider).getMisObras();
  return data
      // Asegurar que cada elemento es un Map<String, dynamic>.
      .map((e) => e as Map<String, dynamic>)
      // Filtrar los que no tienen obra asociada (null safety).
      .where((e) => e['obra'] != null)
      // Convertir el mapa de obra a un objeto Obra.
      .map((e) => Obra.fromJson(e['obra'] as Map<String, dynamic>))
      .toList();
});

/// Obtiene el historial de ausencias de un trabajador.
///
/// Es un FutureProvider.family: recibe el ID del perfil como argumento.
///
/// Parametros:
///   - [perfilId]: el identificador del trabajador (String).
///
/// Retorna un mapa con las fechas y tipos de ausencia del trabajador.
final historialAusenciasProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, perfilId) async {
    // Llamar a GET /api/usuarios/:id/ausencias/.
    return ref.read(apiServiceProvider).getHistorialAusencias(perfilId);
  },
);

// ===========================================================================
// diasSinParteProvider — convertido a AsyncNotifierProvider para
// actualizaciones optimistas sin parpadeos ni pantallas en blanco.
// ===========================================================================
//
// Por que AsyncNotifier en lugar de FutureProvider?
//   FutureProvider solo permite cargar datos una vez. Para actualizar
//   la UI sin recargar todo (ej. eliminar una ausencia), necesitamos
//   un notifier que pueda modificar el estado directamente.
//
// AutoDispose:
//   .autoDispose hace que el provider se destruya automaticamente
//   cuando ninguna pantalla lo esta escuchando. Ahorra memoria.
//   DiasSinParteNotifier extiende AutoDisposeAsyncNotifier.
//
// Actualizacion optimista:
//   eliminarAusenciaLocal() modifica el estado INMEDIATAMENTE sin
//   esperar al servidor. La UI se actualiza al instante.
//   Si el servidor falla, el cambio se revertira al recargar.
// ===========================================================================

/// Provee los dias sin parte registrado y las ausencias de los trabajadores.
///
/// Combina datos de dos fuentes del servidor:
///   1. Dias sin parte (getDiasSinParte).
///   2. Fechas habilitadas para cada trabajador (getFechaLibreActivos).
///
/// Usa AsyncNotifierProvider.autoDispose para permitir actualizaciones
/// optimistas (eliminar ausencias sin esperar al servidor).
///
/// Tipo de dato: Map<String, AusenciaInfo>
///   - Key: UUID del perfil del trabajador.
///   - Value: AusenciaInfo con los datos combinados.
final diasSinParteProvider = AsyncNotifierProvider.autoDispose<
    DiasSinParteNotifier, Map<String, AusenciaInfo>>(
  DiasSinParteNotifier.new,
);

/// Controla el estado de los dias sin parte y ausencias de los trabajadores.
///
/// Carga los datos desde el servidor en build() y permite eliminar
/// ausencias de forma optimista (inmediata, sin esperar al servidor).
///
/// AutoDisposeAsyncNotifier significa que:
///   - Se auto-destruye cuando no hay oyentes (ahorra memoria).
///   - El estado es Map<String, AusenciaInfo>.
///   - build() se ejecuta al crear y retorna el estado inicial.
class DiasSinParteNotifier
    extends AutoDisposeAsyncNotifier<Map<String, AusenciaInfo>> {
  @override
  /// Construye el estado inicial cargando los dias sin parte y ausencias.
  ///
  /// Hace dos peticiones al servidor EN PARALELO usando Future.wait:
  ///   1. GET /api/dias-sin-parte/ -> mapa de perfiles con sus datos.
  ///   2. GET /api/fechas-libres-activos/ -> mapa de perfiles con fechas.
  ///
  /// Luego COMBINA ambos resultados en un solo mapa de AusenciaInfo.
  ///
  /// Future.wait ejecuta todas las futures simultaneamente y espera
  /// a que TODAS terminen. Es mas rapido que hacerlas secuencialmente.
  Future<Map<String, AusenciaInfo>> build() async {
    final api = ref.read(apiServiceProvider);

    // Ejecutar dos peticiones en paralelo para optimizar tiempo.
    final results = await Future.wait([
      api.getDiasSinParte(),      // Resultado 0: raw (dias sin parte)
      api.getFechaLibreActivos(), // Resultado 1: fechas habilitadas
    ]);

    // Desempaquetar resultados.
    // raw: Map<String, dynamic> donde cada key es UUID de perfil y
    // value es un mapa con diasSin, ausencias, etc.
    final raw = results[0] as Map<String, dynamic>;

    // fechasHabilitadas: Map<String, List<DateTime>> donde cada key
    // es UUID de perfil y value es la lista de fechas habilitadas.
    final fechasHabilitadas = results[1] as Map<String, List<DateTime>>;

    // Combinar ambos mapas en uno solo de AusenciaInfo.
    return raw.map((uuid, value) {
      // value es un Map con los datos del perfil (dias sin, ausencias, etc.).
      final info = value as Map<String, dynamic>;
      // Agregar el ID del perfil al mapa de datos.
      final infoConId = {'perfilId': uuid, ...info};

      // Obtener las fechas habilitadas para este perfil (o lista vacia).
      // Convertir cada DateTime a String con formato dd/MM/yyyy.
      final habilitadas = (fechasHabilitadas[uuid] ?? [])
          .map((dt) =>
              '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')}/'
              '${dt.year}')
          .toSet(); // Usar Set para evitar duplicados.

      // Crear AusenciaInfo combinando ambos datos.
      return MapEntry(uuid, AusenciaInfo.fromJson(infoConId, habilitadas));
    });
  }

  /// Elimina una ausencia de la pantalla de forma inmediata (actualizacion optimista).
  ///
  /// Esta operacion se ejecuta en la UI antes de enviar la peticion
  /// al servidor. La ausencia desaparece al instante de la pantalla,
  /// evitando el parpadeo (flash) de una recarga completa.
  ///
  /// [ausenciaId] es el identificador de la ausencia a eliminar.
  ///
  /// Si el servidor falla, el cambio se revertira la proxima vez
  /// que build() se ejecute (al recargar el provider).
  ///
  /// FLUJO:
  ///   1. Obtener el estado actual con valueOrNull.
  ///   2. Si no hay datos (null), salir.
  ///   3. Recorrer todos los perfiles en el mapa.
  ///   4. Para cada perfil, filtrar las ausencias excluyendo la eliminada.
  ///   5. Si el perfil se queda sin datos, eliminarlo del mapa.
  ///   6. Actualizar el estado con AsyncData(updated) -> UI se actualiza.
  void eliminarAusenciaLocal(int ausenciaId) {
    // Obtener el estado actual. valueOrNull devuelve null si el estado
    // esta cargando o tiene error (en esos casos no podemos modificar).
    final current = state.valueOrNull;
    if (current == null) return;

    // Mapa resultado: solo perfiles que tengan datos despues de eliminar.
    final updated = <String, AusenciaInfo>{};

    // Recorrer cada entrada del mapa actual.
    for (final entry in current.entries) {
      final info = entry.value;

      // Filtrar las ausencias activas: excluir la que queremos eliminar.
      final nuevasAusencias =
          info.ausenciasActivas.where((a) => a.id != ausenciaId).toList();

      // Verificar si el perfil aun tiene contenido que mostrar.
      // Si despues de eliminar la ausencia solo quedan datos vacios,
      // eliminamos el perfil del mapa completamente.
      final tieneContenido = nuevasAusencias.isNotEmpty ||
          info.diasSin.isNotEmpty ||
          info.diasIncompletos.isNotEmpty;

      if (tieneContenido) {
        // El perfil aun tiene datos: mantenerlo en el mapa actualizado.
        updated[entry.key] = AusenciaInfo(
          perfilId: info.perfilId,
          nombre: info.nombre,
          diasSin: info.diasSin,
          diasIncompletos: info.diasIncompletos,
          ausenciasActivas: nuevasAusencias,
          totalLaborables: info.totalLaborables,
          fechasHabilitadas: info.fechasHabilitadas,
        );
      }
      // Si no tiene contenido, simplemente no lo agregamos al nuevo mapa.
      // Esto elimina el perfil de la vista.
    }

    // Actualizar el estado directamente con AsyncData.
    // Importante: NO pasamos por AsyncLoading, por eso la UI
    // no parpadea ni muestra pantallas en blanco.
    state = AsyncData(updated);
  }
}
