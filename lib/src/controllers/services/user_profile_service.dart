import 'dart:io'; // Necesario para File
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/models/user_profile.dart'; // Asegúrate de que esta ruta sea correcta para tu modelo UserProfile
import 'package:logging/logging.dart'; // Para el logging
import 'package:flutter/material.dart'; // Importa para usar Colors en Get.snackbar

// Define un logger para este servicio.
final _logger = Logger('UserProfileService');

class UserProfileService extends GetxService {
  // Instancia del cliente de Supabase
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  // Rx para mantener el perfil del usuario actual de forma reactiva.
  final Rx<UserProfile?> currentUserProfile = Rx<UserProfile?>(null);

  @override
  void onInit() {
    super.onInit();
    _logger.info('UserProfileService initialized.');
    // Si hay un usuario autenticado al iniciar el servicio, intenta cargar su perfil.
    // Esto es útil para que el perfil esté disponible tan pronto como la app se inicie
    // o el usuario se autentique (si este servicio se inicializa después del login).
    final currentAuthUser = _supabaseClient.auth.currentUser;
    if (currentAuthUser != null) {
      fetchOrCreateUserProfile(currentAuthUser.id);
    }
  }

  /// Fetches the user profile from the 'profiles' table.
  /// If the profile does not exist, it creates a new basic one.
  Future<void> fetchOrCreateUserProfile(String userId) async {
    _logger
        .info('Attempting to fetch or create user profile for userId: $userId');
    try {
      final Map<String, dynamic>? data = await _supabaseClient
          .from('profiles')
          .select(
              'id, username, email, created_at, bio, avatar_url') // Asegura que avatar_url se selecciona
          .eq('id', userId)
          .single();

      if (data != null) {
        // Perfil encontrado
        String? fetchedAvatarUrl = data['avatar_url'] as String?;
        // Lógica de limpieza: si la URL contiene el duplicado '/public/avatars/avatars/', lo corrige.
        // Esto es para los casos donde URLs antiguas pudieron haber sido guardadas mal.
        if (fetchedAvatarUrl != null &&
            fetchedAvatarUrl.contains('/public/avatars/avatars/')) {
          fetchedAvatarUrl = fetchedAvatarUrl.replaceFirst(
              '/public/avatars/avatars/', '/public/avatars/');
          _logger.info(
              'Cleaned fetched avatar_url on read from DB: $fetchedAvatarUrl');
        }
        data['avatar_url'] =
            fetchedAvatarUrl; // Actualiza el mapa con la URL limpia

        currentUserProfile.value = UserProfile.fromJson(data);
        _logger.info(
            'User profile fetched successfully: ${currentUserProfile.value?.username}');
        if (currentUserProfile.value?.avatarUrl != null) {
          _logger.info(
              'Fetched (and possibly cleaned) avatar_url: ${currentUserProfile.value!.avatarUrl}');
        } else {
          _logger.info('No avatar_url found for this profile.');
        }
      } else {
        // Perfil no encontrado, proceder a crear uno nuevo
        _logger.warning(
            'User profile not found for userId: $userId. Attempting to create a new profile.');
        final initialUsername = 'user_${userId.substring(0, 8)}';
        final initialEmail =
            _supabaseClient.auth.currentUser?.email ?? 'unknown@example.com';

        final newProfileData = {
          'id': userId,
          'username': initialUsername,
          'email': initialEmail,
          'created_at': DateTime.now().toIso8601String(),
          'bio': '', // Inicializa bio vacío
          'avatar_url': null, // Inicializa avatar_url nulo
        };

        final Map<String, dynamic>? insertedData = await _supabaseClient
            .from('profiles')
            .insert(newProfileData)
            .select()
            .single();

        if (insertedData != null) {
          currentUserProfile.value = UserProfile.fromJson(insertedData);
          _logger.info(
              'New user profile created successfully: ${currentUserProfile.value?.username}');
        } else {
          _logger.severe(
              'Failed to create user profile, no data returned after insert.');
          Get.snackbar('Error',
              'No se pudo crear el perfil de usuario. Intento fallido sin datos de retorno.');
        }
      }
    } on PostgrestException catch (e, s) {
      _logger.severe(
          'Postgrest error fetching or creating user profile: ${e.message} (Code: ${e.code})',
          e,
          s);
      Get.snackbar(
        'Error',
        'Error de base de datos al cargar el perfil: ${e.message}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      _logger.severe(
          'General error fetching or creating user profile: $e', e, s);
      Get.snackbar(
        'Error',
        'No se pudo cargar el perfil de usuario: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Updates the user profile fields (username, bio, avatarUrl).
  /// Only updates fields that are provided (not null).
  Future<void> updateProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      Get.snackbar('Error', 'No hay usuario autenticado para actualizar.');
      return;
    }

    _logger.info('Attempting to update user profile for userId: $userId');
    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      // La URL del avatar ya debería venir limpia de uploadAndSetAvatar
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        _logger.info('No profile fields to update for userId: $userId');
        return;
      }

      final Map<String, dynamic>? updatedData = await _supabaseClient
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      if (updatedData != null) {
        // Al actualizar el perfil, si el avatarUrl es parte de la actualización,
        // nos aseguramos de que currentUserProfile refleje la URL limpia.
        String? updatedAvatarUrl = updatedData['avatar_url'] as String?;
        if (updatedAvatarUrl != null &&
            updatedAvatarUrl.contains('/public/avatars/avatars/')) {
          updatedAvatarUrl = updatedAvatarUrl.replaceFirst(
              '/public/avatars/avatars/', '/public/avatars/');
        }
        updatedData['avatar_url'] =
            updatedAvatarUrl; // Actualiza el mapa con la URL limpia

        currentUserProfile.value = UserProfile.fromJson(updatedData);
        _logger.info(
            'Profile updated successfully: ${currentUserProfile.value?.username}');
        if (currentUserProfile.value?.avatarUrl != null) {
          _logger.info(
              'Updated avatar_url in DB: ${currentUserProfile.value!.avatarUrl}');
        } else {
          _logger.info(
              'Avatar_url was set to null or not provided during update.');
        }

        Get.snackbar(
          'Éxito',
          'Perfil actualizado correctamente',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        _logger
            .severe('Failed to update profile, no data returned after update.');
        Get.snackbar(
          'Error',
          'No se pudo actualizar el perfil, no se recibieron datos.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } on PostgrestException catch (e, s) {
      _logger.severe(
          'Postgrest error updating profile: ${e.message} (Code: ${e.code})',
          e,
          s);
      Get.snackbar(
        'Error',
        'Error de base de datos al actualizar el perfil: ${e.message}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e, s) {
      _logger.severe('Unexpected error updating profile: $e', e, s);
      Get.snackbar(
        'Error',
        'Ocurrió un error inesperado al actualizar el perfil.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Uploads an image to Supabase Storage and updates the user's avatar_url in the profile.
  /// Returns the public URL of the uploaded avatar on success, or null on failure.
  Future<String?> uploadAndSetAvatar(File imageFile) async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('No authenticated user for avatar upload.');
      Get.snackbar('Error', 'No hay usuario autenticado para subir un avatar.');
      return null;
    }

    _logger.info('Attempting to upload avatar for userId: $userId');
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Construimos la ruta del objeto dentro del bucket.
      // Ejemplo: "user_id/1678888888.jpg"
      final String objectPath = '$userId/$fileName';

      _logger.info('Calculated objectPath for upload: $objectPath');

      // 1. Sube el archivo a Supabase Storage
      // La función upload de Supabase Storage espera la ruta del objeto
      // relativa al bucket.
      await _supabaseClient.storage
          .from(
              'avatars') // Nombre del bucket (debe coincidir con tu bucket en Supabase)
          .upload(
            objectPath, // Usamos la ruta del objeto que construimos
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert:
                  true, // Esto sobrescribe si el archivo ya existe con el mismo nombre de ruta
            ),
          );

      _logger.info('File uploaded to objectPath: $objectPath');

      // 2. Obtén la URL pública usando la misma ruta del objeto.
      // Esta es la clave para evitar el problema de la URL duplicada.
      final String publicUrl = _supabaseClient.storage
          .from('avatars')
          .getPublicUrl(objectPath); // ¡Aquí se usa la misma objectPath!

      _logger.info('Generated public URL: $publicUrl');

      // 3. Actualiza la tabla de perfiles con la URL pública
      await updateProfile(avatarUrl: publicUrl);

      _logger
          .info('Avatar uploaded and profile updated successfully: $publicUrl');
      Get.snackbar(
        'Éxito',
        'Avatar actualizado correctamente',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return publicUrl;
    } on StorageException catch (e, s) {
      _logger.severe(
          'Storage error uploading avatar: ${e.message} (StatusCode: ${e.statusCode})',
          e,
          s);
      Get.snackbar(
        'Error',
        'Error de almacenamiento al subir el avatar: ${e.message}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    } catch (e, s) {
      _logger.severe('Unexpected error uploading avatar: $e', e, s);
      Get.snackbar(
        'Error',
        'Ocurrió un error inesperado al subir el avatar.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  /// Clears the currently loaded user profile from the service.
  void clearUserProfile() {
    currentUserProfile.value = null;
    _logger.info('User profile cleared.');
  }
}
