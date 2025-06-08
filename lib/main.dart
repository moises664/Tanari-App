// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/screens/login/welcome_screen.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart'; // ¡Asegúrate de importar tu HomeScreen!

const appTitle = 'TAnaRi';
const String SUPABASE_URL = 'https://pfhteyhxvetjhaitlucx.supabase.co';
const String SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmaHRleWh4dmV0amhhaXRsdWN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwNzMxMjcsImV4cCI6MjA2NDY0OTEyN30.93Ty5Z9JdUhHGFAgJkRW2yina0-WKkahqPC6QY9WTHk';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase con tu URL y clave anónima
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    debug:
        true, // Esto te mostrará logs de Supabase en la consola de depuración
  );

  // Inyecta el AuthService. Ahora que lo tienes, usaremos su estado.
  Get.put(AuthService());

  // Inicialización controlada de controladores
  await _initializeApp();

  runApp(const MyApp());
}

final _logger = Logger('Main');

Future<void> _initializeApp() async {
  try {
    // Inyecta BleController.
    // Usaremos Get.putAsync porque tu BleController probablemente necesita
    // inicialización asíncrona o puede ser un poco pesado al inicio.
    await Get.putAsync<BleController>(() async => BleController());
  } catch (e) {
    _logger.severe('Error initializing controllers', e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtiene la instancia de AuthService.
    // Esto es seguro porque ya lo "pusimos" con Get.put en main().
    final authService = Get.find<AuthService>();

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      // --- MODIFICACIÓN IMPORTANTE AQUÍ ---
      // Usamos Obx para escuchar los cambios en el estado de autenticación
      // del AuthService y decidir qué pantalla mostrar.
      home: Obx(() {
        // Muestra una pantalla de carga mientras el estado de autenticación se resuelve.
        // Esto es importante para evitar parpadeos o errores si el usuario no ha iniciado sesión
        // y se intenta acceder a HomeScreen antes de que AuthService lo sepa.
        if (authService.isLoading.value) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (authService.currentUser.value == null) {
          // Si no hay usuario autenticado, muestra la pantalla de bienvenida
          return const WelcomeScreen();
        } else {
          // Si hay un usuario autenticado, muestra la pantalla principal
          return const HomeScreen();
        }
      }),
      // Puedes definir rutas aquí si usas Get.toNamed()
      getPages: [
        GetPage(name: '/welcome', page: () => const WelcomeScreen()),
        // Asegúrate de que las rutas para SignInScreen, SignUpScreen, etc.
        // estén definidas aquí si planeas usar Get.toNamed() para ellas.
        // Si usas Get.to(() => const MyScreen()), no necesitas definirlas aquí.
        // Por ahora, Get.to() directo está bien.
        GetPage(
            name: '/home',
            page: () => const HomeScreen()), // Ruta para HomeScreen
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
