import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/router.dart';
import 'providers/sync_provider.dart';
import 'providers/obras_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("Configuración cargada desde .env");
  } catch (e) {
    print("Usando configuración por defecto (No se encontró .env)");
  }

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
    ref.watch(syncProvider);
    ref.watch(obrasProvider);
    ref.watch(obrasActivasProvider);

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
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final width = mq.size.width;

        final double scale = switch (width) {
          > 2200 => 1.45,
          > 1600 => 1.25,
          > 1024 => 1.10,
          _ => 1.00,
        };

        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: Stack(children: [child!, const _NoConnectionBanner()]),
        );
      },
    );
  }
}

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
            'Sin conexión - Modo Offline activo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
