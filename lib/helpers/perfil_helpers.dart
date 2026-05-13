import '../models/perfil.dart';

String normalizarApellido(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

List<Perfil> ordenarPerfiles(List<Perfil> perfiles) =>
    [...perfiles.where((p) => p.activo)]..sort(
      (a, b) => normalizarApellido(
        a.apellidos,
      ).compareTo(normalizarApellido(b.apellidos)),
    );
