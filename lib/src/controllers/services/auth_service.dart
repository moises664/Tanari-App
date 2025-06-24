import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';

/// Logger para el servicio de autenticación
final _logger = Logger('AuthService');

/// Servicio de autenticación que maneja el ciclo de vida de la sesión del usuario
///
/// Mejoras clave:
///   - Retorno booleano en updatePassword para indicar éxito
///   - Mensajes de éxito eliminados del método updatePassword
///   - Manejo robusto de errores con logging detallado
///   - Sincronización completa con perfil de usuario
///   - Navegación contextual segura
class AuthService extends GetxService {
  // Dependencias --------------------------------------------------------------
  final SupabaseClient _supabaseClient = Get.find<SupabaseClient>();

  // Estado --------------------------------------------------------------------
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;
  bool _appInitializationComplete = false;
  bool _shouldNavigateToRecovery = false;

  // Ciclo de vida -------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _logger.info('AuthService inicializado');
    _checkInitialSession();
    _setupAuthListener();
  }

  /// Verifica si hay una sesión activa al iniciar el servicio
  Future<void> _checkInitialSession() async {
    final session = _supabaseClient.auth.currentSession;
    if (session != null) {
      _logger.info('Sesión inicial detectada: ${session.user.email}');
      currentUser.value = session.user;

      // Carga el perfil del usuario de forma asíncrona
      try {
        await Get.find<UserProfileService>()
            .fetchOrCreateUserProfile(session.user.id);
        _logger.info('Perfil cargado para sesión inicial');
      } catch (e, stackTrace) {
        _logger.severe(
            'Error cargando perfil en sesión inicial', e, stackTrace);
      }
    }
  }

  // Métodos principales -------------------------------------------------------
  void _setupAuthListener() {
    _supabaseClient.auth.onAuthStateChange.listen(_handleAuthStateChange);
  }

  /// Maneja eventos de cambio de estado de autenticación
  Future<void> _handleAuthStateChange(AuthState data) async {
    final event = data.event;
    final session = data.session;
    _logger.info('AuthChangeEvent: $event | User: ${session?.user.email}');

    final userProfileService = Get.find<UserProfileService>();

    // Manejar evento de recuperación de contraseña
    if (event == AuthChangeEvent.passwordRecovery) {
      _logger.info('Evento de recuperación detectado');
      _shouldNavigateToRecovery = true;
      currentUser.value = session?.user;

      // Carga el perfil del usuario
      if (session != null) {
        try {
          await userProfileService.fetchOrCreateUserProfile(session.user.id);
          _logger.info('Perfil cargado para flujo de recuperación');
        } catch (e, stackTrace) {
          _logger.severe(
              'Error cargando perfil en recuperación', e, stackTrace);
        }
      }

      if (_appInitializationComplete) {
        _navigateToChangePassword();
      }
    }

    // Manejar eventos principales
    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.initialSession) {
      await _handleSignedIn(session, userProfileService);
    } else if (event == AuthChangeEvent.signedOut) {
      await _handleSignedOut(userProfileService);
    } else if (event == AuthChangeEvent.userUpdated) {
      await _handleUserUpdated(session, userProfileService);
    } else {
      _logger.fine('Evento no manejado: $event');
    }
  }

  /// Maneja eventos de inicio de sesión
  Future<void> _handleSignedIn(
    Session? session,
    UserProfileService profileService,
  ) async {
    if (session == null) return;

    currentUser.value = session.user;

    // Carga el perfil del usuario
    try {
      await profileService.fetchOrCreateUserProfile(session.user.id);
      _logger.info('Perfil cargado después de inicio de sesión');
    } catch (e, stackTrace) {
      _logger.severe(
          'Error cargando perfil después de inicio de sesión', e, stackTrace);
    }

    if (_appInitializationComplete) {
      _navigateToHome();
    }
  }

  /// Maneja eventos de cierre de sesión
  Future<void> _handleSignedOut(UserProfileService profileService) async {
    currentUser.value = null;
    profileService.clearUserProfile();

    if (Get.currentRoute != Routes.signIn) {
      _navigateToSignIn();
    }
  }

  /// Maneja actualizaciones de perfil de usuario
  Future<void> _handleUserUpdated(
    Session? session,
    UserProfileService profileService,
  ) async {
    if (session == null) return;

    currentUser.value = session.user;

    // Actualiza el perfil del usuario
    try {
      await profileService.fetchOrCreateUserProfile(session.user.id);
      _logger.info('Perfil actualizado después de userUpdated');
    } catch (e, stackTrace) {
      _logger.severe('Error actualizando perfil en userUpdated', e, stackTrace);
    }
  }

  // Navegación ----------------------------------------------------------------
  void _navigateToHome() {
    // Limpiar toda la pila de navegación antes de ir al home
    Get.offAllNamed(Routes.home);
    _logger.info('Navegando a Home');
  }

  void _navigateToSignIn() {
    // Limpiar toda la pila de navegación antes de ir a login
    Get.offAllNamed(Routes.signIn);
    _logger.info('Navegando a SignIn');
  }

  void _navigateToChangePassword() {
    _shouldNavigateToRecovery = false;
    // Limpiar pila de navegación antes de cambiar contraseña
    Get.offAllNamed(
      Routes.changePassword,
      arguments: {'fromRecovery': true},
    );
    _logger.info('Navegando a ChangePassword (recuperación)');
  }

  // API pública ---------------------------------------------------------------
  /// Completa la inicialización de la app y navega a la pantalla adecuada
  void completeAppInitialization() {
    _appInitializationComplete = true;

    if (_shouldNavigateToRecovery) {
      _navigateToChangePassword();
    } else if (currentUser.value != null) {
      _navigateToHome();
    } else {
      Get.offAllNamed(Routes.welcome);
    }
  }

  /// Inicia sesión con correo electrónico y contraseña
  Future<void> signIn(String email, String password) async {
    isLoading.value = true;
    try {
      _logger.info('Inicio de sesión para: $email');
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthException('Usuario no encontrado');
      }

      _showSuccessSnackbar('Inicio Exitoso', '¡Bienvenido de nuevo!');
    } on AuthException catch (e) {
      _handleAuthError('Error en inicio de sesión', e);
    } catch (e, stackTrace) {
      _handleGenericError(
          'Error inesperado en inicio de sesión', e, stackTrace);
    } finally {
      isLoading.value = false;
    }
  }

  /// Registra un nuevo usuario
  Future<void> signUp(String email, String password, String username) async {
    isLoading.value = true;
    try {
      _logger.info('Registrando usuario: $email');
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (response.user != null) {
        await Get.find<UserProfileService>()
            .fetchOrCreateUserProfile(response.user!.id);
        _showSuccessSnackbar(
          'Registro Exitoso',
          '¡Bienvenido! Verifica tu correo',
        );
      } else {
        throw AuthException('No se pudo crear el usuario');
      }
    } on AuthException catch (e) {
      _handleAuthError('Error en registro', e);
    } catch (e, stackTrace) {
      _handleGenericError('Error inesperado en registro', e, stackTrace);
    } finally {
      isLoading.value = false;
    }
  }

  /// Cierra la sesión actual
  Future<void> signOut() async {
    isLoading.value = true;
    try {
      _logger.info('Cerrando sesión');
      await _supabaseClient.auth.signOut();
    } on AuthException catch (e) {
      _handleAuthError('Error al cerrar sesión', e);
    } catch (e, stackTrace) {
      _handleGenericError('Error inesperado al cerrar sesión', e, stackTrace);
    } finally {
      isLoading.value = false;
    }
  }

  /// Envía correo de recuperación de contraseña
  Future<void> sendPasswordRecoveryEmail(String email) async {
    isLoading.value = true;
    try {
      _logger.info('Enviando correo a: $email');
      await _supabaseClient.auth.resetPasswordForEmail(
        email,
        redirectTo: 'tanariapp://reset-password/',
      );

      _showSuccessSnackbar(
        'Correo Enviado',
        'Instrucciones enviadas a $email',
      );
    } on AuthException catch (e) {
      _handleAuthError('Error en recuperación', e);
    } catch (e, stackTrace) {
      _handleGenericError('Error inesperado en recuperación', e, stackTrace);
    } finally {
      isLoading.value = false;
    }
  }

  /// Actualiza la contraseña del usuario
  ///
  /// Devuelve `true` si la actualización fue exitosa, `false` en caso de error
  Future<bool> updatePassword(String newPassword) async {
    isLoading.value = true;
    try {
      _logger.info('Actualizando contraseña para: ${currentUser.value?.email}');
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        // Éxito: no mostramos snackbar aquí, lo maneja la UI
        _logger.info('Contraseña actualizada exitosamente');
        return true;
      } else {
        throw AuthException('No se pudo actualizar la contraseña.');
      }
    } on AuthException catch (e) {
      _handleAuthError('Error al actualizar contraseña', e);
      return false;
    } catch (e, stackTrace) {
      _handleGenericError(
          'Error inesperado al actualizar contraseña', e, stackTrace);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Helpers -------------------------------------------------------------------
  /// Muestra un snackbar de éxito
  void _showSuccessSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  /// Maneja errores de autenticación específicos
  void _handleAuthError(String context, AuthException e) {
    _logger.severe('$context: ${e.message}', e);
    Get.snackbar(
      'Error de Autenticación',
      e.message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  /// Maneja errores genéricos inesperados
  void _handleGenericError(String context, dynamic e, StackTrace s) {
    _logger.severe('$context: $e', e, s);
    Get.snackbar(
      'Error Inesperado',
      'Por favor intente nuevamente',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }
}
