import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';

class UpdateService {
  final Dio _dio = Dio(BaseOptions(baseUrl: Env.apiUrl));

  Future<Map<String, String>?> hayActualizacion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await _dio.get('/api/v1/version');
      final versionServidor = response.data['version'] as String;
      final url = response.data['url'] as String;

      if (versionServidor != info.version) {
        return {'version': versionServidor, 'url': url};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> abrirDescarga(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
