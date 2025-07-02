import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart'; // Importa las rutas para navegación

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _logger = Logger('SplashScreen');
  int _retryCount = 0;
  final int _maxRetries = 5; // Máximo de reintentos

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // Verificar si AuthService está registrado
      if (Get.isRegistered<AuthService>()) {
        final authService = Get.find<AuthService>();
        final userProfileService = Get.find<UserProfileService>();

        // Verificar sesión activa y cargar perfil
        if (authService.currentUser.value != null) {
          await userProfileService
              .fetchOrCreateUserProfile(authService.currentUser.value!.id);
          _logger.info('Perfil cargado exitosamente');
        }

        // Navegar a la pantalla adecuada
        authService.completeAppInitialization();
      } else {
        // Reintentar si no está registrado
        _retryCount++;
        if (_retryCount <= _maxRetries) {
          _logger.warning(
              'AuthService no disponible. Reintento $_retryCount/$_maxRetries');
          _initializeApp(); // Llamada recursiva
        } else {
          _handleInitializationError();
        }
      }
    } catch (e, stackTrace) {
      _logger.severe('Error en inicialización', e, stackTrace);
      _handleInitializationError();
    }
  }

  void _handleInitializationError() {
    _logger.warning('Navegando a pantalla de bienvenida por fallo');
    Get.offAllNamed(Routes.welcome);
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
