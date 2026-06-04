// =============================================================================
// lazy_screen.dart  -  Widget de carga diferida (lazy loading)
// =============================================================================
// ASPECTO EN PANTALLA:
//   Mientras no ha cargado: pantalla en blanco (SizedBox.shrink).
//   Mientras carga: pantalla completa con spinner centrado.
//   Cuando ha cargado: el contenido real proporcionado por builder().
//
// USO:
//   Pantallas pesadas que deben cargar datos antes de mostrarse.
//   Permite diferir la carga al frame posterior (postFrameCallback)
//   para no bloquear la animacion inicial.
//
// DATOS QUE NECESITA:
//   - loader: funcion async que realiza la carga de datos
//   - builder: funcion que construye el widget cuando los datos estan listos
//   - eager: bool, si true carga inmediatamente en initState (sin postFrame)
//
// INTERACCION DEL USUARIO:
//   No tiene interaccion. Solo muestra estados de carga/contenido.
// =============================================================================

/// Widget que carga contenido de forma diferida (lazy loading).
/// Muestra un indicador de carga mientras se ejecuta una tarea async
/// y luego renderiza el contenido real. Útil para pantallas pesadas.
import 'package:flutter/material.dart';

/// Widget con carga diferida. Ejecuta [loader] de forma asincrona y
/// luego muestra el widget devuelto por [builder].
///
/// [StatefulWidget] porque gestiona los estados _loaded y _loading.
class LazyWidget extends StatefulWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;
  // Si true, carga inmediatamente en initState en lugar de en postFrame.
  final bool eager;

  const LazyWidget({
    super.key,
    required this.loader,
    required this.builder,
    this.eager = false,
  });

  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  bool _loaded = false; // Indica si ya se ejecuto el loader.
  bool _loading = false; // Indica si el loader esta en ejecucion.

  @override
  void initState() {
    super.initState();
    if (widget.eager) {
      // Carga inmediata: se ejecuta en el mismo initState.
      _load();
    } else {
      // Carga diferida: espera al siguiente frame para no bloquear
      // la construccion inicial del widget tree.
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (_loaded || _loading) return; // Evita doble ejecucion.
    setState(() => _loading = true);
    await widget.loader();
    if (mounted) setState(() {
      _loaded = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.builder(); // Contenido real.
    if (_loading) {
      // Pantalla de carga con spinner centrado.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Estado inicial: nada visible.
    return const SizedBox.shrink();
  }
}
