import 'package:flutter/material.dart';
import '../models/parte_trabajo.dart';
import 'card_parte.dart';

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
