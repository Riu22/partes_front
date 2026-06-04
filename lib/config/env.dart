import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de entorno: URLs del servidor, API, Supabase, etc.
/// Lee variables del archivo .env o usa valores por defecto.
/// En modo release usa la IP del servidor real; en debug usa IP local.
class Env {
  // --- IPs por defecto (se usan si no hay .env) ---
  // _localIp: para desarrollo en la red local
  // _serverIp: para producción (servidor real)
  static const _localIp = '192.168.110.129';
  static const _serverIp = '192.168.110.190';

  // --- Lógica de consulta ---

  /// Intenta leer la variable del .env. Si no existe, devuelve el valor por defecto.
  static String _get(String key, String defaultValue) {
    return dotenv.maybeGet(key) ?? defaultValue;
  }

  /// URL de Supabase (base de datos y autenticación)
  static String get supabaseUrl {
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    return _get('SUPABASE_URL', 'http://$ipDefecto:8000');
  }

  /// Clave anónima de Supabase (permite login y operaciones básicas)
  static String get supabaseAnonKey {
    return _get(
      'SUPABASE_ANON_KEY',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
    );
  }

  /// URL base de la API REST del backend
  static String get apiUrl {
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    return _get('API_URL', 'http://$ipDefecto:8081/api/v1');
  }

  /// URL de la aplicación web (usada para redirección de recuperación de password)
  static String get appUrl {
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    return _get('APP_URL', 'http://$ipDefecto:3000');
  }

  /// URL de descarga del APK de la app Android
  static String get apkUrl {
    return _get(
      'APK_URL',
      'http://$_serverIp:8000/storage/v1/object/public/instaladores/app-release.apk',
    );
  }
}
