import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router.dart';
import 'providers/sync_provider.dart'; // Tu archivo de lógica de sincronización
import 'providers/obras_provider.dart';

void main() async {
  // 1. Garantizar que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    // --- MOTOR DE SINCRONIZACIÓN ---
    // Al hacer watch aquí, el "ref.listen" dentro de tu syncProvider
    // se activa y se mantiene escuchando cambios de red en todo momento.
    ref.watch(syncProvider);

    // Precarga de datos esenciales
    ref.watch(obrasProvider);

    // Escuchamos el contador de pendientes por si quieres mostrar un log
    // o debug en consola de cuántos quedan por subir
    ref.listen(pendientesOfflineProvider, (prev, next) {
      if (next.hasValue) {
        print(
          '--- [Estado Offline] Partes pendientes en cola: ${next.value} ---',
        );
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Gestión de Partes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
      // Opcional: Builder para mostrar un banner si no hay conexión
      builder: (context, child) {
        return Stack(children: [child!, const _NoConnectionBanner()]);
      },
    );
  }
}

/// Widget opcional para avisar visualmente que no hay internet
class _NoConnectionBanner extends ConsumerWidget {
  const _NoConnectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tieneConexion = ref.watch(conectividadProvider).valueOrNull ?? true;

    if (tieneConexion) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.redAccent,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Sin conexión - Los partes se guardarán en el móvil',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
