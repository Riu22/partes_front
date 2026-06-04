// =============================================================================
// ARCHIVO:   env.dart
// PROPOSITO: Configuracion de entorno de la aplicacion.  Centraliza el acceso
//            a todas las variables de configuracion: URLs del servidor
//            backend, URL de Supabase (base de datos y autenticacion), clave
//            anonima de Supabase, URL de la app web y URL de descarga del APK.
//
//            La clase Env lee las variables desde un archivo .env usando el
//            paquete flutter_dotenv.  Si el archivo .env no existe o una
//            variable falta, se usan valores por defecto definidos
//            estaticamente en esta clase.
//
//            En modo RELEASE (kReleaseMode == true), se usa la IP del
//            servidor de produccion (_serverIp).  En modo DEBUG, se usa la
//            IP local (_localIp) para desarrollo en red local.
//
//            kReleaseMode es una constante de dart:core (re-exportada por
//            flutter/foundation.dart) que es true cuando la app se compila
//            con "flutter build" (modo release) y false en "flutter run"
//            (modo debug).
//
// ESTRUCTURA:
//   Env (clase estatica)
//     +-- _localIp          IP del servidor de desarrollo (red local)
//     +-- _serverIp         IP del servidor de produccion
//     +-- _get()            Metodo helper que lee del .env o usa default
//     +-- supabaseUrl       URL base de Supabase
//     +-- supabaseAnonKey   Clave anonima de Supabase (JWT publico)
//     +-- apiUrl            URL de la API REST del backend
//     +-- appUrl            URL de la aplicacion web
//     +-- apkUrl            URL de descarga del APK Android
//
// NOTA:  Todas las variables y metodos son static porque la clase Env no
//        necesita instanciarse.  Se usa como un namespace o "singleton
//        estatico".  En Dart, "static" significa que pertenece a la clase
//        en si, no a una instancia.
// =============================================================================

import 'package:flutter/foundation.dart';
// flutter/foundation.dart  proporciona kReleaseMode, ChangeNotifier,
// ValueNotifier, etc.  kReleaseMode es una constante que indica si la app
// se ejecuta en modo release (compilada) o debug (interpretada).

import 'package:flutter_dotenv/flutter_dotenv.dart';
// flutter_dotenv  carga el archivo .env en memoria.  dotenv.maybeGet(key)
// devuelve el valor de la variable o null si no existe.

// =============================================================================
/// Configuracion de entorno: URLs del servidor, API, Supabase, etc.
///
/// Proporciona getters estaticos para acceder a las variables de
/// configuracion.  Lee del archivo .env si existe, o usa valores por defecto
/// en caso contrario.
///
/// CONCEPTO DART:  Una clase con solo miembros static es equivalente a un
/// "namespace" o "modulo de constantes".  No se puede (ni se debe)
/// instanciar.  Se usa para agrupar funciones y constantes relacionadas.
///
/// USO:
///   Env.supabaseUrl     -> "http://192.168.110.129:8000" (debug)
///   Env.apiUrl          -> "http://192.168.110.190:8081/api/v1" (release)
///   Env.supabaseAnonKey -> "eyJhbGciOiJIUzI1NiIs..." (JWT)
/// =============================================================================
class Env {
  // ===========================================================================
  // IPs POR DEFECTO
  // ===========================================================================
  // Estas direcciones IP se usan como fallback si el archivo .env no
  // existe.  _localIp se usa en debug, _serverIp se usa en release.

  /// IP del servidor de desarrollo en la red local.
  /// Se usa cuando kReleaseMode es false (modo debug / "flutter run").
  /// Cambiar segun la IP local del servidor de desarrollo.
  static const _localIp = '192.168.110.129';

  /// IP del servidor de produccion.
  /// Se usa cuando kReleaseMode es true (modo release / "flutter build").
  /// Cambiar segun la IP del servidor real.
  static const _serverIp = '192.168.110.190';

  // ===========================================================================
  // LOGICA DE CONSULTA
  // ===========================================================================

  /// Intenta leer la variable [key] del archivo .env.  Si no existe o el
  /// archivo .env no se cargo, devuelve [defaultValue].
  ///
  /// dotenv.maybeGet() es la version segura de dotenv.env[key].  En lugar
  /// de lanzar una excepcion si la clave no existe, devuelve null, y
  /// nosotros usamos el operador ?? para proporcionar el valor por defecto.
  ///
  /// PARAMETROS:
  ///   [key]           - Nombre de la variable en .env (ej: "SUPABASE_URL")
  ///   [defaultValue]  - Valor que se usara si la variable no existe
  ///
  /// RETORNO:
  ///   String con el valor de la variable o el valor por defecto.
  static String _get(String key, String defaultValue) {
    return dotenv.maybeGet(key) ?? defaultValue;
  }

  // ===========================================================================
  // GETTERS DE CONFIGURACION
  // ===========================================================================

  /// URL de Supabase (base de datos y autenticacion).
  ///
  /// Supabase proporciona:
  ///   - Base de datos PostgreSQL con API REST
  ///   - Autenticacion (login, registro, recuperacion de password)
  ///   - Almacenamiento de archivos (Storage)
  ///   - Realtime (suscribirse a cambios en la BD)
  ///
  /// En debug:  "http://<localIp>:8000"
  /// En release: "http://<serverIp>:8000"
  /// El puerto 8000 es el puerto por defecto de la API de Supabase (Kong).
  static String get supabaseUrl {
    // Elegir IP segun el modo de compilacion.
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    // Si .env tiene SUPABASE_URL, usarla.  Si no, construirla con la IP.
    return _get('SUPABASE_URL', 'http://$ipDefecto:8000');
  }

  /// Clave anonima de Supabase (JWT de rol "anon").
  ///
  /// Esta clave permite que la app se conecte a Supabase sin autenticacion
  /// previa.  Es una clave PUBLICA que va incrustada en la app.  No es
  /// un secreto.  Las reglas de seguridad se definen en las Policies
  /// (Row Level Security) de Supabase, no en la clave.
  ///
  /// El JWT tiene este payload:
  /// {
  ///   "role": "anon",
  ///   "iss": "supabase-demo",
  ///   "iat": 1641769200,
  ///   "exp": 1799535600
  /// }
  static String get supabaseAnonKey {
    return _get(
      'SUPABASE_ANON_KEY',
      // Valor por defecto: un JWT pre-generado para desarrollo local.
      // En produccion, cambiar SUPABASE_ANON_KEY en el .env.
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
    );
  }

  /// URL base de la API REST del backend personalizado.
  ///
  /// Esta API es independiente de Supabase.  Es un backend propio que
  /// implementa logica de negocio adicional (calculos de quincena, informes
  /// personalizados, etc.).  Corre en el mismo servidor pero en otro puerto.
  ///
  /// En debug:  "http://<localIp>:8081/api/v1"
  /// En release: "http://<serverIp>:8081/api/v1"
  /// El puerto 8081 es el puerto del backend REST personalizado.
  static String get apiUrl {
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    return _get('API_URL', 'http://$ipDefecto:8081/api/v1');
  }

  /// URL de la aplicacion web (frontend web).
  ///
  /// Se usa principalmente para el flujo de recuperacion de contrasena.
  /// Cuando el usuario solicita restablecer su contrasena desde la app,
  /// Supabase envia un correo con un enlace que apunta a esta URL.
  ///
  /// En debug:  "http://<localIp>:3000"
  /// En release: "http://<serverIp>:3000"
  /// El puerto 3000 es el puerto del frontend web (Next.js, etc.).
  static String get appUrl {
    final ipDefecto = kReleaseMode ? _serverIp : _localIp;
    return _get('APP_URL', 'http://$ipDefecto:3000');
  }

  /// URL de descarga del APK de la app Android.
  ///
  /// Se usa para que los usuarios puedan descargar la ultima version de
  /// la app desde la web o desde un boton de "Actualizar" dentro de la app.
  /// El APK esta almacenado en Supabase Storage (bucket "instaladores").
  ///
  /// Usa _serverIp siempre (incluso en debug) porque el APK se compila
  /// contra el servidor de produccion.
  static String get apkUrl {
    return _get(
      'APK_URL',
      // Construye la URL completa al objeto en Supabase Storage.
      // El bucket "instaladores" contiene el archivo "app-release.apk".
      'http://$_serverIp:8000/storage/v1/object/public/instaladores/app-release.apk',
    );
  }
}
