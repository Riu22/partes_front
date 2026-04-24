import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';

class UpdateService {
  final Dio _dio = Dio(BaseOptions(baseUrl: Env.apiUrl));

  Future<Map<String, String>?> hayActualizacion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      print('Versión instalada: ${info.version}');

      final response = await _dio.get('/version');
      print('Respuesta servidor: ${response.data}');

      final versionServidor = response.data['version'] as String;
      final url = response.data['url'] as String;
      print('Versión servidor: $versionServidor');

      if (versionServidor != info.version) {
        print('Hay actualización disponible');
        return {'version': versionServidor, 'url': url};
      }
      print('Ya está actualizado');
      return null;
    } catch (e) {
      print('Error en hayActualizacion: $e');
      return null;
    }
  }

  Future<void> abrirDescarga(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
