import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // --- DATOS POR DEFECTO (EL PLAN B) ---
  static const _localIp = '192.168.110.129';
  static const _serverIp = '192.168.110.190';

  // --- LÓGICA DE CONSULTA ---

  // Esta función intenta leer del .env. Si no existe la variable, devuelve el default.
  static String _get(String key, String defaultValue) {
    return dotenv.maybeGet(key) ?? defaultValue;
  }

  static String get supabaseUrl {
    // Definimos qué IP usaríamos por defecto según el modo de la App
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;

    // CONSULTA: ¿Está en el .env? Si no, usa la IP que calculamos arriba.
    return _get('SUPABASE_URL', 'http://$ipDefecto:8000');
  }

  static String get supabaseAnonKey {
    // CONSULTA: ¿Está en el .env? Si no, usa tu clave maestra hardcoded.
    return _get(
      'SUPABASE_ANON_KEY',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
    );
  }

  static String get apiUrl {
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    return _get('API_URL', 'http://$ipDefecto:8081/api/v1');
  }

  static String get appUrl {
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    return _get('APP_URL', 'http://$ipDefecto:3000');
  }
}
