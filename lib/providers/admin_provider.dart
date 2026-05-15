import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ausencia_info.dart';
import 'auth_provider.dart';

final usuariosProvider = FutureProvider<List<dynamic>>((ref) async {
  return await ref.read(apiServiceProvider).getUsuarios();
});

final asignacionesObraProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  obraId,
) async {
  return await ref.read(apiServiceProvider).getAsignacionesObra(obraId);
});
final misObrasProvider = FutureProvider<List<dynamic>>((ref) async {
  return await ref.read(apiServiceProvider).getMisObras();
});

// Convierte el mapa crudo del API a un Map<String, AusenciaInfo> tipado.
// Cada entrada contiene: días sin parte, días con horas incompletas y total laborables.
final diasSinParteProvider =
    FutureProvider.autoDispose<Map<String, AusenciaInfo>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final raw = await api.getDiasSinParte();

  return raw.map((uuid, value) {
    final info = value as Map<String, dynamic>;

    final diasSin = (info['diasSin'] as List)
        .map((e) => e.toString())
        .toList();

    final diasIncompletos = (info['diasIncompletos'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      return DiaIncompleto(
        fecha: m['fecha'] as String,
        horas: m['horas'] as String,
      );
    }).toList();

    return MapEntry(
      uuid,
      AusenciaInfo(
        perfilId: uuid,
        nombre: info['nombre'] as String,
        diasSin: diasSin,
        diasIncompletos: diasIncompletos,
        totalLaborables: info['totalLaborables'] as int,
      ),
    );
  });
});
