import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/parte_trabajo.dart';
import '../models/obra.dart';
import 'auth_provider.dart';

final partesProvider = FutureProvider<List<ParteTrabajo>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getPartes();
  return data.map((e) => ParteTrabajo.fromJson(e)).toList();
});

final obrasProvider = FutureProvider<List<Obra>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getObras();
  return data.map((e) => Obra.fromJson(e)).toList();
});

final partesJefeProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getPartesJefe();
  return data;
});

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
