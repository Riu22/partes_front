// =============================================================================
// ARCHIVO:   app_shell.dart
// PROPOSITO: Define la estructura visual comun (shell) que envuelve a todas
//            las pantallas que estan dentro del StatefulShellRoute.
//
//            AppShell proporciona:
//              1. Un Scaffold con AppBar (barra superior) que muestra el
//                 titulo de la pantalla actual.
//              2. Un Drawer (menu lateral) con opciones de navegacion.
//              3. El body que contiene el IndexedStack de GoRouter (las
//                 ramas del StatefulShellRoute).
//
//            Este widget actua como "layout padre".  Todas las pantallas
//            que se navegan dentro de las ramas del shell comparten esta
//            misma estructura.  Las pantallas fuera del shell (rutas
//            flotantes) NO usan AppShell y tienen su propio Scaffold.
//
// CONCEPTOS DE FLUTTER / GOROUTER EXPLICADOS:
//
//   - StatefulNavigationShell:
//       Objeto proporcionado por GoRouter que maneja la navegacion entre
//       las ramas de un StatefulShellRoute.  Contiene el indice de la
//       rama activa, el IndexedStack con todas las ramas, y metodos como
//       goBranch() para cambiar de pestana.
//
//   - Scaffold:
//       Widget de Material Design que implementa la estructura basica de
//       una pantalla: AppBar, body, drawer, bottomNavigationBar, FAB, etc.
//       Es el "lienzo" sobre el que se pintan los demas widgets.
//
//   - AppBar:
//       Barra superior de la pantalla.  Muestra el titulo, iconos de
//       accion, y opcionalmente un boton de menu (hamburguesa) para abrir
//       el drawer.
//
//   - Drawer:
//       Panel que se desliza desde el borde izquierdo de la pantalla.
//       Tipicamente contiene un menu de navegacion.  Se abre con el icono
//       de hamburguesa en la AppBar o deslizando el dedo desde la izquierda.
//
//   - IndexedStack (implicito en StatefulShellRoute):
//       Widget que muestra UNO de sus hijos a la vez, pero mantiene todos
//       los hijos montados (no los destruye al cambiar).  Esto permite que
//       cada rama conserve su estado aunque no este visible.
// =============================================================================

import 'package:flutter/material.dart';
// flutter/material.dart  proporciona Scaffold, AppBar, Text, Drawer, etc.

import 'package:go_router/go_router.dart';
// go_router  proporciona GoRouter, StatefulNavigationShell, GoRouterState.
// GoRouterState.of(context) devuelve el estado actual del router (incluye
// la ruta matchedLocation para saber en que pantalla estamos).

import '../widgets/app_drawer.dart';
// app_drawer.dart  Define AppDrawer, el menu lateral personalizado que
// contiene los enlaces a las diferentes secciones de la app.

// =============================================================================
/// Shell principal de la app con AppBar y menu lateral (drawer).
///
/// AppShell es un StatelessWidget que construye un Scaffold comun para
/// todas las pantallas que estan dentro del StatefulShellRoute.  Cada
/// pantalla "rama" se renderiza en el body del Scaffold.
///
/// navigationShell es proporcionado por GoRouter y contiene la rama activa
/// (el widget que se debe mostrar en el body).  Al cambiar de rama, el
/// navigationShell cambia internamente el indice del IndexedStack y el
/// body se actualiza.
///
/// CONCEPTO FLUTTER:  StatelessWidget es un widget que NO tiene estado
/// mutable.  Se construye una vez con los datos que recibe y no cambia
/// hasta que el widget padre lo reconstruye con nuevos datos.  Es mas
/// ligero que StatefulWidget.
/// =============================================================================
class AppShell extends StatelessWidget {
  /// navigationShell:  El objeto que GoRouter proporciona para manejar
  /// la navegacion entre ramas del StatefulShellRoute.
  ///
  /// StatefulNavigationShell contiene:
  ///   - currentIndex:  El indice de la rama activa (0 a N-1)
  ///   - goBranch(int index):  Metodo para cambiar a otra rama
  ///   - El propio widget hijo (IndexedStack con todas las ramas)
  final StatefulNavigationShell navigationShell;

  /// Constructor.
  /// super.key es la clave opcional que Flutter usa para identificar
  /// widgets en el arbol (util para animaciones y reordenamiento).
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Scaffold:  Estructura base de la pantalla con Material Design.
    // Proporciona los espacios para AppBar, body, drawer, etc.
    return Scaffold(
      // --- APP BAR (barra superior) ----------------------------------------
      // Muestra el titulo de la pantalla actual.  El titulo se obtiene de
      // _titleForLocation() que lo determina segun la ruta actual.
      // La AppBar se muestra en TODAS las pantallas que usan este shell.
      appBar: AppBar(title: _titleForLocation(context)),

      // --- DRAWER (menu lateral) -------------------------------------------
      // Panel que se desliza desde la izquierda.  AppDrawer contiene las
      // opciones de navegacion de la aplicacion.
      drawer: const AppDrawer(),

      // --- BODY (contenido de la rama activa) ------------------------------
      // navigationShell es el widget que contiene el IndexedStack con
      // todas las ramas.  Cuando el usuario cambia de pestana en la
      // navegacion inferior, GoRouter actualiza el indice del
      // IndexedStack y el body muestra la rama correspondiente.
      body: navigationShell,
    );
  }

  // ===========================================================================
  /// Metodo auxiliar que devuelve el titulo de la AppBar segun la ruta
  /// actual (matchedLocation).
  ///
  /// GoRouterState.of(context) obtiene el estado actual del router desde
  /// el arbol de widgets.  matchedLocation es la URL de la ruta activa
  /// (ej: "/partes", "/obras", etc.).
  ///
  /// Si la ruta actual no esta en el mapa (por ejemplo, es una ruta
  /// desconocida o una subruta), se usa el titulo por defecto:
  /// "Gestion de Partes".
  ///
  /// RETORNO:
  ///   Un widget Text con el titulo correspondiente a la ruta actual.
  // ===========================================================================
  Widget _titleForLocation(BuildContext context) {
    // Obtener la ruta actual desde GoRouterState.
    // GoRouterState.of(context) es el equivalente a Navigator de GoRouter:
    // devuelve el estado del router en la posicion actual del arbol.
    final location = GoRouterState.of(context).matchedLocation;

    // Mapa de rutas a titulos.  Solo incluye las rutas principales.
    // Las subrutas (como /partes/nuevo) se muestran con su titulo propio
    // en el AppBar interno de cada pantalla.
    final titles = {
      '/partes': 'Mis Partes',
      '/partes/nuevo': 'Nuevo Parte',
      '/obras': 'Obras',
      '/usuarios': 'Usuarios',
    };

    // Si la ruta esta en el mapa, usar su titulo.  Si no, usar el
    // titulo generico "Gestion de Partes".
    return Text(titles[location] ?? 'Gestion de Partes');
  }
}
