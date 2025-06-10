import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart'; // Importar para SnackBar

final _logger = Logger('AuthService');

class AuthService extends GetxController {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  final _currentUser = Rx<User?>(null); // Observable para el usuario actual
  final _appInitializationComplete = false.obs;
  final _isLoading = false.obs;

  User? get currentUser => _currentUser.value;
  bool get appInitializationComplete => _appInitializationComplete.value;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    _logger.info('AuthService: Initializing...');

    _supabaseClient.auth.onAuthStateChange.listen((data) {
      _logger.info('AuthService: Auth event received: ${data.event}');
      _onAuthChange(data);
    });
  }

  void setAppInitializationComplete(bool status) {
    _appInitializationComplete.value = status;
    _logger.info(
        'AuthService: Application initialization marked as ${status ? "complete" : "incomplete"}.');
  }

  void _onAuthChange(AuthState data) {
    _logger.info(
        'AuthService: Auth event: ${data.event}, User: ${data.session?.user?.email ?? 'N/A'}');
    final AuthChangeEvent event = data.event;
    final Session? session = data.session;

    _currentUser.value = session?.user;

    if (_appInitializationComplete.value &&
        event != AuthChangeEvent.initialSession) {
      switch (event) {
        case AuthChangeEvent.signedIn:
          Get.offAllNamed('/home');
          Get.snackbar('Bienvenido',
              'Has iniciado sesión como ${_currentUser.value?.email}',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green,
              colorText: Colors.white);
          break;
        case AuthChangeEvent.signedOut:
          // *** CAMBIO CRÍTICO AQUÍ: Mostrar SnackBar ANTES de la navegación offAllNamed ***
          Get.snackbar('Adiós', 'Has cerrado sesión',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
              colorText: Colors.white);
          // Opcional: Pequeño retraso para que el SnackBar tenga tiempo de montarse.
          // await Future.delayed(const Duration(milliseconds: 100));
          Get.offAllNamed('/welcome');
          break;
        case AuthChangeEvent.passwordRecovery:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.mfaChallengeVerified:
          _logger.info(
              'AuthService: Evento de autenticación (${event.name}) manejado, no se requiere navegación global aquí.');
          break;
        case AuthChangeEvent.initialSession:
          _logger.warning(
              'AuthService: AuthChangeEvent.initialSession recibido, pero la navegación inicial es responsabilidad de SplashScreen.');
          break;
      }
    } else {
      _logger.warning(
          'AuthService: Evento (${event.name}) recibido. La navegación está en espera porque la inicialización de la app no está completa o es un initialSession.');
    }
  }

  // --- Tus métodos de autenticación (signIn, signUp, signOut, recoverPassword) ---
  // No hay cambios en estos métodos ya que se manejan correctamente con _isLoading.

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _isLoading.value = true;
    try {
      final AuthResponse response =
          await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _logger
          .info('AuthService: Sign-in successful for ${response.user?.email}');
    } on AuthException catch (e) {
      _logger.warning('AuthService: Sign-in error: ${e.message}');
      Get.snackbar('Error de inicio de sesión', e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      rethrow;
    } catch (e) {
      _logger.severe('AuthService: Unexpected sign-in error: $e');
      Get.snackbar(
          'Error inesperado', 'Ocurrió un error inesperado al iniciar sesión',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    _isLoading.value = true;
    try {
      final AuthResponse response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      _logger
          .info('AuthService: Sign-up successful for ${response.user?.email}');
      Get.snackbar('Registro Exitoso',
          'Por favor, verifica tu correo electrónico para confirmar tu cuenta.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } on AuthException catch (e) {
      _logger.warning('AuthService: Sign-up error: ${e.message}');
      Get.snackbar('Error de registro', e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      rethrow;
    } catch (e) {
      _logger.severe('AuthService: Unexpected sign-up error: $e');
      Get.snackbar(
          'Error inesperado', 'Ocurrió un error inesperado al registrarse',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    _isLoading.value = true;
    try {
      await _supabaseClient.auth.signOut();
      _logger.info('AuthService: User signed out.');
      // La navegación y el snackbar se manejan en _onAuthChange a través del evento signedOut.
    } catch (e) {
      _logger.severe('AuthService: Error signing out: $e');
      Get.snackbar('Error al cerrar sesión',
          'No se pudo cerrar sesión. Intenta de nuevo.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> recoverPassword(String email) async {
    _isLoading.value = true;
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
      Get.snackbar('Correo Enviado',
          'Se ha enviado un correo electrónico con instrucciones para restablecer tu contraseña.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
      _logger.info('AuthService: Password recovery email sent to $email');
    } on AuthException catch (e) {
      _logger.warning('AuthService: Password recovery error: ${e.message}');
      Get.snackbar('Error', e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      rethrow;
    } catch (e) {
      _logger.severe('AuthService: Unexpected password recovery error: $e');
      Get.snackbar('Error inesperado',
          'Ocurrió un error al intentar recuperar la contraseña',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }
}
