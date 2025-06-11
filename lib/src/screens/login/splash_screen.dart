// lib/src/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart'; // Asegúrate de importar el servicio de perfil
import 'package:tanari_app/src/core/app_colors.dart'; // Si lo usas para colores

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Inicializar servicios importantes aquí
    // El orden puede importar si un servicio depende de otro
    await Get.putAsync(() => Future.value(UserProfileService()),
        permanent: true); // Inicializa UserProfileService
    await Get.putAsync(() => Future.value(AuthService()),
        permanent: true); // Inicializa AuthService
    await Get.putAsync(() => Future.value(BleController()), permanent: true);

    // Esperar un breve momento para la estética y la inicialización de GetX
    await Future.delayed(const Duration(seconds: 1));

    // Notificar a AuthService que la inicialización de la aplicación ha terminado
    // AuthService se encargará de la navegación basada en el estado de autenticación
    Get.find<AuthService>().setAppInitializationComplete();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor:
          AppColors.backgroundPrimary, // O el color que desees para tu splash
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Puedes poner tu logo o algún indicador de carga aquí
            CircularProgressIndicator(color: AppColors.textPrimary),
            SizedBox(height: 20),
            Text(
              'Cargando Tanari...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
