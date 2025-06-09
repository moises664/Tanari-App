// lib/src/controllers/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart';
import 'package:tanari_app/src/screens/login/singin_screen.dart';
import 'package:tanari_app/src/screens/login/welcome_screen.dart'; // Asegúrate de importar WelcomeScreen

class AuthService extends GetxService {
  final _supabaseClient = Supabase.instance.client;
  final Logger _logger = Logger('AuthService');

  final Rx<User?> currentUser = Rx<User?>(null);
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _logger.fine('AuthService initialized');

    _initializeAuthStatus();

    _supabaseClient.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      currentUser.value = session?.user;

      // CORRECCIÓN para el Error 2: 'User: ${session?.user?.email}'
      _logger.info('Auth event: $event, User: ${session?.user?.email}');

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        // Corrección para el Error 3: Removido '!'
        if (session?.user != null) {
          await _getOrCreateUserProfile(session
              .user!); // Aquí aún necesitas '!' si _getOrCreateUserProfile espera un User no nulo
          // Asegúrate de que '/home' es una ruta definida en GetMaterialApp en main.dart
          if (Get.currentRoute != '/home') {
            Get.offAll(() => const HomeScreen());
          }
          Get.snackbar("Bienvenido", "Has iniciado sesión exitosamente!",
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green,
              colorText: Colors.white);
        } else {
          _logger.warning(
              'Sesión o usuario nulo a pesar del evento SignedIn/InitialSession. Redirigiendo a SignIn.');
          if (Get.currentRoute != '/signIn') {
            Get.offAll(() => const SignInScreen());
          }
        }
      }
      // REMOVIDA LA LÓGICA DE AuthChangeEvent.signedUp DE AQUÍ
      // YA QUE NO EXISTE EN TU VERSIÓN DE SUPABASE
      // Y se manejará directamente en el método signUp.
      else if (event == AuthChangeEvent.signedOut) {
        if (Get.currentRoute != '/signIn' && Get.currentRoute != '/welcome') {
          // Añadido '/welcome'
          Get.offAll(() =>
              const SignInScreen()); // O a WelcomeScreen si es tu punto de entrada
        }
        Get.snackbar("Adiós", "Has cerrado sesión.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white);
      } else if (event == AuthChangeEvent.userUpdated) {
        _logger.info('Perfil de usuario actualizado.');
      } else if (event == AuthChangeEvent.passwordRecovery) {
        _logger.info('Recuperación de contraseña iniciada.');
      }
      isLoading.value = false;
    });
  }

  // Resto del código de AuthService, incluyendo _getOrCreateUserProfile

  // Nuevo método para obtener o crear el perfil del usuario
  Future<void> _getOrCreateUserProfile(User user) async {
    try {
      final Map<String, dynamic>? profiles = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', user.id)
          .limit(1)
          .maybeSingle();

      if (profiles == null) {
        await _supabaseClient.from('profiles').insert({
          'id': user.id,
          'username': user.email?.split('@').first ?? 'UsuarioTanari',
          'is_admin': false,
        });
        _logger.info('Perfil de usuario creado para: ${user.email}');
      } else {
        _logger.info('Perfil de usuario ya existe para: ${user.email}');
      }
    } catch (e) {
      _logger.severe('Error al obtener o crear perfil de usuario: $e');
    }
  }

  void _initializeAuthStatus() {
    final user = _supabaseClient.auth.currentUser;
    currentUser.value = user;
    isLoading.value = false;
    _logger.fine('Initial auth status checked. User: ${user?.email}');
  }

  /// Registra un nuevo usuario con email, contraseña y un username.
  /// La creación del perfil ahora se maneja en _getOrCreateUserProfile.
  Future<void> signUp(String email, String password, String username) async {
    isLoading.value = true;
    try {
      final AuthResponse response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _logger.info(
            'Solicitud de registro enviada para: ${response.user?.email}');
        // Si tienes confirmación de correo (Email Confirm en Supabase Auth Settings):
        // Supabase NO iniciará sesión automáticamente.
        // Muestra un snackbar de "verifica tu correo" y redirige a la pantalla de bienvenida/login.
        Get.snackbar(
            "Registro Exitoso", "¡Revisa tu correo para verificar tu cuenta!",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blueAccent,
            colorText: Colors.white);
        _logger.info(
            'Usuario registrado, requiere verificación de correo. Redirigiendo a WelcomeScreen.');
        if (Get.currentRoute != '/welcome') {
          Get.offAll(() => const WelcomeScreen());
        }
      } else {
        _logger.warning('Respuesta de registro sin usuario válido.');
        // Esto puede pasar si el registro falló por alguna razón que no lanzó una AuthException.
        // El snackbar de error ya lo maneja el catch.
      }
    } on AuthException catch (e) {
      _logger.severe('Error de registro: ${e.message}');
      Get.snackbar("Error de Registro", e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } catch (e) {
      _logger.severe('Error inesperado de registro: $e');
      Get.snackbar("Error de Registro", "Ocurrió un error inesperado.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// Inicia sesión con email y contraseña.
  Future<void> signIn(String email, String password) async {
    isLoading.value = true;
    try {
      await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // La lógica de snackbar y redirección se maneja en el listener onAuthStateChange (AuthChangeEvent.signedIn)
    } on AuthException catch (e) {
      _logger.severe('Error de inicio de sesión: ${e.message}');
      Get.snackbar("Error de Inicio de Sesión", e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } catch (e) {
      _logger.severe('Error inesperado de inicio de sesión: $e');
      Get.snackbar("Error de Inicio de Sesión", "Ocurrió un error inesperado.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// Cierra la sesión del usuario actual.
  Future<void> signOut() async {
    isLoading.value = true;
    try {
      await _supabaseClient.auth.signOut();
      // La lógica de snackbar y redirección se maneja en el listener onAuthStateChange (AuthChangeEvent.signedOut)
    } on AuthException catch (e) {
      _logger.severe('Error al cerrar sesión: ${e.message}');
      Get.snackbar("Error al Cerrar Sesión", e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } catch (e) {
      _logger.severe('Error inesperado al cerrar sesión: $e');
      Get.snackbar("Error al Cerrar Sesión", "Ocurrió un error inesperado.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// Solicita un restablecimiento de contraseña para el email dado.
  /// Envía un enlace al correo electrónico del usuario.
  Future<void> resetPasswordForEmail(String email) async {
    isLoading.value = true;
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
      Get.snackbar("Revisa tu Correo",
          "Se ha enviado un enlace para restablecer la contraseña a tu correo.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueAccent,
          colorText: Colors.white);
    } on AuthException catch (e) {
      _logger.severe('Error al solicitar restablecimiento: ${e.message}');
      Get.snackbar("Error", e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } catch (e) {
      _logger.severe('Error inesperado al solicitar restablecimiento: $e');
      Get.snackbar(
          "Error", "Ocurrió un error inesperado al solicitar restablecimiento.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// Obtiene el ID del usuario actualmente autenticado (UUID de Supabase Auth).
  String? getCurrentUserId() {
    return _supabaseClient.auth.currentUser?.id;
  }

  /// Obtiene el objeto completo del usuario actualmente autenticado.
  User? getCurrentUser() {
    return _supabaseClient.auth.currentUser;
  }
}

extension on Session? {
  get user => null;
}
