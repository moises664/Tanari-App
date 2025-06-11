// lib/src/controllers/services/user_profile_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/models/user_profile.dart'; // <--- ¡IMPORTANTE! Importa tu CLASE UserProfile

final _logger =
    Logger('UserProfileService'); // Para logs, si lo tienes configurado

class UserProfileService extends GetxService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  // Rx<UserProfile?> para emitir instancias de la clase UserProfile
  final Rx<UserProfile?> currentUserProfile = Rx<UserProfile?>(null);

  @override
  void onInit() {
    super.onInit();
    _logger.info('UserProfileService initialized.');
    // No cargamos el perfil aquí, lo haremos en AuthService cuando el usuario esté autenticado
  }

  /// Fetches the user profile from Supabase based on userId.
  /// If no profile exists, it creates one.
  Future<void> fetchOrCreateUserProfile(String userId) async {
    try {
      _logger.info(
          'Attempting to fetch or create user profile for userId: $userId');

      // 1. Intenta obtener el perfil existente
      final List<Map<String, dynamic>> response = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .limit(
              1); // Usamos limit(1) y no single() porque single() lanza error si no hay resultados.

      if (response.isNotEmpty) {
        // Si el perfil existe, actualiza el estado con la instancia de UserProfile
        currentUserProfile.value = UserProfile.fromJson(response.first);
        _logger.info('User profile fetched successfully for userId: $userId');
      } else {
        // 2. Si no existe, crea uno nuevo
        final User? user = _supabaseClient
            .auth.currentUser; // Obtener el usuario autenticado directamente

        if (user != null) {
          final Map<String, dynamic> newUserProfileData = {
            'id': userId,
            'username': user.userMetadata?['username'] as String? ??
                user.email?.split('@').first ??
                'Usuario',
            'email': user.email ??
                'no_email@example.com', // Asegúrate de tener un fallback
            'avatar_url': user.userMetadata?['avatar_url'] as String?,
            // Aquí puedes añadir otros campos predeterminados para el nuevo perfil
          };

          await _supabaseClient.from('profiles').insert(newUserProfileData);

          // Vuelve a intentar obtener el perfil recién creado para asegurarte de que está en el estado correcto
          final List<Map<String, dynamic>> newResponse = await _supabaseClient
              .from('profiles')
              .select()
              .eq('id', userId)
              .limit(1);

          if (newResponse.isNotEmpty) {
            currentUserProfile.value = UserProfile.fromJson(newResponse.first);
            _logger.info(
                'New user profile created and fetched for userId: $userId');
          } else {
            _logger.warning(
                'Failed to fetch newly created profile for userId: $userId after insertion.');
            currentUserProfile.value = null;
          }
        } else {
          _logger.warning(
              'User object is null when trying to create profile for userId: $userId. This should not happen if user is signed in.');
          currentUserProfile.value = null;
        }
      }
    } catch (e, s) {
      _logger.severe(
          'Error fetching or creating user profile for userId: $userId', e, s);
      currentUserProfile.value = null;
      Get.snackbar(
        'Error de Perfil',
        'No se pudo cargar o crear el perfil del usuario. Intenta de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Clears the current user profile data (e.g., on logout).
  void clearUserProfile() {
    currentUserProfile.value = null;
    _logger.info('User profile cleared.');
  }

  // Puedes añadir métodos para actualizar el perfil aquí:
  Future<void> updateUsername(String newUsername) async {
    if (currentUserProfile.value == null) {
      _logger.warning('Cannot update username, currentUserProfile is null.');
      Get.snackbar('Error', 'Perfil no cargado para actualizar.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }
    try {
      _logger.info(
          'Attempting to update username for user: ${currentUserProfile.value!.id}');
      await _supabaseClient.from('profiles').update({
        'username': newUsername,
      }).eq('id', currentUserProfile.value!.id);

      // Actualiza la instancia local del perfil para reflejar el cambio
      currentUserProfile.value = UserProfile(
        id: currentUserProfile.value!.id,
        username: newUsername,
        email: currentUserProfile.value!.email,
        avatarUrl: currentUserProfile.value!.avatarUrl,
        createdAt: currentUserProfile.value!.createdAt,
      );
      _logger.info('Username updated successfully to: $newUsername');
      Get.snackbar('Éxito', 'Nombre de usuario actualizado.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e, s) {
      _logger.severe('Error updating username: $e', e, s);
      Get.snackbar('Error', 'No se pudo actualizar el nombre de usuario.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }
}
