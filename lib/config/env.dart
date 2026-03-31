import 'package:flutter/foundation.dart';

class Env {
  static const _pcIp = '[IP_ADDRESS]';

  static String get apiUrl {
    if (kIsWeb) return 'http://localhost:8081/api/v1';
    return 'http://[IP_ADDRESS]/api/v1';
  }

  static String get supabaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://[IP_ADDRESS]';
  }

  // URL base de la app para redirecciones
  static String get appUrl {
    if (kIsWeb) return 'http://localhost:3000';
    return 'http://$_pcIp:3000';
  }
}
