import 'package:flutter/foundation.dart';

class Env {
  static const _pcIp = '192.168.110.129';

  static String get apiUrl {
    if (kIsWeb) return 'http://localhost:8081/api/v1';
    return 'http://$_pcIp:8081/api/v1';
  }

  static String get supabaseUrl {
    if (kIsWeb) return 'http://$_pcIp:8000';
    return 'http://$_pcIp:8000';
  }

  static String get appUrl {
    if (kIsWeb) return 'http://$_pcIp:3000';
    return 'http://$_pcIp:3000';
  }
}
