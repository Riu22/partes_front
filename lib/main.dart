import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <--- Añade este import
import 'config/router.dart';

void main() async {
  // 1. Asegura que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa Supabase antes de lanzar la App
  // Sustituye con tu URL y tu ANON KEY real
  await Supabase.initialize(
    url: 'http://localhost:8000',
    anonKey: 'TU_SUPABASE_ANON_KEY_AQUI',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Gestión de Partes',
      debugShowCheckedModeBanner: false, // Quita el banner de debug
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
