import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';

/// Servicio para comprobar si hay una nueva versión de la app disponible.
/// Compara la versión instalada con la que devuelve el servidor.
class UpdateService {
  final Dio _dio = Dio(BaseOptions(baseUrl: Env.apiUrl));

  /// Consulta al servidor si hay una versión más reciente.
  /// Devuelve un mapa con 'version' y 'url' si hay actualización, o null si ya está actualizado.
  Future<Map<String, String>?> hayActualizacion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      print('Versión instalada: ${info.version}');

      final response = await _dio.get('/version');
      print('Respuesta del servidor: ${response.data}');

      final versionServidor = response.data['version'] as String;
      final url = response.data['url'] as String;
      print('Versión en servidor: $versionServidor');

      if (versionServidor != info.version) {
        print('Hay una actualización disponible');
        return {'version': versionServidor, 'url': url};
      }
      print('La app ya está actualizada');
      return null;
    } catch (e) {
      print('Error al comprobar actualización: $e');
      return null;
    }
  }

  /// Abre la URL de descarga en el navegador o gestor de descargas del sistema
  Future<void> abrirDescarga(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
