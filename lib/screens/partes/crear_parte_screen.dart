import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'formulario_parte_jefe.dart';
import 'formulario_parte_normal.dart';
import 'formulario_parte_postventa.dart';

class CrearParteScreen extends ConsumerWidget {
  const CrearParteScreen({
    super.key,
    this.perfilIdPreseleccionado,
    this.nombrePreseleccionado,
    this.fechaPreseleccionada,
  });

  final String? perfilIdPreseleccionado;
  final String? nombrePreseleccionado;
  final DateTime? fechaPreseleccionada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (perfil.esJefeObra) {
      return const FormularioParteJefe();
    }
    if (perfil.postventa) {
      return FormularioPostVenta(
        perfilIdPreseleccionado: perfilIdPreseleccionado,
        nombrePreseleccionado: nombrePreseleccionado,
        fechaPreseleccionada: fechaPreseleccionada,
      );
    }
    return FormularioParteNormal(
      perfilIdPreseleccionado: perfilIdPreseleccionado,
      nombrePreseleccionado: nombrePreseleccionado,
      fechaPreseleccionada: fechaPreseleccionada,
    );
  }
}
