import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helpers/tema_constants.dart';
import '../providers/partes_provider.dart';
import '../providers/auth_provider.dart';
import 'lista_partes.dart';
import 'card_parte_jefe.dart';

class PartesNormalesView extends ConsumerWidget {
  final bool agruparPorOperario;

  const PartesNormalesView({super.key, required this.agruparPorOperario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final mostrarResumen =
        perfil?.esOperario == true || perfil?.esEncargado == true;

    return partesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: blue)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: textSecondary)),
      ),
      data: (partes) => ListaPartes(
        partes: partes,
        mostrarResumen: mostrarResumen,
        agruparPorOperario: agruparPorOperario,
      ),
    );
  }
}

class PartesJefeView extends ConsumerWidget {
  const PartesJefeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesJefeProvider);
    return partesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: blue)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: textSecondary)),
      ),
      data: (partes) {
        if (partes.isEmpty) {
          return const Center(
            child: Text(
              'No hay partes registrados',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
          itemCount: partes.length,
          itemBuilder: (context, index) => CardParteJefe(parte: partes[index]),
        );
      },
    );
  }
}
