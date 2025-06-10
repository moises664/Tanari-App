import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart'; // Asegúrate de importar tu BleController

final _logger = Logger('SplashScreen'); // Logger para esta pantalla

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = Get.find<AuthService>();

  @override
  void initState() {
    super.initState();
    // Es crucial ejecutar la lógica de inicialización *después* de que el primer frame
    // del widget ha sido dibujado, para asegurar que el contexto de GetX esté completamente listo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      _logger.info(
          'SplashScreen: Starting app initialization and service binding...');

      // 1. Inyectar BleController si aún no está registrado.
      // Usamos Get.putAsync para asegurar que cualquier inicialización async en BleController
      // (como permisos de Bluetooth) se complete antes de que la app avance.
      // Esto resuelve el problema de "BleController" not found.
      if (!Get.isRegistered<BleController>()) {
        _logger.info(
            'SplashScreen: BleController not registered. Putting it now...');
        await Get.putAsync<BleController>(() async => BleController());
        _logger.info('SplashScreen: BleController initialized successfully.');
      } else {
        _logger.info('SplashScreen: BleController already registered.');
      }

      // 2. Dar una señal al AuthService de que la inicialización del framework está completa.
      // Esto desbloqueará la navegación automática en AuthService para futuros eventos
      // (como un login/logout manual DESPUÉS del inicio de la app),
      // pero la navegación inicial la controlamos aquí en SplashScreen.
      _authService.setAppInitializationComplete(true);
      _logger.info(
          'SplashScreen: Signaled AuthService that app is ready for navigation.');

      // 3. Determinar la navegación inicial basada en el estado de autenticación actual.
      // Leemos el valor actual del usuario.
      final user = _authService.currentUser?.value;

      // Una pequeña espera adicional para asegurar que GetX haya procesado todo
      // y el navegador esté en su estado más estable para el offAllNamed.
      await Future.delayed(const Duration(
          milliseconds: 100)); // Puedes ajustar esto si aún hay problemas.

      if (user != null) {
        _logger.info(
            'SplashScreen: User found: ${user.email}. Navigating to /home.');
        Get.offAllNamed(
            '/home'); // Navegar a la pantalla principal si hay sesión
      } else {
        _logger.info('SplashScreen: No user found. Navigating to /welcome.');
        Get.offAllNamed(
            '/welcome'); // Navegar a la pantalla de bienvenida si no hay sesión
      }
    } catch (e, s) {
      _logger.severe('SplashScreen: Error during app initialization: $e', e, s);
      // Mostrar un Snackbar o un diálogo de error al usuario
      Get.snackbar(
        'Error Crítico',
        'No se pudo inicializar la aplicación. Por favor, reinicia. ($e)',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      // En caso de error crítico, al menos intentar ir a la pantalla de bienvenida como fallback
      Get.offAllNamed('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(), // Indicador de carga visual
            SizedBox(height: 20),
            Text('Cargando aplicación...'), // Texto de carga
          ],
        ),
      ),
    );
  }
}

extension on User? {
  get value => null;
}
