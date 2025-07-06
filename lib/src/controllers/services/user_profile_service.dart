// user_profile_service.dart (Versión corregida y optimizada)

import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart'; // Asegúrate de usar este import para Logger
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/models/user_profile.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:path/path.dart' as p; // Para manipulación de rutas de archivos

/// Logger para la clase UserProfileService.
final _logger = Logger('UserProfileService');

/// [UserProfileService] es un servicio de GetX que gestiona la información
/// del perfil del usuario, incluyendo la carga, actualización y gestión de avatares.
class UserProfileService extends GetxService {
  late final SupabaseClient _supabaseClient;

  // Observable para el perfil del usuario actualmente autenticado.
  final Rxn<UserProfile> currentProfile = Rxn<UserProfile>();
  final RxBool isLoadingProfile = false.obs;

  // Suscripción para escuchar cambios en el perfil en tiempo real.
  StreamSubscription<List<Map<String, dynamic>>>? _profileStreamSubscription;

  @override
  void onInit() {
    super.onInit();
    _supabaseClient = Get.find<SupabaseClient>();
    _logger.info('UserProfileService inicializado.');

    // Escuchar cambios de estado de autenticación para cargar el perfil automáticamente.
    _supabaseClient.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.userUpdated) {
        if (session?.user != null) {
          await fetchOrCreateUserProfile(session!.user!.id);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        currentProfile.value = null;
        _profileStreamSubscription
            ?.cancel(); // Cancelar la suscripción al cerrar sesión
        _logger.info('Perfil limpiado tras cierre de sesión.');
      }
    });
  }

  @override
  void onClose() {
    _profileStreamSubscription?.cancel();
    _logger.info('UserProfileService cerrado.');
    super.onClose();
  }

  /// Método principal para obtener o crear un perfil de usuario.
  /// Intenta obtener el perfil existente. Si no lo encuentra, intenta crear uno básico.
  /// Si ambos fallan, recurre a una función de respaldo en la base de datos.
  Future<void> fetchOrCreateUserProfile(String userId) async {
    isLoadingProfile.value = true;
    try {
      _logger.info('Buscando o creando perfil para usuario: $userId');

      // Intento 1: Obtener perfil existente
      final profile = await _fetchProfile(userId);

      if (profile != null) {
        currentProfile.value = profile;
        _logger.info('Perfil obtenido para $userId: ${profile.username}');
        _setupProfileRealtimeListener(
            userId); // Configurar listener solo si el perfil existe
        return;
      }

      // Intento 2: Crear perfil básico si no se encontró uno existente
      _logger.warning(
          'Perfil no encontrado para $userId. Intentando crear uno básico.');
      await _createBasicProfile(userId);

      // Después de intentar crear, volver a intentar obtener el perfil
      final createdProfile = await _fetchProfile(userId);
      if (createdProfile != null) {
        currentProfile.value = createdProfile;
        _logger.info(
            'Perfil básico creado y obtenido para $userId: ${createdProfile.username}');
        _setupProfileRealtimeListener(userId);
        return;
      }

      // Último recurso: Función de respaldo si la creación básica también falla
      _logger.severe(
          'Fallo la creación básica del perfil para $userId. Intentando función de respaldo.');
      await _createProfileFallback(userId);

      // Después de la función de respaldo, intentar obtener el perfil nuevamente
      final fallbackProfile = await _fetchProfile(userId);
      if (fallbackProfile != null) {
        currentProfile.value = fallbackProfile;
        _logger.info(
            'Perfil creado con función de respaldo para $userId: ${fallbackProfile.username}');
        _setupProfileRealtimeListener(userId);
      } else {
        throw Exception(
            'No se pudo crear o obtener el perfil del usuario después de todos los intentos.');
      }
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe(
          'Error Postgrest en fetchOrCreateUserProfile: ${e.message}',
          e,
          stackTrace);
      _showErrorSnackbar('Error de Perfil',
          'Problema con la base de datos al cargar el perfil: ${e.message}');
      currentProfile.value = null;
    } catch (e, stackTrace) {
      _logger.severe(
          'Error inesperado en fetchOrCreateUserProfile: $e', e, stackTrace);
      _showErrorSnackbar('Error de Perfil',
          'Ocurrió un error inesperado al gestionar el perfil.');
      currentProfile.value = null;
    } finally {
      isLoadingProfile.value = false;
    }
  }

  /// Intento 1: Obtener perfil existente.
  /// Retorna [UserProfile] si se encuentra, de lo contrario [null].
  Future<UserProfile?> _fetchProfile(String userId) async {
    try {
      final Map<String, dynamic>? data = await _supabaseClient
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle() // Usar maybeSingle para obtener un solo registro o null
          .timeout(const Duration(
              seconds: 5)); // Pequeño timeout para esta operación

      return data != null ? UserProfile.fromJson(data) : null;
    } on PostgrestException catch (e, stackTrace) {
      _logger.warning(
          'Error al buscar perfil para $userId: ${e.message}', e, stackTrace);
      return null; // Retornar null si hay un error de Postgrest (ej. no encontrado)
    } catch (e, stackTrace) {
      _logger.warning(
          'Error inesperado al buscar perfil para $userId: $e', e, stackTrace);
      return null;
    }
  }

  /// Intento 2: Crear perfil básico si no existe.
  /// Asume que el usuario ya está autenticado y tiene un `currentUser`.
  Future<void> _createBasicProfile(String userId) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      _logger.warning('No hay usuario autenticado para crear perfil básico.');
      return;
    }

    final username =
        user.userMetadata?['username'] as String? ?? 'Usuario Tanari';

    try {
      // Insertar el perfil. created_at y updated_at deben ser manejados por la DB.
      await _supabaseClient.from('profiles').insert({
        'id': userId,
        'username': username,
        'email': user.email,
        'is_admin': false, // Por defecto, no es admin
      });
      _logger.info('Perfil básico insertado para $userId.');
    } on PostgrestException catch (e, stackTrace) {
      if (e.message.contains('duplicate key')) {
        _logger.info('Perfil ya existe para $userId (duplicado), no se creó.');
      } else {
        _logger.severe(
            'Error al insertar perfil básico para $userId: ${e.message}',
            e,
            stackTrace);
        rethrow; // Re-lanzar para que fetchOrCreateUserProfile lo capture
      }
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado al crear perfil básico para $userId: $e',
          e, stackTrace);
      rethrow;
    }
  }

  /// Último recurso: Función de respaldo (RPC) para crear un perfil.
  /// Esto se usa si la inserción directa falla por alguna razón inesperada.
  /// Requiere que la función `create_profile_fallback` exista en Supabase.
  Future<void> _createProfileFallback(String userId) async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        _logger
            .warning('No hay usuario autenticado para la función de respaldo.');
        return;
      }
      final username =
          user.userMetadata?['username'] as String? ?? 'Usuario Tanari';

      // Llama a la función RPC en Supabase
      final Map<String, dynamic> response = await _supabaseClient.rpc(
        'create_profile_fallback',
        params: {
          'user_id': userId,
          'username_param':
              username, // Usar un nombre de parámetro distinto para evitar conflictos
          'email_param': user.email,
        },
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
      _logger.info('Perfil creado con función de respaldo para $userId.');
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe('Error Postgrest en función de respaldo: ${e.message}', e,
          stackTrace);
      _showErrorSnackbar('Error de Base de Datos',
          'Fallo la creación del perfil de respaldo: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.severe(
          'Error inesperado en función de respaldo: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Configura un listener en tiempo real para el perfil del usuario actual.
  void _setupProfileRealtimeListener(String userId) {
    _profileStreamSubscription?.cancel(); // Cancela suscripciones anteriores
    _profileStreamSubscription = _supabaseClient
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            currentProfile.value = UserProfile.fromJson(data[0]);
            _logger
                .info('Actualización de perfil en tiempo real para $userId.');
          }
        }, onError: (error, stackTrace) {
          _logger.severe(
              'Error en el stream de perfil en tiempo real para $userId: $error',
              error,
              stackTrace);
          _showErrorSnackbar('Error de Conexión',
              'Problema con la actualización en tiempo real del perfil.');
        });
    _logger.info('Listener en tiempo real para perfil $userId configurado.');
  }

  /// Limpia el perfil de usuario actual del observable.
  void clearUserProfile() {
    currentProfile.value = null;
    _profileStreamSubscription?.cancel(); // Cancelar real-time listener
    _logger.info('Perfil de usuario limpiado.');
  }

  /// Actualiza la información del perfil del usuario.
  /// Los campos `created_at` y `updated_at` son manejados por la base de datos.
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('No hay usuario autenticado para actualizar el perfil.');
      _showErrorSnackbar('Error de Autenticación',
          'No hay sesión activa para actualizar el perfil.');
      return;
    }

    isLoadingProfile.value = true;
    try {
      _logger.info(
          'Actualizando perfil para usuario: $userId con cambios: $updates');

      // Eliminar campos que deben ser manejados por la base de datos
      updates.remove('updated_at'); // La DB maneja esto con triggers/defaults
      updates.remove('created_at'); // La DB maneja esto
      updates.remove('id'); // El ID no debe ser actualizable por el cliente

      await _supabaseClient.from('profiles').update(updates).eq('id',
          userId); // No se usa .select().single() aquí, el listener en tiempo real lo actualizará.

      _showSuccessSnackbar(
          'Perfil Actualizado', 'Tu perfil ha sido actualizado exitosamente.');
      // El listener en tiempo real (_setupProfileRealtimeListener) se encargará de actualizar currentProfile.value
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe(
          'Error actualizando perfil para $userId desde Supabase: ${e.message}',
          e,
          stackTrace);
      _showErrorSnackbar('Error al Actualizar Perfil',
          'No se pudo actualizar el perfil: ${e.message}');
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado al actualizar perfil para $userId: $e',
          e, stackTrace);
      _showErrorSnackbar('Error al Actualizar Perfil',
          'Ocurrió un error inesperado al actualizar el perfil.');
    } finally {
      if (Get.isRegistered<UserProfileService>()) {
        isLoadingProfile.value = false;
      }
    }
  }

  /// Sube una nueva imagen de avatar a Supabase Storage y actualiza el perfil del usuario con la URL.
  Future<void> uploadAvatar(File imageFile) async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('No hay usuario autenticado para subir avatar.');
      _showErrorSnackbar('Error de Autenticación',
          'No hay sesión activa para subir el avatar.');
      return;
    }

    isLoadingProfile.value = true;
    try {
      _logger.info(
          'Intentando subir avatar para ID: $userId desde ${imageFile.path}');
      // Definir la ruta de almacenamiento: userId/nombre_del_archivo.ext
      final String path = '$userId/${p.basename(imageFile.path)}';

      // Subir el archivo al bucket 'avatars'.
      // `upsert: true` permite reemplazar un archivo existente con el mismo nombre.
      final String publicUrl =
          await _supabaseClient.storage.from('avatars').upload(
                path,
                imageFile,
                fileOptions: const FileOptions(
                  cacheControl: '3600', // Control de caché por 1 hora.
                  upsert: true,
                ),
              );

      // Actualizar el perfil del usuario con la nueva URL del avatar.
      // updateProfile ahora espera un mapa de actualizaciones.
      await updateProfile({'avatar_url': publicUrl});

      _logger.info('Avatar subido y perfil actualizado con URL: $publicUrl');
      _showSuccessSnackbar(
          'Avatar Actualizado', 'Tu foto de perfil ha sido actualizada.');
    } on StorageException catch (e, stackTrace) {
      _logger.severe(
          'Error de Storage al subir avatar: ${e.message}', e, stackTrace);
      _showErrorSnackbar(
          'Error al Subir Avatar', 'Error al subir avatar: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado al subir avatar: $e', e, stackTrace);
      _showErrorSnackbar('Error al Subir Avatar',
          'Error inesperado al subir avatar: ${e.toString()}');
      rethrow;
    } finally {
      if (Get.isRegistered<UserProfileService>()) {
        isLoadingProfile.value = false;
      }
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
      return _supabaseClient.storage.from('avatars').getPublicUrl(fileName);
    }
    // Si es una ruta relativa (ej. "user_id/imagen.png"), obtenemos la URL pública.
    else if (!storedPath.startsWith('http')) {
      return _supabaseClient.storage.from('avatars').getPublicUrl(storedPath);
    }

    // Si ya es una URL pública válida (incluyendo las que ya tienen token de caché), la retornamos tal cual.
    return storedPath;
  }

  /// Muestra un snackbar de éxito con un título y mensaje.
  void _showSuccessSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.backgroundWhite,
      duration: const Duration(seconds: 3),
    );
  }

  /// Muestra un snackbar de error con un título y mensaje.
  void _showErrorSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.backgroundWhite,
      duration: const Duration(seconds: 5),
    );
  }
}
