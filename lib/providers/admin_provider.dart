/// Proveedor de datos de administración.
///
/// Maneja la información de administración del sistema:
/// lista de usuarios, asignaciones a obras, historial de ausencias
/// y días sin parte registrado. Se usa en las pantallas de
/// administración y supervisión.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ausencia_info.dart';
import '../models/obra.dart';
import 'auth_provider.dart';

/// Provee la lista de todos los usuarios registrados en el sistema.
final usuariosProvider = FutureProvider<List<dynamic>>((ref) async {
  return await ref.read(apiServiceProvider).getUsuarios();
});

/// Obtiene las asignaciones de trabajadores para una obra específica.
///
/// - [obraId]: el identificador de la obra.
/// Retorna la lista de trabajadores asignados a esa obra.
final asignacionesObraProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  obraId,
) async {
  return await ref.read(apiServiceProvider).getAsignacionesObra(obraId);
});

/// Provee las obras asignadas al usuario administrador actual.
///
/// Obtiene del servidor las obras y extrae los datos de cada una
/// para mostrarlas en la interfaz del administrador.
final misObrasProvider = FutureProvider<List<Obra>>((ref) async {
  final data = await ref.read(apiServiceProvider).getMisObras();
  return data
      .map((e) => e as Map<String, dynamic>)
      .where((e) => e['obra'] != null)
      .map((e) => Obra.fromJson(e['obra'] as Map<String, dynamic>))
      .toList();
});

/// Obtiene el historial de ausencias de un trabajador.
///
/// - [perfilId]: el identificador del trabajador.
/// Retorna un mapa con las fechas y tipos de ausencia.
final historialAusenciasProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, perfilId) async {
    return ref.read(apiServiceProvider).getHistorialAusencias(perfilId);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// diasSinParteProvider — convertido a AsyncNotifierProvider para poder hacer
// actualizaciones optimistas sin parpadeos ni pantallas en blanco.
// ─────────────────────────────────────────────────────────────────────────────

/// Provee los días sin parte registrado y las ausencias de los trabajadores.
///
/// Combina datos de dos fuentes: los días sin parte y las fechas
/// habilitadas para cada trabajador. Usa un notifier para poder
/// hacer actualizaciones en la interfaz sin recargar la pantalla
/// (actualizaciones optimistas).
final diasSinParteProvider = AsyncNotifierProvider.autoDispose<
    DiasSinParteNotifier, Map<String, AusenciaInfo>>(
  DiasSinParteNotifier.new,
);

/// Controla el estado de los días sin parte y ausencias de los trabajadores.
///
/// Carga los datos desde el servidor y permite eliminar ausencias
/// de forma inmediata en la interfaz (sin esperar al servidor)
/// para que la pantalla no parpadee.
class DiasSinParteNotifier
    extends AutoDisposeAsyncNotifier<Map<String, AusenciaInfo>> {
  @override
  /// Construye el estado inicial cargando los días sin parte y ausencias.
  ///
  /// Hace dos peticiones al servidor al mismo tiempo:
  /// una para los días sin parte y otra para las fechas habilitadas.
  /// Luego combina ambos datos en un mapa de [AusenciaInfo].
  Future<Map<String, AusenciaInfo>> build() async {
    final api = ref.read(apiServiceProvider);

    final results = await Future.wait([
      api.getDiasSinParte(),
      api.getFechaLibreActivos(),
    ]);

    final raw = results[0] as Map<String, dynamic>;
    final fechasHabilitadas = results[1] as Map<String, List<DateTime>>;

    return raw.map((uuid, value) {
      final info = value as Map<String, dynamic>;
      final infoConId = {'perfilId': uuid, ...info};

      final habilitadas = (fechasHabilitadas[uuid] ?? [])
          .map((dt) =>
              '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')}/'
              '${dt.year}')
          .toSet();

      return MapEntry(uuid, AusenciaInfo.fromJson(infoConId, habilitadas));
    });
  }

  /// Elimina una ausencia de la pantalla de forma inmediata, sin esperar al servidor.
  ///
  /// Esto se hace antes de enviar la petición al servidor para que
  /// la interfaz no se quede en blanco ni parpadee mientras se procesa.
  /// Si luego el servidor falla, se revertirá el cambio al recargar.
  /// [ausenciaId] es el identificador de la ausencia a eliminar.
  void eliminarAusenciaLocal(int ausenciaId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = <String, AusenciaInfo>{};

    for (final entry in current.entries) {
      final info = entry.value;
      final nuevasAusencias =
          info.ausenciasActivas.where((a) => a.id != ausenciaId).toList();

      // Solo mantenemos el perfil si aún tiene algo que mostrar
      final tieneContenido = nuevasAusencias.isNotEmpty ||
          info.diasSin.isNotEmpty ||
          info.diasIncompletos.isNotEmpty;

      if (tieneContenido) {
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
    }

    // Actualizamos el estado sin pasar por loading — la UI no parpadea
    state = AsyncData(updated);
  }
}