/// Proveedor de partes de trabajo.
///
/// Obtiene la lista de partes de trabajo desde el servidor.
/// Si no hay conexión, usa los datos guardados en el teléfono
/// para que el usuario pueda ver sus partes sin internet.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parte_trabajo.dart';
import 'auth_provider.dart';

const _cacheKeyPartes = 'cache_partes_lista';

/// Provee la lista de partes de trabajo del usuario.
///
/// Intenta obtener los partes desde el servidor.
/// Si falla la conexión, usa la copia guardada en caché.
final partesProvider = FutureProvider<List<ParteTrabajo>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final prefs = await SharedPreferences.getInstance();

  try {
    final data = await api.getPartes();
    await prefs.setString(_cacheKeyPartes, jsonEncode(data));
    return data.map((e) => ParteTrabajo.fromJson(e)).toList();
  } catch (e) {
    final cache = prefs.getString(_cacheKeyPartes);
    if (cache != null) {
      final List<dynamic> lista = jsonDecode(cache);
      return lista.map((e) => ParteTrabajo.fromJson(e)).toList();
    }
    return [];
  }
});

/// Provee la lista de partes de trabajo del jefe (vista de supervisor).
///
/// Muestra los partes de todos los trabajadores a cargo del jefe.
final partesJefeProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getPartesJefe();
  return data;
});

/// Busca partes de trabajo aplicando filtros.
///
/// - [filtros]: mapa con los filtros a aplicar (obra, operario, especialidad).
/// Retorna una lista de partes que coinciden con los filtros.
final busquedaPartesProvider =
    FutureProvider.family<List<dynamic>, Map<String, String?>>((
      ref,
      filtros,
    ) async {
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
/// Viene del servidor y muestra los días disponibles para trabajar.
final fechasPermitidasProvider = FutureProvider<List<DateTime>>((ref) async {
  try {
    return await ref.read(apiServiceProvider).getMisFechasLibres();
  } catch (_) {
    return [];
  }
});

/// Obtiene un resumen mensual de partes para el jefe.
///
/// - [params.anio]: año del resumen.
/// - [params.mes]: mes del resumen.
/// Retorna un mapa con datos resumidos del mes.
final resumenMensualJefeProvider =
    FutureProvider.family<Map<String, dynamic>, ({int anio, int mes})>((
      ref,
      params,
    ) async {
      final api = ref.read(apiServiceProvider);
      return api.getResumenMensualJefe(params.anio, params.mes);
    });

/// Obtiene el resumen mensual de partes desglosado por cada usuario.
///
/// - [params.anio]: año del resumen.
/// - [params.mes]: mes del resumen.
/// Retorna una lista con el resumen de cada usuario.
final resumenMensualPorUsuarioProvider =
    FutureProvider.family<List<dynamic>, ({int anio, int mes})>((
      ref,
      params,
    ) async {
      final api = ref.read(apiServiceProvider);
      return api.getResumenMensualPorJefe(params.anio, params.mes);
    });
