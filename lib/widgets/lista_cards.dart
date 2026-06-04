// =============================================================================
// lista_cards.dart  -  Lista simple de tarjetas de partes
// =============================================================================
// ASPECTO EN PANTALLA:
//   Columna vertical con una [CardParte] por cada parte de trabajo.
//   Cada tarjeta ocupa el ancho completo con margen horizontal.
//
// USO:
//   Renderizar los partes de un dia cuando NO se agrupan por operario
//   (vista plana dentro de DayHeader).
//
// DATOS QUE NECESITA:
//   - partes: List<ParteTrabajo> a mostrar
//
// INTERACCION DEL USUARIO:
//   No tiene interaccion directa. Delega en cada CardParte.
// =============================================================================

/// Lista simple de tarjetas de partes de trabajo.
/// Renderiza una columna con una tarjeta CardParte por cada elemento.
import 'package:flutter/material.dart';
import '../models/parte_trabajo.dart';
import 'card_parte.dart';

/// Lista plana de tarjetas de partes. Sin scroll propio (se usa dentro
/// de Column de DayHeader). [StatelessWidget] porque no tiene estado.
class ListaCards extends StatelessWidget {
  final List<ParteTrabajo> partes;

  const ListaCards({super.key, required this.partes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: partes
          .map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CardParte(parte: p),
            ),
          )
          .toList(),
    );
  }
}
