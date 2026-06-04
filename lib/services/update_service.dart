// =============================================================================
// update_service.dart  --  Servicio de deteccion de actualizaciones
// =============================================================================
// PROPOSITO:
//   Comprueba si hay una nueva version de la aplicacion disponible en el
//   servidor. Compara la version instalada localmente con la version publicada
//   y, si son diferentes, ofrece al usuario la URL de descarga de la nueva
//   version.
//
// ANALOGIA:
//   - UpdateService es como un "vigilante de versiones". Cada vez que se le
//     pregunta, llama al servidor y dice: "Eh, en el servidor tienen la
//     version X.Y.Z, pero tu tienes la A.B.C. Deberias actualizarte".
//   - La URL de descarga es como un cartel que dice "Nueva version disponible
//     aqui -> www.ejemplo.com/app-v2.apk".
//
// CONEXION CON EL RESTO DE LA APP:
//   - Normalmente se llama al iniciar la app (en el splash screen o en el
//     menu de configuracion) para notificar al usuario si debe actualizar.
//   - Si hay actualizacion, la app muestra un dialogo con la opcion de
//     descargar la nueva version.
//   - Es independiente de AuthService y ApiService (tiene su propio Dio).
//
// NOTA SOBRE SEGURIDAD:
//   Este servicio no verifica la autenticidad de la URL de descarga. En una
//   app de produccion, la respuesta del servidor deberia estar firmada para
//   evitar que un atacante manipule la URL y redirija a una descarga maliciosa.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';

/// Servicio para comprobar si hay una nueva version de la app disponible.
/// Compara la version instalada con la que devuelve el servidor.
///
/// COMO FUNCIONA INTERNAMENTE:
///   1. Obtiene la version instalada usando PackageInfo.fromPlatform().
///      Esta API lee el manifiesto de la app (Android: build.gradle, iOS: Info.plist).
///   2. Hace una peticion GET al endpoint /version del servidor.
///   3. El servidor devuelve un JSON con la version actual y la URL de descarga.
///   4. Compara ambas versiones como strings. Si son diferentes, hay actualizacion.
///
///   NOTA: La comparacion es string exacta ("1.2.3" != "1.2.4"). No usa
///   versionado semantico (no compara mayor.menor.patch numericamente).
///   Si el servidor devuelve "1.10.0" y el cliente tiene "1.9.0",
///   "1.10.0" != "1.9.0" es true (correcto). Pero "1.9.0" != "1.9.0.0"
///   tambien seria true, aunque semanticamente sean iguales.
class UpdateService {
  /// Cliente HTTP propio para consultas de version.
  /// No necesita autenticacion ni tokens.
  final Dio _dio = Dio(BaseOptions(baseUrl: Env.apiUrl));

  /// Consulta al servidor si hay una version mas reciente.
  /// Devuelve un mapa con 'version' y 'url' si hay actualizacion,
  /// o null si ya esta actualizado o si hubo un error.
  ///
  /// ESTRUCTURA DE LA RESPUESTA DEL SERVIDOR:
  ///   {
  ///     "version": "1.2.3",    // Version actual publicada en el servidor
  ///     "url": "https://..."   // URL de descarga del nuevo APK/IPA
  ///   }
  ///
  /// POSIBLES CASOS:
  ///   - Version del servidor != version instalada: hay actualizacion.
  ///   - Version del servidor == version instalada: app actualizada.
  ///   - Error de red o servidor caido: se devuelve null (no se interrumpe
  ///     el flujo de la app, simplemente no se muestra aviso).
  Future<Map<String, String>?> hayActualizacion() async {
    try {
      // Obtiene la version de la app instalada en el dispositivo
      // PackageInfo lee el bundle version (Android: versionName, iOS: CFBundleShortVersionString)
      final info = await PackageInfo.fromPlatform();
      print('Version instalada: ${info.version}');

      // Consulta la version actual en el servidor
      final response = await _dio.get('/version');
      print('Respuesta del servidor: ${response.data}');

      // Extrae la version y URL de la respuesta del servidor
      final versionServidor = response.data['version'] as String;
      final url = response.data['url'] as String;
      print('Version en servidor: $versionServidor');

      // Compara las versiones (comparacion de strings exacta)
      if (versionServidor != info.version) {
        print('Hay una actualizacion disponible');
        return {'version': versionServidor, 'url': url};
      }
      print('La app ya esta actualizada');
      return null;
    } catch (e) {
      // Si algo falla (red, parsing de JSON, etc.) no lanzamos excepcion,
      // simplemente devolvemos null. La app seguira funcionando normalmente
      // sin molestar al usuario por un error de actualizacion.
      print('Error al comprobar actualizacion: $e');
      return null;
    }
  }

  /// Abre la URL de descarga en el navegador o gestor de descargas del sistema.
  ///
  /// [url] es la URL de descarga obtenida del servidor (tipicamente un enlace
  /// a un APK en Google Drive, Dropbox, o un CDN).
  ///
  /// Usa launchUrl con LaunchMode.externalApplication para abrir la URL
  /// en una aplicacion externa (navegador) en lugar de dentro de la app
  /// (WebView). Esto permite la descarga real del archivo.
  Future<void> abrirDescarga(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
