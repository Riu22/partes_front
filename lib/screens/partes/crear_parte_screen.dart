// =============================================================================
// PANTALLA: CrearParteScreen
// -----------------------------------------------------------------------------
// QUE ES: Enrutador que redirige al formulario correcto segun el rol.
// PARA QUE SIRVE: Decide si mostrar formulario de jefe, postventa o normal.
// QUIEN LA VE (rol): Todos los roles, pero cada uno ve un formulario distinto.
// COMO SE LLEGA: Desde el FAB de PartesScreen o desde admin_home.
// A DONDE VA DESPUES: Al formulario correspondiente.
// QUE DATOS NECESITA: Perfil del usuario, opcionalmente perfilId y fecha.
// OFFLINE: N/A, es solo un enrutador.
// =============================================================================

/// Pantalla que actua como enrutador para crear un nuevo parte.
/// Segun el rol del usuario y si es postventa, redirige al formulario
/// correspondiente: jefe de obra, postventa o normal.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'formulario_parte_jefe.dart';
import 'formulario_parte_normal.dart';
import 'formulario_parte_postventa.dart';

/// Redirige al formulario adecuado segun el rol:
/// - Jefe de obra -> FormularioParteJefe
/// - Postventa -> FormularioPostVenta
/// - Otros -> FormularioParteNormal
///
/// Flutter concept: ConsumerWidget sin estado que decide que widget
/// mostrar basandose en el estado del provider de autenticacion.
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

    // Logica de seleccion de formulario segun el rol
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
