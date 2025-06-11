// lib/src/controllers/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';

final _logger = Logger('AuthService');

class AuthService extends GetxService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  final Rx<User?> currentUser =
      Rx<User?>(null); // Rx para el usuario de Supabase
  final RxBool isLoading =
      false.obs; // <--- ¡NUEVO! Variable reactiva para el estado de carga

  bool _appInitializationComplete = false;

  @override
  void onInit() {
    super.onInit();
    _logger.info('AuthService initialized.');
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _supabaseClient.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      _logger.info('AuthChangeEvent: $event, User: ${session?.user?.email}');

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        currentUser.value = session?.user;
        if (session?.user?.id != null) {
          await Get.find<UserProfileService>()
              .fetchOrCreateUserProfile(session!.user!.id);
        }

        if (_appInitializationComplete) {
          Get.offAllNamed(Routes.home); // O Routes.profile según tu preferencia
          _logger.info('AuthService: Navigating to home after sign-in event.');
        }
      } else if (event == AuthChangeEvent.signedOut) {
        currentUser.value = null;
        Get.find<UserProfileService>().clearUserProfile();
        Get.offAllNamed(Routes.signIn);
        _logger
            .info('AuthService: Navigating to sign-in after sign-out event.');
      } else if (event == AuthChangeEvent.userUpdated) {
        currentUser.value = session?.user;
        _logger.info('AuthService: User profile updated event.');
        if (session?.user?.id != null) {
          await Get.find<UserProfileService>()
              .fetchOrCreateUserProfile(session!.user!.id);
        }
      }
    });
  }

  void setAppInitializationComplete() {
    _appInitializationComplete = true;
    if (currentUser.value != null) {
      Get.offAllNamed(Routes.home); // O Routes.profile
    } else {
      Get.offAllNamed(Routes.welcome);
    }
  }

  Future<void> signIn(String email, String password) async {
    isLoading.value = true; // <--- Inicia la carga
    try {
      _logger.info('Attempting sign-in for email: $email');
      final AuthResponse response =
          await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final User? user = response.user;

      if (user != null) {
        Get.snackbar(
          'Inicio de Sesión Exitoso',
          '¡Bienvenido de nuevo!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error de Inicio de Sesión',
          'Credenciales inválidas o usuario no encontrado.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } on AuthException catch (e) {
      _logger.severe('AuthException during sign-in: ${e.message}', e);
      Get.snackbar(
        'Error de Autenticación',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      _logger.severe('Unexpected error during sign-in: $e', e, s);
      Get.snackbar(
        'Error Inesperado',
        'Algo salió mal durante el inicio de sesión. Intenta de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false; // <--- Finaliza la carga
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    isLoading.value = true; // <--- Inicia la carga
    try {
      _logger.info('Attempting sign-up for email: $email');
      final AuthResponse response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      final User? user = response.user;

      if (user != null) {
        Get.snackbar(
          'Registro Exitoso',
          '¡Bienvenido! Por favor, verifica tu correo electrónico si es necesario.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error de Registro',
          'No se pudo completar el registro. Intenta de nuevo.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } on AuthException catch (e) {
      _logger.severe('AuthException during sign-up: ${e.message}', e);
      Get.snackbar(
        'Error de Registro',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      _logger.severe('Unexpected error during sign-up: $e', e, s);
      Get.snackbar(
        'Error Inesperado',
        'Algo salió mal durante el registro. Intenta de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false; // <--- Finaliza la carga
    }
  }

  Future<void> signOut() async {
    isLoading.value = true; // <--- Inicia la carga
    try {
      _logger.info('Attempting sign-out.');
      await _supabaseClient.auth.signOut();
    } on AuthException catch (e) {
      _logger.severe('AuthException during sign-out: ${e.message}', e);
      Get.snackbar(
        'Error de Sesión',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      _logger.severe('Unexpected error during sign-out: $e', e, s);
      Get.snackbar(
        'Error Inesperado',
        'No se pudo cerrar sesión. Intenta de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false; // <--- Finaliza la carga
    }
  }

  Future<void> sendPasswordRecoveryEmail(String email) async {
    isLoading.value = true; // <--- Inicia la carga
    try {
      _logger.info('Sending password recovery email to: $email');
      await _supabaseClient.auth.resetPasswordForEmail(email);
      Get.snackbar(
        'Correo Enviado',
        'Se ha enviado un correo de recuperación de contraseña a $email. Por favor, revisa tu bandeja de entrada.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on AuthException catch (e) {
      _logger.severe('AuthException during password recovery: ${e.message}', e);
      Get.snackbar(
        'Error de Recuperación',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      _logger.severe('Unexpected error during password recovery: $e', e, s);
      Get.snackbar(
        'Error Inesperado',
        'No se pudo enviar el correo de recuperación. Intenta de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false; // <--- Finaliza la carga
    }
  }
}
