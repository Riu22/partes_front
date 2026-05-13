import 'package:flutter/foundation.dart';

enum ModoExport { zip, pdf, zipOperario }

@immutable
class PdfParams {
  final DateTime desde;
  final DateTime hasta;
  final List<int> obraIds;
  final List<String> perfilIds;
  final ModoExport modo;

  const PdfParams({
    required this.desde,
    required this.hasta,
    required this.obraIds,
    required this.perfilIds,
    required this.modo,
  });

  @override
  bool operator ==(Object other) =>
      other is PdfParams &&
      desde == other.desde &&
      hasta == other.hasta &&
      listEquals(obraIds, other.obraIds) &&
      listEquals(perfilIds, other.perfilIds) &&
      modo == other.modo;

  @override
  int get hashCode =>
      Object.hash(desde, hasta, Object.hashAll(obraIds), Object.hashAll(perfilIds), modo);
}
