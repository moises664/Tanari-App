// USER PROFILE SERVICE

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/models/user_profile.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';

/// Excepción personalizada para errores relacionados con perfiles de usuario.
class ProfileException implements Exception {
  final String message;
  ProfileException(this.message);

  @override
  String toString() => 'ProfileException: $message';
}

/// [UserProfileService] es un servicio de GetX que gestiona todas las operaciones
/// relacionadas con los perfiles de usuario en la base de datos de Supabase.
/// Esto incluye la carga, actualización y subida de avatares.
///
/// Este servicio se basa en que la creación inicial del perfil para nuevos usuarios
/// es manejada por un trigger de base de datos en Supabase, no por la aplicación cliente.
class UserProfileService extends GetxService {
  late final SupabaseClient _supabase;
  final Logger _logger = Logger('UserProfileService');

  /// Perfil de usuario actual, observable para que los widgets puedan reaccionar a los cambios.
  final Rx<UserProfile?> currentProfile = Rx<UserProfile?>(null);

  @override
  void onInit() {
    super.onInit();
    _logger.info('UserProfileService inicializando...');

    // Obtener la instancia de SupabaseClient inyectada por GetX.
    _supabase = Get.find<SupabaseClient>();
    _logger.info('UserProfileService dependencias encontradas.');

    // Escuchar cambios de estado de autenticación para cargar el perfil automáticamente.
    // Esto asegura que el perfil se cargue cada vez que un usuario inicia sesión
    // o cuando se detecta una sesión inicial.
    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.userUpdated) {
        if (session?.user != null) {
          // Intentar cargar o crear el perfil.
          // La creación es un fallback si el trigger del servidor falló.
          await fetchOrCreateUserProfile(session!.user!.id);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // Limpiar el perfil si el usuario cierra sesión.
        currentProfile.value = null;
        _logger.info('Perfil limpiado tras cierre de sesión.');
      }
    });
  }

  /// Busca el perfil de un usuario por su ID.
  ///
  /// **Este método asume que el perfil ya ha sido creado por un trigger
  /// del lado del servidor (`on_auth_user_created`) cuando el usuario se registra.**
  /// Si el perfil no se encuentra (lo cual sería una anomalía), este método
  /// intentará crearlo como un mecanismo de respaldo.
  ///
  /// Parámetros:
  /// - `userId`: El ID único del usuario (generalmente el `id` de `auth.users`).
  Future<void> fetchOrCreateUserProfile(String userId) async {
    _logger.info('Intentando cargar o crear perfil para ID: $userId');
    try {
      // Intentar obtener el perfil existente.
      final response =
          await _supabase.from('profiles').select().eq('id', userId).single();
      currentProfile.value = UserProfile.fromMap(response);
      _logger.info('Perfil cargado: ${currentProfile.value?.username}');
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == 'PGRST116') {
        // Código PGRST116 indica que no se encontró la fila.
        _logger.warning(
            'Perfil no encontrado para $userId. Intentando crearlo como fallback...');
        try {
          final user = _supabase.auth.currentUser;
          if (user == null) {
            throw ProfileException(
                'Usuario autenticado no encontrado para crear perfil de fallback.');
          }

          // Preparar datos mínimos para la creación del perfil.
          // El `username` se intenta obtener de la metadata del usuario de auth,
          // si no está, se usa una parte del email o un valor por defecto.
          final newProfileData = {
            'id': user.id,
            'email': user.email,
            'username': user.userMetadata?['username'] ??
                user.email?.split('@')[0] ??
                'usuario_tanari',
            'is_admin': false,
            // 'created_at' y 'updated_at' serán manejados por los defaults/triggers de la DB.
          };

          final insertResponse = await _supabase
              .from('profiles')
              .insert(newProfileData)
              .select()
              .single();
          currentProfile.value = UserProfile.fromMap(insertResponse);
          _logger.info('Perfil de fallback creado y cargado para $userId.');
          Get.snackbar(
            'Perfil Creado',
            'Tu perfil ha sido creado exitosamente.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.success,
            colorText: AppColors.backgroundWhite,
          );
        } catch (insertE, insertStackTrace) {
          _logger.severe(
              'Error al crear perfil de fallback para $userId: $insertE',
              insertE,
              insertStackTrace);
          Get.snackbar('Error', 'Error al crear perfil: ${insertE.toString()}',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.error,
              colorText: AppColors.backgroundWhite);
          throw ProfileException(
              'No se pudo crear el perfil: ${insertE.toString()}');
        }
      } else {
        // Otros errores de Postgrest.
        _logger.severe(
            'Error de Postgrest al cargar perfil para $userId: ${e.message}',
            e,
            stackTrace);
        Get.snackbar('Error', 'Error al cargar perfil: ${e.message}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: AppColors.backgroundWhite);
        rethrow;
      }
    } catch (e, stackTrace) {
      // Errores inesperados.
      _logger.severe(
          'Error inesperado al cargar o crear perfil para $userId: $e',
          e,
          stackTrace);
      Get.snackbar(
          'Error', 'Error inesperado al cargar o crear perfil: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
      rethrow;
    }
  }

  /// Actualiza la información del perfil de un usuario existente.
  ///
  /// La columna `updated_at` de la tabla `profiles` se actualizará
  /// automáticamente en el lado del servidor mediante el trigger `on_profiles_update`
  /// que ejecuta la función `set_updated_at()`.
  ///
  /// Parámetros:
  /// - `userId`: El ID del usuario cuyo perfil se va a actualizar.
  /// - `username`: Nuevo nombre de usuario (opcional).
  /// - `bio`: Nueva biografía (opcional).
  /// - `avatarUrl`: Nueva URL del avatar (opcional).
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    _logger.info('Intentando actualizar perfil para ID: $userId');
    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        _logger.info(
            'No hay cambios para actualizar el perfil. Operación omitida.');
        return;
      }

      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select() // Seleccionar los datos actualizados para reflejarlos en la app.
          .single();

      currentProfile.value =
          UserProfile.fromMap(response); // Actualizar el perfil observable.
      _logger.info('Perfil actualizado para: $userId.');
      Get.snackbar(
        'Éxito',
        'Perfil actualizado con éxito.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.backgroundWhite,
      );
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe('Error de Postgrest al actualizar perfil: ${e.message}', e,
          stackTrace);
      Get.snackbar('Error', 'Error al actualizar perfil: ${e.message}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
      rethrow;
    } catch (e, stackTrace) {
      _logger.severe(
          'Error inesperado al actualizar perfil: $e', e, stackTrace);
      Get.snackbar(
          'Error', 'Error inesperado al actualizar perfil: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
      rethrow;
    }
  }

  /// Sube un archivo de imagen al bucket 'avatars' de Supabase Storage.
  ///
  /// Parámetros:
  /// - `userId`: El ID del usuario asociado al avatar (se usa para la ruta del archivo).
  /// - `imageFile`: El archivo de imagen a subir.
  ///
  /// Retorna la URL pública del avatar subido.
  Future<String> uploadAvatar(
      {required String userId, required File imageFile}) async {
    _logger.info(
        'Intentando subir avatar para ID: $userId desde ${imageFile.path}');
    try {
      // Definir la ruta de almacenamiento: userId/nombre_del_archivo.ext
      final String path = '$userId/${p.basename(imageFile.path)}';

      // Subir el archivo al bucket 'avatars'.
      // `upsert: true` permite reemplazar un archivo existente con el mismo nombre.
      await _supabase.storage.from('avatars').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600', // Control de caché por 1 hora.
              upsert: true,
            ),
          );

      // Obtener la URL pública del archivo subido.
      final String publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(path);

      // Actualizar el perfil del usuario con la nueva URL del avatar.
      await updateProfile(userId: userId, avatarUrl: publicUrl);

      _logger.info('Avatar subido y perfil actualizado con URL: $publicUrl');
      return publicUrl;
    } on StorageException catch (e, stackTrace) {
      _logger.severe(
          'Error de Storage al subir avatar: ${e.message}', e, stackTrace);
      Get.snackbar('Error', 'Error al subir avatar: ${e.message}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
      rethrow;
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado al subir avatar: $e', e, stackTrace);
      Get.snackbar('Error', 'Error inesperado al subir avatar: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
      rethrow;
    }
  }

  /// Retorna la URL pública completa de un avatar dado su ruta de almacenamiento
  /// en Supabase Storage. Si la ruta es nula o vacía, devuelve una URL de avatar por defecto.
  ///
  /// Este método también corrige URLs mal formadas o incompletas para asegurar
  /// que siempre se obtenga una URL válida para mostrar la imagen.
  String getAvatarUrl(String? storedPath) {
    if (storedPath == null || storedPath.isEmpty) {
      // URL de un avatar por defecto si no hay uno configurado.
      return 'https://pfhteyhxvetjhaitlucx.supabase.co/storage/v1/object/public/avatars/default-avatar.png';
    }

    // Prefijo base para las URLs públicas de Supabase Storage.
    const prefix =
        'https://pfhteyhxvetjhaitlucx.supabase.co/storage/v1/object/public/avatars/';

    // Si la ruta ya es una URL pública completa y no contiene el token de caché,
    // la reconstruimos para asegurar que sea válida y pueda tener un token de caché.
    if (storedPath.startsWith(prefix) && !storedPath.contains('?t=')) {
      final String fileName = storedPath.substring(prefix.length);
      return _supabase.storage.from('avatars').getPublicUrl(fileName);
    }
    // Si es una ruta relativa (ej. "user_id/imagen.png"), obtenemos la URL pública.
    else if (!storedPath.startsWith('http')) {
      return _supabase.storage.from('avatars').getPublicUrl(storedPath);
    }

    // Si ya es una URL pública válida (incluyendo las que ya tienen token de caché), la retornamos tal cual.
    return storedPath;
  }

  /// Limpia el perfil de usuario actual. Se usa típicamente al cerrar sesión.
  void clearUserProfile() {
    currentProfile.value = null;
    _logger.info('Perfil de usuario limpiado.');
  }
}
