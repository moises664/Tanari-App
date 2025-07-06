// AUTH SERVICE

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:app_links/app_links.dart'; // Para manejar deep links

// Logger para la clase AuthService
final _logger = Logger('AuthService');

/// [AuthService] es un servicio de GetX que gestiona toda la lógica de autenticación
/// con Supabase, incluyendo el registro, inicio de sesión, cierre de sesión,
/// recuperación de contraseña y el manejo de deep links.
///
/// Este servicio interactúa con [UserProfileService] para asegurar que el perfil
/// del usuario se cargue o se cree (si es necesario, como fallback) después de la autenticación.
/// La creación inicial del perfil para nuevos registros se delega a un trigger de Supabase
/// en el lado del servidor para garantizar la consistencia y evitar duplicidades.
class AuthService extends GetxService {
  late final SupabaseClient _supabaseClient;
  late final UserProfileService _userProfileService;
  late final AppLinks _appLinks; // Instancia para manejar deep links
  StreamSubscription<Uri>?
      _linkSubscription; // Suscripción a eventos de deep links

  // Observables para el estado de autenticación y carga
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoading = false.obs;

  // Flags para controlar el flujo de inicialización y navegación de recuperación
  bool _appInitializationComplete = false;
  bool _shouldNavigateToRecovery = false;

  /// Getter para verificar si el usuario está autenticado.
  bool get isAuthenticated => currentUser.value != null;

  @override
  void onInit() {
    super.onInit();
    _logger.info('AuthService inicializando...');

    // Obtener las instancias de SupabaseClient y UserProfileService inyectadas por GetX
    _supabaseClient = Get.find<SupabaseClient>();
    _userProfileService = Get.find<UserProfileService>();
    // Inicializar AppLinks. No se usa Get.find() aquí porque AppLinks no es un servicio inyectado globalmente
    // a menos que se haya hecho un Get.put(AppLinks()) en main.dart.
    // Si AppLinks no es un servicio de GetX, se debe inicializar directamente.
    _appLinks = AppLinks();
    _logger.info('AuthService dependencias encontradas.');

    // Inicializar sistemas de deep links y configurar el listener de autenticación
    _initDeepLinks();
    _setupAuthListener();
  }

  @override
  void onClose() {
    // Cancelar la suscripción a deep links para evitar fugas de memoria
    _linkSubscription?.cancel();
    _logger.info('AuthService cerrado.');
    super.onClose();
  }

  /// Inicializa el sistema de deep links para capturar enlaces al inicio de la app
  /// y mientras la app está en ejecución.
  Future<void> _initDeepLinks() async {
    try {
      // Manejar el enlace inicial que pudo haber abierto la aplicación
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }

      // Escuchar por nuevos enlaces mientras la aplicación está en uso
      _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
      _logger.info('Deep Links listener inicializado');
    } catch (e, stackTrace) {
      _logger.severe('Error inicializando deep links', e, stackTrace);
      Get.snackbar(
        'Error Técnico',
        'Problema con el manejo de enlaces profundos',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Procesa un deep link URI para determinar la acción a realizar (ej. recuperación de contraseña).
  void _handleDeepLink(Uri uri) {
    _logger.info('Deep Link recibido: ${uri.toString()}');

    // Manejar enlaces de restablecimiento de contraseña
    if (uri.scheme == 'tanari' && uri.host == 'reset-password') {
      handlePasswordResetDeepLink(uri);
    }
    // Manejar enlaces de callback de autenticación (ej: tanari://auth/callback#access_token=xxx)
    else if (uri.scheme == 'tanari' &&
        uri.host == 'auth' &&
        uri.path == '/callback') {
      handleAuthCallbackDeepLink(uri);
    } else {
      _logger.warning('Deep link no reconocido: $uri');
    }
  }

  /// Configura un listener para los cambios de estado de autenticación de Supabase.
  /// Este es el punto central para reaccionar a los eventos de inicio/cierre de sesión
  /// y actualizaciones de usuario.
  void _setupAuthListener() {
    _supabaseClient.auth.onAuthStateChange.listen(_handleAuthStateChange);
    _logger.info('Auth state change listener configurado.');
  }

  /// Maneja los diferentes eventos de cambio de estado de autenticación de Supabase.
  ///
  /// Parámetros:
  /// - `data`: Un objeto `AuthState` que contiene el evento y la sesión actual.
  Future<void> _handleAuthStateChange(AuthState data) async {
    final event = data.event;
    final session = data.session;
    _logger.info('AuthChangeEvent: $event | User: ${session?.user.email}');

    // Si no hay sesión o token de acceso, intentar recuperar la sesión.
    // Esto es crucial para manejar sesiones persistentes o tokens expirados.
    if (session?.accessToken == null && session?.refreshToken != null) {
      _logger.warning('Sesión sin accessToken, intentando recuperar...');
      try {
        await _supabaseClient.auth.recoverSession(session!.refreshToken!);
        _logger.info('Sesión recuperada exitosamente');
        // El evento de sesión recuperada disparará nuevamente _handleAuthStateChange con la nueva sesión.
        return;
      } catch (e) {
        _logger.severe('Error al recuperar sesión', e);
        // Si la recuperación falla, se considera como un cierre de sesión.
        await _handleSignedOut();
        return;
      }
    }

    switch (event) {
      case AuthChangeEvent.passwordRecovery:
        _logger.info('Evento de recuperación de contraseña detectado.');
        _shouldNavigateToRecovery = true;
        currentUser.value = session?.user; // Actualizar usuario actual

        if (session != null) {
          try {
            await _loadUserProfile(); // Cargar perfil si hay sesión
            _logger.info('Perfil cargado para flujo de recuperación.');
          } catch (e, stackTrace) {
            _logger.severe(
                'Error cargando perfil en recuperación: $e', e, stackTrace);
          }
        }
        // Navegar a la pantalla de cambio de contraseña si la inicialización está completa.
        if (_appInitializationComplete) {
          _navigateToChangePassword();
        }
        break;

      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
        _logger.info('Evento de inicio de sesión o sesión inicial detectado.');
        await _handleSignedIn(session);
        break;

      case AuthChangeEvent.signedOut:
        _logger.info('Evento de cierre de sesión detectado.');
        await _handleSignedOut();
        break;

      case AuthChangeEvent.userUpdated:
        _logger.info('Evento de actualización de usuario detectado.');
        await _handleUserUpdated(session);
        break;

      default:
        _logger.fine('Evento de autenticación no manejado: $event');
    }
  }

  /// Maneja las acciones a realizar cuando un usuario inicia sesión o se establece una sesión inicial.
  Future<void> _handleSignedIn(Session? session) async {
    if (session == null) {
      _logger.warning('Intento de manejar signedIn con sesión nula.');
      return;
    }

    currentUser.value = session.user; // Actualizar el usuario observable
    await _loadUserProfile(); // Cargar el perfil del usuario

    Get.snackbar(
      "Inicio de Sesión Exitoso",
      "¡Bienvenido de nuevo!",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.backgroundWhite,
    );

    // Navegar a la pantalla principal solo si la inicialización de la app está completa.
    if (_appInitializationComplete) {
      _navigateToHome();
    }
  }

  /// Maneja las acciones a realizar cuando un usuario cierra sesión.
  Future<void> _handleSignedOut() async {
    currentUser.value = null; // Limpiar el usuario observable
    _userProfileService.clearUserProfile(); // Limpiar el perfil en el servicio
    _navigateToSignIn(); // Navegar a la pantalla de inicio de sesión
  }

  /// Maneja las acciones a realizar cuando la información del usuario se actualiza.
  Future<void> _handleUserUpdated(Session? session) async {
    if (session == null) return;

    currentUser.value = session.user; // Actualizar el usuario observable
    await _loadUserProfile(); // Recargar el perfil para reflejar los cambios
  }

  // =========================== NAVEGACIÓN ===========================

  /// Navega a la pantalla principal de la aplicación.
  void _navigateToHome() {
    Get.offAllNamed(Routes.home);
    _logger.info('Navegando a Home.');
  }

  /// Navega a la pantalla de inicio de sesión.
  void _navigateToSignIn() {
    Get.offAllNamed(Routes.signIn);
    _logger.info('Navegando a SignIn.');
  }

  /// Navega a la pantalla de bienvenida.
  void _navigateToWelcome() {
    Get.offAllNamed(Routes.welcome);
    _logger.info('Navegando a Welcome.');
  }

  /// Navega a la pantalla de cambio de contraseña, indicando si es un flujo de recuperación.
  void _navigateToChangePassword() {
    _shouldNavigateToRecovery = false; // Resetear el flag después de usarlo
    Get.offAllNamed(
      Routes.changePassword,
      arguments: {'fromRecovery': true},
    );
    _logger.info('Navegando a ChangePassword (flujo de recuperación).');
  }

  // ======================== API PÚBLICA ============================

  /// Marca la inicialización de la aplicación como completa y maneja la navegación inicial.
  /// Este método es llamado desde [main.dart] después de que todas las dependencias
  /// han sido inyectadas y la UI está lista.
  Future<void> completeAppInitialization() async {
    _logger.info('Completando inicialización de la aplicación...');
    try {
      // Si ya hay un usuario autenticado al momento de completar la inicialización,
      // asegurar que su perfil esté cargado.
      if (currentUser.value != null) {
        _logger
            .info('Usuario autenticado detectado: ${currentUser.value!.email}');
        await _loadUserProfile();
      } else {
        _logger
            .info('No hay usuario autenticado al final de la inicialización.');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error en la fase final de inicialización de la app: $e',
          e, stackTrace);
      rethrow; // Propagar el error para que la pantalla de error de main.dart lo capture.
    } finally {
      _appInitializationComplete =
          true; // Marcar la inicialización como completa.
    }

    // Manejo de navegación post-inicialización, especialmente para deep links
    // que podrían haber establecido _shouldNavigateToRecovery.
    if (_shouldNavigateToRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToChangePassword();
      });
    } else if (isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToHome();
      });
    } else {
      // Si no está autenticado y no hay recuperación pendiente, ir a la pantalla de bienvenida.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToWelcome(); // CAMBIO CLAVE AQUÍ: Navegar a WelcomeScreen
      });
    }
  }

  /// Carga el perfil del usuario actualmente autenticado utilizando [UserProfileService].
  /// Este método se llama internamente después de eventos de autenticación.
  Future<void> _loadUserProfile() async {
    if (currentUser.value != null) {
      await _userProfileService.fetchOrCreateUserProfile(currentUser.value!.id);
    }
  }

  /// Inicia sesión de un usuario con su correo electrónico y contraseña.
  ///
  /// Parámetros:
  /// - `email`: Correo electrónico del usuario.
  /// - `password`: Contraseña del usuario.
  Future<void> signIn(String email, String password) async {
    isLoading.value = true;
    int attempt = 0;
    const int maxAttempts = 3;
    try {
      while (attempt < maxAttempts) {
        try {
          _logger
              .info('Intento ${attempt + 1} de inicio de sesión para: $email');

          final response = await _supabaseClient.auth
              .signInWithPassword(
            email: email,
            password: password,
          )
              .timeout(const Duration(seconds: 60), onTimeout: () {
            throw AuthException('Tiempo de espera agotado al iniciar sesión.');
          });

          if (response.user == null) {
            throw AuthException(
                'Credenciales inválidas o usuario no encontrado.');
          }

          // Verificar si el perfil existe y crear si es necesario
          try {
            await _userProfileService
                .fetchOrCreateUserProfile(response.user!.id);
            _logger.info('Perfil del usuario cargado/creado exitosamente.');
          } catch (e, stackTrace) {
            _logger.severe(
                'Error al cargar o crear el perfil del usuario', e, stackTrace);
            throw AuthException('Error al inicializar el perfil de usuario');
          }

          _logger.info('Usuario ${response.user!.email} autenticado.');
          return;
        } on AuthException catch (e, stackTrace) {
          if (attempt == maxAttempts - 1) {
            _handleAuthError('Error en inicio de sesión', e, stackTrace);
          }
        } on TimeoutException catch (e) {
          _logger.warning('Timeout en intento ${attempt + 1}: $e');
          if (attempt == maxAttempts - 1) {
            rethrow;
          }
        } catch (e, stackTrace) {
          if (e.toString().contains('Connection reset by peer') ||
              e.toString().contains('SocketException')) {
            _logger.warning(
                'Error de conexión en intento ${attempt + 1}. Reintentando...');
          } else {
            _handleGenericError(
                'Error inesperado al iniciar sesión', e, stackTrace);
            rethrow;
          }
        }

        await Future.delayed(const Duration(seconds: 3));
        attempt++;
      }

      if (attempt == maxAttempts) {
        _handleAuthError(
          'Error persistente',
          AuthException(
              'No se pudo conectar al servidor después de $maxAttempts intentos.'),
          StackTrace.current,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Registra un nuevo usuario en Supabase Auth.
  /// La creación del perfil asociado en la tabla `public.profiles` se maneja
  /// automáticamente en el lado del servidor mediante un trigger de base de datos
  /// (`on_auth_user_created` que llama a `handle_new_user`).
  ///
  /// Parámetros:
  /// - `email`: El correo electrónico del nuevo usuario.
  /// - `password`: La contraseña del nuevo usuario.
  /// - `username`: El nombre de usuario deseado para el perfil.
  Future<void> signUp(String email, String password, String username) async {
    isLoading.value = true;
    try {
      _logger
          .info('Registrando usuario: $email con nombre de usuario: $username');

      // Paso 1: Registrar al usuario en Supabase Auth.
      // El 'username' se pasa en la metadata para que el trigger del servidor pueda acceder a él.
      final authResponse = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (authResponse.user == null) {
        throw AuthException(
            'Error al crear usuario en Supabase Auth. Usuario nulo en la respuesta.');
      }

      _logger.info(
          'Registro exitoso en Supabase Auth para ${authResponse.user!.email}.');
      _showSuccessSnackbar(
        'Registro Exitoso',
        '¡Hemos enviado un enlace de confirmación a tu correo electrónico! Por favor, verifica tu bandeja de entrada para completar el registro.',
      );

      // Redirigir al usuario a la pantalla de inicio de sesión para que complete la verificación.
      Get.offAllNamed(Routes.signIn);
    } on AuthException catch (e, stackTrace) {
      _handleAuthError('Error de autenticación al registrar', e, stackTrace);
    } on PostgrestException catch (e, stackTrace) {
      // Manejar errores específicos de la base de datos si ocurrieran (menos probable con el nuevo flujo).
      _handleDatabaseError(
          'Error de base de datos al registrar', e, stackTrace);
    } catch (e, stackTrace) {
      _handleGenericError('Error inesperado al registrar', e, stackTrace);
    } finally {
      isLoading.value = false; // Desactivar el indicador de carga.
    }
  }

  /// Cierra la sesión del usuario actualmente autenticado.
  Future<void> signOut() async {
    isLoading.value = true;
    try {
      _logger.info('Cerrando sesión para: ${currentUser.value?.email}');
      await _supabaseClient.auth.signOut();
      _logger.info('Sesión cerrada exitosamente.');
      Get.snackbar(
        'Sesión Cerrada',
        'Has cerrado sesión exitosamente.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.backgroundWhite,
        duration: const Duration(seconds: 3),
      );
      Get.offAllNamed(
          Routes.signIn); // Navegar a la pantalla de inicio de sesión.
    } on AuthException catch (e, stackTrace) {
      _handleAuthError('Error al cerrar sesión', e, stackTrace);
    } catch (e, stackTrace) {
      _handleGenericError('Error inesperado al cerrar sesión', e, stackTrace);
    } finally {
      isLoading.value = false;
    }
  }

  /// Envía un correo electrónico de recuperación de contraseña al usuario.
  ///
  /// Parámetros:
  /// - `email`: El correo electrónico del usuario que solicitó la recuperación.
  Future<void> sendPasswordRecoveryEmail(String email) async {
    isLoading.value = true;
    try {
      _logger.info('Intentando enviar email de recuperación a: $email');
      await _supabaseClient.auth.resetPasswordForEmail(
        email,
        redirectTo:
            'tanari://reset-password', // URL de deep link para la recuperación.
      );

      _showSuccessSnackbar(
        'Correo Enviado',
        'Hemos enviado un enlace de restablecimiento de contraseña a tu correo electrónico. Por favor, revisa tu bandeja de entrada.',
      );
      _logger.info('Email de recuperación enviado a $email.');
    } on AuthException catch (e, stackTrace) {
      _handleAuthError(
          'Error de autenticación al enviar recuperación', e, stackTrace);
    } catch (e, stackTrace) {
      _handleGenericError(
          'Error inesperado al enviar recuperación', e, stackTrace);
    } finally {
      isLoading.value = false;
    }
  }

  /// Actualiza la contraseña del usuario actualmente autenticado.
  ///
  /// Parámetros:
  /// - `newPassword`: La nueva contraseña a establecer.
  ///
  /// Retorna `true` si la actualización fue exitosa, `false` en caso contrario.
  Future<bool> updatePassword(String newPassword) async {
    isLoading.value = true;
    try {
      _logger.info('Intentando actualizar contraseña...');
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        _logger.info(
            'Contraseña actualizada con éxito para ${response.user!.email}.');
        return true;
      }
      _logger.warning(
          'Actualización de contraseña fallida: Usuario nulo en la respuesta.');
      return false;
    } on AuthException catch (e, stackTrace) {
      _handleAuthError(
          'Error de autenticación al actualizar contraseña', e, stackTrace);
      return false;
    } catch (e, stackTrace) {
      _handleGenericError(
          'Error inesperado al actualizar contraseña', e, stackTrace);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Maneja el deep link de restablecimiento de contraseña.
  /// Establece un flag para navegar a la pantalla de cambio de contraseña
  /// una vez que la inicialización de la app esté completa.
  void handlePasswordResetDeepLink(Uri uri) {
    _logger.info('Manejando reset password deep link: $uri');
    _shouldNavigateToRecovery =
        true; // Indicar que se debe navegar a la recuperación.

    // Si la aplicación ya está completamente inicializada, navegar inmediatamente.
    if (_appInitializationComplete) {
      _navigateToChangePassword();
    }
  }

  /// Maneja el deep link de callback de autenticación.
  /// Esto es típicamente usado después de la confirmación de email o inicio de sesión social.
  Future<void> handleAuthCallbackDeepLink(Uri uri) async {
    _logger.info('Manejando auth callback deep link: $uri');

    try {
      // Intenta obtener la sesión desde la URL del deep link.
      await _supabaseClient.auth.getSessionFromUrl(uri);
      _logger.info('Sesión procesada desde deep link exitosamente.');
      // El listener de onAuthStateChange se encargará de la navegación posterior.
    } catch (e, stackTrace) {
      _logger.severe(
          'Error procesando auth callback deep link: $e', e, stackTrace);
      Get.snackbar(
        'Error de Autenticación',
        'No se pudo completar el inicio de sesión desde el enlace.',
        backgroundColor: AppColors.error,
        colorText: AppColors.backgroundWhite,
      );
    }
  }

  // ============================= HELPERS =============================

  /// Muestra un snackbar de éxito con un título y mensaje.
  void _showSuccessSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.backgroundWhite,
      duration: const Duration(seconds: 4),
    );
  }

  /// Maneja y muestra errores específicos de autenticación ([AuthException]).
  void _handleAuthError(
      String context, AuthException e, StackTrace stackTrace) {
    _logger.severe('$context: ${e.message}', e, stackTrace);

    String displayMessage = e.message;
    if (e.message.contains("Email not confirmed")) {
      displayMessage =
          "Por favor, verifica tu correo electrónico para activar tu cuenta.";
    } else if (e.message.contains("Invalid login credentials")) {
      displayMessage =
          "Correo o contraseña incorrectos. Por favor, inténtalo de nuevo.";
    } else if (e.message.contains("User already registered")) {
      displayMessage = "Este correo electrónico ya está registrado.";
    } else if (e.message.contains("Network error")) {
      displayMessage = "Problema de conexión a la red. Verifica tu internet.";
    }

    Get.snackbar(
      'Error de Autenticación',
      displayMessage,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.backgroundWhite,
      duration: const Duration(seconds: 5),
    );
  }

  /// Maneja y muestra errores específicos de base de datos ([PostgrestException]).
  void _handleDatabaseError(
      String context, PostgrestException e, StackTrace stackTrace) {
    _logger.severe('$context: ${e.message}', e, stackTrace);

    String displayMessage = "Error en operación de base de datos.";
    if (e.message.contains("duplicate key")) {
      displayMessage =
          "Ya existe un registro con la misma clave. El nombre de usuario o email podría estar en uso.";
    } else if (e.message.contains("violates foreign key")) {
      displayMessage =
          "Error de relación de datos. Asegúrate de que los IDs referenciados existan.";
    } else if (e.message.contains("permission denied")) {
      displayMessage =
          "Permiso denegado. No tienes autorización para realizar esta operación.";
    }

    Get.snackbar(
      'Error de Base de Datos',
      displayMessage,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.backgroundWhite,
      duration: const Duration(seconds: 5),
    );
  }

  /// Maneja y muestra errores genéricos inesperados.
  void _handleGenericError(String context, dynamic e, StackTrace s) {
    _logger.severe('$context: $e', e, s);
    Get.snackbar(
      'Error Inesperado',
      'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo más tarde.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.backgroundWhite,
      duration: const Duration(seconds: 5),
    );
  }
}
