// lib/src/services/auth_service.dart
import 'package:flutter/material.dart'; // Importa para Get.snackbar
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart'; // Para el logger

class AuthService extends GetxService {
  final _supabaseClient = Supabase.instance.client;
  final Logger _logger = Logger('AuthService'); // Instancia para logging

  final Rx<User?> currentUser =
      Rx<User?>(null); // Observable para el usuario actual
  final RxBool isLoading = true
      .obs; // Observable para el estado de carga (inicialmente true para la verificación inicial)

  @override
  void onInit() {
    super.onInit();
    _logger.fine('AuthService initialized');

    // Inicializa el estado de carga y el usuario al arrancar la app
    _initializeAuthStatus();

    // Escucha cambios en el estado de autenticación de Supabase
    _supabaseClient.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      currentUser.value = session?.user; // Actualiza el usuario observable

      _logger.info(
          'Auth event: $event, User: ${session?.user.email}'); //elimine el '?'

      // Aquí, el main.dart manejará la redirección principal basada en currentUser.value.
      // Puedes usar estos eventos para mostrar mensajes informativos al usuario.
      if (event == AuthChangeEvent.signedIn) {
        Get.snackbar("Bienvenido", "Has iniciado sesión exitosamente!",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white);
      } else if (event == AuthChangeEvent.signedOut) {
        Get.snackbar("Adiós", "Has cerrado sesión.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white);
      }
      // NOTA: AuthChangeEvent.signedUp ya no es un evento separado en Supabase.
      // Un registro exitoso resultará en un AuthChangeEvent.signedIn.

      // Asegúrate de que isLoading se establezca en false una vez que el estado se haya resuelto
      isLoading.value = false;
    });
  }

  // Método para inicializar el estado de autenticación al inicio de la app
  void _initializeAuthStatus() {
    final user = _supabaseClient.auth.currentUser;
    currentUser.value = user;
    // Esto asegura que isLoading es false después de la verificación inicial
    isLoading.value = false;
    _logger.fine('Initial auth status checked. User: ${user?.email}');
  }

  /// Registra un nuevo usuario con email, contraseña y un username.
  /// Inserta también el perfil del usuario en la tabla 'profiles'.
  Future<void> signUp(String email, String password, String username) async {
    isLoading.value = true; // Inicia el estado de carga
    try {
      final AuthResponse response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Si el registro fue exitoso, también insertamos el perfil en la tabla 'profiles'
        // Es crucial que tu tabla 'profiles' en Supabase tenga las columnas 'id' y 'username'.
        // 'id' debe ser de tipo UUID y marcada como clave primaria, y se recomienda una RLS para ello.
        await _supabaseClient.from('profiles').insert({
          'id': response.user!.id, // El ID del usuario de auth.users
          'username': username,
          'is_admin': false, // Por defecto, no es admin
          // Puedes añadir otros campos iniciales aquí
        });
        _logger.info(
            'Usuario registrado y perfil creado: ${response.user?.email}');
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
      isLoading.value = false; // Finaliza el estado de carga
    }
  }

  /// Inicia sesión con email y contraseña.
  Future<void> signIn(String email, String password) async {
    isLoading.value = true; // Inicia el estado de carga
    try {
      await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // La lógica de snackbar y redirección se maneja en el listener onAuthStateChange
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
      isLoading.value = false; // Finaliza el estado de carga
    }
  }

  /// Cierra la sesión del usuario actual.
  Future<void> signOut() async {
    isLoading.value = true; // Inicia el estado de carga
    try {
      await _supabaseClient.auth.signOut();
      // La lógica de snackbar y redirección se maneja en el listener onAuthStateChange
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
      isLoading.value = false; // Finaliza el estado de carga
    }
  }

  /// Solicita un restablecimiento de contraseña para el email dado.
  /// Envía un enlace al correo electrónico del usuario.
  Future<void> resetPasswordForEmail(String email) async {
    isLoading.value = true; // Inicia el estado de carga
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
      isLoading.value = false; // Finaliza el estado de carga
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
