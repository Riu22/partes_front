/// Funciones para ordenar y filtrar perfiles de trabajadores.
/// Ayudan a mostrar la lista de operarios en orden alfabético correcto,
/// teniendo en cuenta tildes y la letra ñ.

import '../models/perfil.dart';

/// Quita las tildes y la ñ de un texto para poder ordenarlo
/// alfabéticamente de forma correcta en español.
///
/// Por ejemplo, "Álvarez" se convierte en "alvarez" y "Muñoz" en "munoz".
///
/// - [s]: el texto a normalizar
/// Devuelve el texto en minúsculas y sin tildes
String normalizarApellido(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

/// Ordena una lista de perfiles dejando solo los activos
/// y ordenándolos por apellido alfabéticamente.
///
/// - [perfiles]: la lista completa de perfiles
/// Devuelve una nueva lista solo con los perfiles activos ordenados
List<Perfil> ordenarPerfiles(List<Perfil> perfiles) =>
    [...perfiles.where((p) => p.activo)]..sort(
      (a, b) => normalizarApellido(
        a.apellidos,
      ).compareTo(normalizarApellido(b.apellidos)),
    );
