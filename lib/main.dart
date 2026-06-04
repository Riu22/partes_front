// =============================================================================
// ARCHIVO:   main.dart
// PROPOSITO: Punto de entrada principal de la aplicacion.  Inicializa las
//            dependencias globales (dotenv, Riverpod, tema, idioma, router) y
//            monta el widget raiz de Flutter.
//
//            Este archivo es el corazon de la aplicacion.  Sin el, el programa
//            no puede arrancar.  Se encarga de:
//
//              1. Cargar variables de entorno desde el archivo .env
//              2. Crear el ProviderScope (contenedor de estado global de
//                 Riverpod que permite compartir datos entre widgets sin
//                 pasarlos manualmente por constructores)
//              3. Inicializar el enrutador GoRouter para navegar entre
//                 pantallas con URLs
//              4. Configurar el tema visual (Material 3 con esquema de
//                 colores azul y modo claro)
//              5. Forzar el idioma a espanol (Espana) usando el paquete
//                 flutter_localizations
//              6. Escalar el texto segun el ancho de pantalla usando
//                 MediaQuery (pantallas mas grandes = texto mas grande)
//              7. Mostrar un banner rojo de "Sin conexion" cuando el
//                 dispositivo no tiene internet
//
//            Flujo tipico de arranque:
//              main()
//                -> WidgetsFlutterBinding.ensureInitialized()
//                -> dotenv.load(fileName: ".env")
//                -> runApp(ProviderScope(child: MyApp()))
//                  -> MyApp.build()
//                    -> MaterialApp.router(routerConfig, theme, locale...)
//                      -> _NoConnectionBanner superpuesto via Stack
//
// CONCEPTOS DE FLUTTER EXPLICADOS:
//   - ProviderScope:    Widget de Riverpod que crea el contenedor de estado
//                       global.  Todos los providers viven dentro de el.
//                       Sin el, ref.watch() y ref.read() no funcionan.
//   - WidgetsFlutterBinding.ensureInitialized():  Necesario antes de llamar
//                       a cualquier metodo asincrono que dependa del motor
//                       de Flutter (como dotenv.load).
//   - MaterialApp.router:  Variante de MaterialApp que usa GoRouter en lugar
//                       del sistema de rutas Navigator 1.0.  El router
//                       externo maneja toda la navegacion.
//   - MediaQuery:       Objeto que contiene informacion de la pantalla:
//                       dimensiones, densidad, factor de escala de texto,
//                       padding de la barra de estado, etc.
//   - ConsumerStatefulWidget / ConsumerWidget:  Variantes de StatefulWidget
//                       y StatelessWidget que tienen acceso a WidgetRef para
//                       leer/escuchar providers de Riverpod.
//
// NOTA:  No confundir "context" (el arbol de widgets de Flutter) con el
//        concepto de contexto empresarial.  Aqui siempre se refiere a
//        BuildContext, la posicion de un widget en el arbol de Flutter.
// =============================================================================

import 'package:flutter/material.dart';
// flutter/material.dart  contiene el toolkit Material Design de Flutter.
// Incluye Widget, State, BuildContext, ThemeData, Colors, MaterialApp,
// Scaffold, AppBar, Text, etc.  Es la libreria principal de UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod  es el gestor de estado global reactivo.  Proporciona
// Provider, StateProvider, FutureProvider, ref.watch(), ref.read(), etc.
// Reemplaza patrones como BLoC o Provider (el de InheritedWidget).

import 'package:flutter_dotenv/flutter_dotenv.dart';
// flutter_dotenv  carga variables de entorno desde un archivo .env para
// usarlas en tiempo de ejecucion (URLs de servidores, claves, etc.).

import 'package:flutter_localizations/flutter_localizations.dart';
// flutter_localizations  contiene los delegados de traduccion para Material.
// GlobalMaterialLocalizations.delegate proporciona textos en espanol para
// botones como "Cancelar", "Aceptar", fechas, etc.

import 'config/router.dart';
// config/router.dart  Define el GoRouter (routerProvider) con todas las
// rutas de la aplicacion y la logica de redireccion (auth guards).

import 'providers/sync_provider.dart';
// providers/sync_provider.dart  Contiene syncProvider, que mantiene el motor
// de sincronizacion en segundo plano (descarga subidas pendientes, etc.).

import 'helpers/splash_helper.dart';
// helpers/splash_helper.dart  Contiene ocultarSplash(), que cierra la
// pantalla de bienvenida nativa (splash screen) al terminar la carga
// inicial.

// =============================================================================
// FUNCION:  main
// PROPOSITO: Punto de entrada de la aplicacion Dart.  Flutter llama a esta
//            funcion automaticamente al iniciar el programa.
//
/// Punto de entrada de la aplicacion.
/// Inicializa el binding de Flutter, carga el archivo .env (o usa valores
/// por defecto si no existe) y monta el widget raiz envuelto en ProviderScope
/// para que Riverpod funcione en toda la app.
// =============================================================================
void main() async {
  // --- PASO 1:  Asegurar que el motor de Flutter este listo ----------------
  // WidgetsFlutterBinding es el puente entre Dart y el motor nativo de
  // Flutter (Skia/Impeller).  Sin ensureInitialized(), las llamadas async
  // como dotenv.load() fallan porque el binding aun no existe.
  WidgetsFlutterBinding.ensureInitialized();

  // --- PASO 2:  Cargar variables de entorno --------------------------------
  // Intenta leer el archivo .env que contiene SUPABASE_URL, API_URL, etc.
  // Si no existe (despliegue sin .env), usa los valores por defecto
  // definidos en config/env.dart.
  try {
    await dotenv.load(fileName: ".env");
    // Si el archivo existe, se cargan las variables y se imprimen en consola
    // para confirmar.
    print("Configuracion cargada desde .env");
  } catch (e) {
    // Si el archivo no existe o hay un error, no se detiene la ejecucion.
    // Env._get() usara los valores por defecto definidos estaticamente.
    print("Usando configuracion por defecto (No se encontro .env)");
  }

  // --- PASO 3:  Montar el widget raiz --------------------------------------
  // ProviderScope es un widget que crea un contenedor de providers de
  // Riverpod.  Todo provider (ref.watch, ref.read) debe estar dentro de
  // un ProviderScope.  MyApp es el widget principal que construye el
  // arbol entero de la aplicacion.
  runApp(const ProviderScope(child: MyApp()));
}

// =============================================================================
/// Widget principal de la aplicacion.
///
/// MyApp es la raiz del arbol de widgets.  Extiende ConsumerStatefulWidget
/// para tener acceso a WidgetRef (ref) y poder escuchar cambios en los
/// providers de Riverpod en tiempo real.
///
/// CONCEPTO FLUTTER:  ConsumerStatefulWidget es una variante de
/// StatefulWidget que inyecta automaticamente WidgetRef en el State.  Esto
/// permite que el widget reaccione a cambios de estado sin necesidad de
/// usar Provider.of<>, context.read<> o context.watch<>.
/// =============================================================================
class MyApp extends ConsumerStatefulWidget {
  // super.key es la clave que Flutter usa para identificar widgets en el
  // arbol.  Es opcional y se pasa a la clase padre.
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

// =============================================================================
/// Estado mutable del widget MyApp.
///
/// _MyAppState contiene la logica de construccion principal y se encarga de:
///   1. Ocultar la splash screen nativa despues del primer frame
///   2. Mantener vivo el provider de sincronizacion (syncProvider)
///   3. Construir el MaterialApp.router con tema, localizacion, router y
///      el builder que escala el texto y superpone el banner offline.
/// =============================================================================
class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    // initState se ejecuta una sola vez, cuando el widget se inserta en el
    // arbol.  Es el lugar correcto para lanzar operaciones unicas de inicio.
    super.initState();

    // addPostFrameCallback ejecuta el callback DESPUES de que se pinte el
    // primer frame.  Esto garantiza que el arbol de widgets ya existe y que
    // cualquier operacion que dependa del contexto sea segura.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ocultarSplash() cierra la pantalla de bienvenida nativa (splash)
      // definida en Android (styles.xml) o iOS (LaunchScreen).
      ocultarSplash();
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- DESPERTADOR DE SINCRONIZACION -------------------------------------
    // ref.watch(syncProvider) mantiene activo el provider de sincronizacion.
    // Aunque no se use el valor devuelto, el simple hecho de "escucharlo"
    // evita que Riverpod lo destruya (los providers no escuchados se
    // eliminan).  SyncProvider se encarga de subir a Supabase los partes
    // creados sin conexion y de escuchar cambios en la red/ciclo de vida.
    // La llamada de la linea 47 dice:
    //   " DESPERTADOR: Mantiene el motor de sincronizacion vivo y atento
    //     a la red/ciclo de vida "
    ref.watch(syncProvider);

    // --- OBTENER EL ROUTER DE GOROUTER -------------------------------------
    // routerProvider es un Provider<GoRouter> definido en config/router.dart.
    // ref.watch() se suscribe a cambios de autenticacion: cuando el usuario
    // inicia/cierra sesion, el router se notifica y redirige automaticamente.
    final router = ref.watch(routerProvider);

    // --- CONSTRUIR LA APLICACION PRINCIPAL ----------------------------------
    // MaterialApp.router es la version de MaterialApp que utiliza un router
    // externo (GoRouter) en lugar del Navigator clasico.  El router maneja
    // rutas, redirecciones, deep links y transiciones.
    return MaterialApp.router(
      // Titulo de la aplicacion (usado por el sistema operativo en el
      // selector de apps recientes y en la barra de titulo de la ventana).
      title: 'Gestion de Partes',

      // Oculta el banner rojo "DEBUG" que Flutter muestra por defecto en
      // la esquina superior derecha durante el desarrollo.
      debugShowCheckedModeBanner: false,

      // --- CONFIGURACION DE IDIOMA -----------------------------------------
      // locale:  Idioma por defecto de la app.  Locale('es', 'ES') forza
      // espanol de Espana.
      locale: const Locale('es', 'ES'),

      // localizationsDelegates:  Lista de objetos que proporcionan textos
      // traducidos para los widgets de Material.  Sin ellos, botones como
      // "Cancelar" aparecerian en ingles.
      localizationsDelegates: const [
        // Traducciones para widgets de Material (AppBar, Dialog, etc.).
        GlobalMaterialLocalizations.delegate,
        // Traducciones para widgets genericos (texto direccional, etc.).
        GlobalWidgetsLocalizations.delegate,
        // Traducciones para widgets de estilo Cupertino (iOS).
        GlobalCupertinoLocalizations.delegate,
      ],

      // supportedLocales:  Lista de idiomas que la app soporta.
      supportedLocales: const [Locale('es', 'ES')],

      // --- CONFIGURACION DE TEMA -------------------------------------------
      // ThemeData define la paleta de colores, tipografia, estilos de
      // botones, tarjetas, etc.  Aplica a toda la aplicacion.
      // CONCEPTO FLUTTER:  ThemeData es un objeto inmutable que describe
      // la apariencia visual de la app.  Se aplica a todos los widgets
      // hijos via InheritedTheme.
      theme: ThemeData(
        // colorScheme.fromSeed  genera una paleta de colores completa
        // (primario, secundario, terciario, error, etc.) a partir de un
        // solo color semilla (Colors.blue).
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          // brightness:  Light = modo claro, Dark = modo oscuro.
          brightness: Brightness.light,
        ),
        // useMaterial3:  Habilita el diseno Material 3 (Material You) con
        // sus formas redondeadas, elevaciones y tipografia actualizada.
        useMaterial3: true,
      ),

      // routerConfig:  La configuracion del router devuelta por GoRouter.
      // GoRouter es un paquete externo que implementa navegacion declarativa
      // basada en URLs (similar a React Router o Vue Router).
      routerConfig: router,

      // --- BUILDER GLOBAL --------------------------------------------------
      // builder es una funcion que envuelve a TODOS los widgets de la app.
      // Se ejecuta para cada pantalla, permitiendo modificar el arbol global
      // sin tocar cada pantalla individualmente.
      builder: (context, child) {
        // MediaQuery.of(context) devuelve las propiedades de la pantalla
        // actual:  ancho, alto, densidad de pixeles, padding, etc.
        final mq = MediaQuery.of(context);
        final width = mq.size.width;

        // --- ESCALADO DE TEXTO SEGUN PANTALLA ------------------------------
        // En pantallas muy grandes (monitores, tablets), el texto se ve
        // pequeno.  Escalamos el factor de texto linealmente segun el ancho.
        // switch expression es una caracteristica de Dart 3 que evalua
        // condiciones en orden y devuelve el primer valor que coincida.
        final double scale = switch (width) {
          // > 2200 pixeles:  pantallas 4K o ultra anchas, escala 1.45x
          > 2200 => 1.45,
          // > 1600 pixeles:  pantallas grandes (1440p), escala 1.25x
          > 1600 => 1.25,
          // > 1024 pixeles:  tablets en horizontal, escala 1.10x
          > 1024 => 1.10,
          // 1024 o menos:  telefonos y tablets verticales, escala normal 1x
          _ => 1.00,
        };

        // CONCEPTO FLUTTER:  MediaQuery es un widget que sobreescribe las
        // propiedades de la pantalla para sus hijos.  Aqui creamos uno nuevo
        // con textScaler modificado para que todos los textos se escalen.
        // mq.copyWith() crea una copia de MediaQueryData con el campo
        // textScaler cambiado a una escala lineal.
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          // Stack apila los widgets uno encima del otro.
          // child:  la pantalla actual (cualquier pagina).
          // _NoConnectionBanner:  barra roja superpuesta (solo visible sin
          // internet).  Usamos ! (null assertion) porque child nunca es null
          // en este contexto (GoRouter siempre construye una pantalla).
          child: Stack(children: [child!, const _NoConnectionBanner()]),
        );
      },
    );
  }
}

// =============================================================================
/// Widget que muestra un banner rojo en la parte superior cuando el
/// dispositivo no tiene conexion a internet.
///
/// CONCEPTO FLUTTER:  ConsumerWidget es una variante de StatelessWidget que
/// tiene acceso a WidgetRef via el parametro ref del metodo build().  Se
/// usa para leer providers de Riverpod sin necesidad de crear un
/// StatefulWidget.  La diferencia principal con StatelessWidget es que
/// ref.watch() hace que el widget se reconstruya automaticamente cuando
/// el valor del provider cambia.
///
/// El banner se oculta automaticamente cuando la conexion se restaura,
/// porque ref.watch(conectividadProvider) devuelve el nuevo estado (true)
/// y el widget retorna SizedBox.shrink() (widget vacio).
/// =============================================================================
class _NoConnectionBanner extends ConsumerWidget {
  /// Constructor privado (con guion bajo) porque este widget solo se usa
  /// dentro de main.dart.  No se puede instanciar desde otros archivos.
  const _NoConnectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- LEER ESTADO DE CONECTIVIDAD ---------------------------------------
    // conectividadProvider es un provider que expone un AsyncValue<bool>.
    // valueOrNull devuelve el valor si el provider se ha resuelto, o null
    // si esta cargando o tiene error.  ?? true:  si es null (cargando),
    // asumimos que hay conexion (true) para no mostrar el banner
    // innecesariamente durante la carga inicial.
    final tieneConexion = ref.watch(conectividadProvider).valueOrNull ?? true;

    // Si hay conexion, no mostramos nada.
    // SizedBox.shrink() es un widget invisible de tamano cero.  Equivale
    // a un "widget vacio" que no ocupa espacio en el layout.
    if (tieneConexion) return const SizedBox.shrink();

    // --- MOSTRAR BANNER ROJO -----------------------------------------------
    // Positioned coloca el banner en una posicion absoluta dentro del Stack.
    // top: padding superior (altura de la barra de estado, para que el
    // banner no se superponga a los iconos del sistema como la hora/bateria).
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Material(
        // color rojo intenso para llamar la atencion del usuario.
        color: Colors.redAccent,
        child: const Padding(
          // padding vertical de 4 pixeles para que el texto no quede pegado.
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            // Mensaje informativo:  la app sigue funcionando offline.
            'Sin conexion - Modo Offline activo',
            // Centrado horizontalmente.
            textAlign: TextAlign.center,
            style: TextStyle(
              // Texto blanco para contrastar con fondo rojo.
              color: Colors.white,
              // Tamano pequeno (12) para no robar mucho espacio.
              fontSize: 12,
              // Negrita para destacar.
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
