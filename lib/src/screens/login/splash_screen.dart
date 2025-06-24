import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/core/app_colors.dart';

/// Pantalla de presentación con manejo mejorado de inicialización
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _logger = Logger('_SplashScreenState');

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Secuencia de inicialización mejorada
  Future<void> _initializeApp() async {
    // Espera a que el framework esté listo
    await Future.delayed(Duration.zero);

    // Espera adicional para mostrar el splash
    await Future.delayed(const Duration(seconds: 1));

    final authService = Get.find<AuthService>();

    // Verifica si hay una sesión activa y carga el perfil
    if (authService.currentUser.value != null) {
      try {
        await Get.find<UserProfileService>()
            .fetchOrCreateUserProfile(authService.currentUser.value!.id);
        _logger.info('Perfil cargado desde SplashScreen');
      } catch (e) {
        _logger.severe('Error cargando perfil en SplashScreen', e);
      }
    }

    authService.completeAppInitialization();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
