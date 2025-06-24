import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/models/user_profile.dart';
import 'dart:io'; // Necesario para la clase File
import 'package:path/path.dart' as p; // Para manipulación de rutas de archivo

class UserProfileService extends GetxService {
  final SupabaseClient _supabase = Get.find<SupabaseClient>();
  final Rx<UserProfile?> currentProfile = Rx<UserProfile?>(null);

  @override
  void onInit() {
    super.onInit();
    // Escuchar cambios de autenticación para cargar/limpiar el perfil
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      if (event == AuthChangeEvent.signedIn && session != null) {
        fetchOrCreateUserProfile(session.user!.id);
      } else if (event == AuthChangeEvent.signedOut) {
        clearUserProfile();
      }
    });

    // Cargar el perfil inicial si ya hay una sesión activa
    if (_supabase.auth.currentUser != null) {
      fetchOrCreateUserProfile(_supabase.auth.currentUser!.id);
    }
  }

  /// Carga el perfil de usuario existente o crea uno por defecto.
  Future<void> fetchOrCreateUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        currentProfile.value = UserProfile.fromMap(response);
      } else {
        await createDefaultProfile(userId);
      }
    } catch (e) {
      Get.snackbar('Error', 'Error al cargar perfil: $e');
      rethrow;
    }
  }

  /// Crea un perfil de usuario por defecto para un nuevo usuario.
  Future<void> createDefaultProfile(String userId) async {
    try {
      final newProfile = UserProfile(
        id: userId,
        username: 'Usuario ${userId.substring(0, 6)}',
        email: _supabase.auth.currentUser?.email ??
            'email@desconocido.com', // Fallback seguro
        isAdmin: false,
        createdAt: DateTime.now(),
        bio: '¡Hola! Soy nuevo en Tanari',
      );

      await _supabase.from('profiles').insert(newProfile.toMap());
      currentProfile.value = newProfile;
    } catch (e) {
      Get.snackbar('Error', 'Error al crear perfil: $e');
      rethrow;
    }
  }

  /// Actualiza los campos del perfil de usuario.
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      // Solo actualiza si hay algo que actualizar
      if (updates.isNotEmpty) {
        await _supabase.from('profiles').update(updates).eq('id', userId);
        // Actualizar el perfil reactivo localmente
        if (currentProfile.value != null) {
          currentProfile.value = currentProfile.value!.copyWith(
            username:
                username, // Pasa null si no se actualiza, copyWith lo maneja
            bio: bio,
            avatarUrl: avatarUrl,
          );
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Error al actualizar perfil: $e');
      rethrow;
    }
  }

  /// Sube una imagen de avatar al almacenamiento de Supabase y actualiza la URL del perfil.
  Future<void> uploadAvatar({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final String fileName =
          '${userId}/${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}';
      final String bucket =
          'avatars'; // Asegúrate de que este bucket exista en Supabase Storage

      // Sube la imagen al almacenamiento
      final String? publicUrl = await _supabase.storage.from(bucket).upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              upsert: true, // Reemplazar si el archivo ya existe
              contentType:
                  'image/jpeg', // O el tipo de tu imagen (image/png, etc.)
            ),
          );

      // Obtener la URL pública del avatar
      // Supabase storage devuelve la ruta, no la URL completa directamente de `upload`
      final String avatarDownloadUrl =
          _supabase.storage.from(bucket).getPublicUrl(fileName);

      // Actualizar el perfil del usuario con la nueva URL del avatar
      await updateProfile(userId: userId, avatarUrl: avatarDownloadUrl);

      Get.snackbar(
        'Éxito',
        'Avatar subido correctamente.',
        backgroundColor: AppColors.success,
        colorText: AppColors.backgroundWhite,
      );
    } catch (e) {
      Get.snackbar('Error', 'Error al subir el avatar: $e');
      rethrow;
    }
  }

  /// Limpia el perfil de usuario actual (ej. al cerrar sesión).
  void clearUserProfile() {
    currentProfile.value = null;
  }
}
