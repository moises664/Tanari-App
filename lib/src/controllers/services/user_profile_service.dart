// user_profile_service.dart

import 'dart:async'; // Para usar Timer y StreamSubscription
import 'dart:io'; // Para manejar archivos (ej. para subir avatares)
import 'package:get/get.dart'; // Para el manejo de estados y la inyección de dependencias
import 'package:supabase_flutter/supabase_flutter.dart'; // Cliente Supabase para interactuar con la base de datos y Storage
import 'package:logging/logging.dart'; // Para un logging robusto
import 'package:tanari_app/src/core/app_colors.dart'; // Colores de la aplicación
import 'package:tanari_app/src/models/user_profile.dart'; // Modelo de datos para el perfil de usuario
import 'package:path/path.dart'
    as p; // Para manipulación de rutas de archivos (ej. extensión de archivo)

/// Logger para la clase UserProfileService.
/// Permite registrar mensajes informativos, advertencias y errores para depuración.
final _logger = Logger('UserProfileService');

/// [UserProfileService] es un servicio de GetX que gestiona todas las operaciones
/// relacionadas con los perfiles de usuario en la base de datos de Supabase.
/// Esto incluye la carga, creación (como respaldo), actualización de datos del perfil
/// y la gestión de la subida y visualización de avatares.
class UserProfileService extends GetxService {
  // Instancia del cliente Supabase, inyectada al inicializar el servicio.
  late final SupabaseClient _supabaseClient;

  // Observable para el perfil del usuario actualmente autenticado.
  // Rxn<UserProfile> permite que el valor sea nulo (RxNullable).
  final Rxn<UserProfile> currentProfile = Rxn<UserProfile>();

  // Observable para indicar si el perfil se está cargando.
  final RxBool isLoadingProfile = false.obs;

  // Suscripción para escuchar cambios en el perfil en tiempo real.
  // Esto permite que la UI se actualice automáticamente cuando el perfil cambia en la DB.
  StreamSubscription<List<Map<String, dynamic>>>? _profileStreamSubscription;

  @override
  void onInit() {
    super.onInit();
    _supabaseClient = Get.find<SupabaseClient>();
    _logger.info('UserProfileService inicializado.');

    // Escuchar cambios de estado de autenticación de Supabase.
    // Esto asegura que el perfil se cargue o se limpie cuando el usuario inicia/cierra sesión.
    _supabaseClient.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // Si el usuario ha iniciado sesión, la sesión es inicial o el usuario se actualizó,
      // intentar obtener o crear su perfil.
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.userUpdated) {
        if (session?.user != null) {
          // Acceso condicional a 'user' para evitar errores de nulabilidad.
          // 'session' ya es verificado por '?.', y 'user' es verificado por '!'.
          await fetchOrCreateUserProfile(session!.user.id);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // Si el usuario cierra sesión, limpiar el perfil actual y cancelar la suscripción en tiempo real.
        currentProfile.value = null;
        _profileStreamSubscription?.cancel();
        _logger.info('Perfil limpiado tras cierre de sesión.');
      }
    });
  }

  @override
  void onClose() {
    // Al cerrar el servicio, asegurar que la suscripción en tiempo real sea cancelada
    // para evitar fugas de memoria.
    _profileStreamSubscription?.cancel();
    _logger.info('UserProfileService cerrado.');
    super.onClose();
  }

  /// Método principal para obtener o crear un perfil de usuario.
  /// Implementa una estrategia de reintento:
  /// 1. Intenta obtener el perfil existente.
  /// 2. Si no lo encuentra, intenta crear uno básico directamente.
  /// 3. Si ambos fallan, recurre a una función de respaldo RPC en la base de datos.
  Future<void> fetchOrCreateUserProfile(String userId) async {
    isLoadingProfile.value = true; // Activar indicador de carga
    try {
      _logger.info('Buscando o creando perfil para usuario: $userId');

      // Intento 1: Obtener perfil existente
      final profile = await _fetchProfile(userId);

      if (profile != null) {
        currentProfile.value = profile;
        _logger.info('Perfil obtenido para $userId: ${profile.username}');
        _setupProfileRealtimeListener(
            userId); // Configurar listener solo si el perfil existe
        return; // Éxito, salir de la función
      }

      // Intento 2: Perfil no encontrado, intentar crear uno básico directamente.
      _logger.warning(
          'Perfil no encontrado para $userId. Intentando crear uno básico.');
      await _createBasicProfile(userId);

      // Después de intentar crear, volver a intentar obtener el perfil.
      final createdProfile = await _fetchProfile(userId);
      if (createdProfile != null) {
        currentProfile.value = createdProfile;
        _logger.info(
            'Perfil básico creado y obtenido para $userId: ${createdProfile.username}');
        _setupProfileRealtimeListener(userId);
        return; // Éxito, salir de la función
      }

      // Último recurso: La creación básica también falló, intentar función de respaldo (RPC).
      _logger.severe(
          'Fallo la creación básica del perfil para $userId. Intentando función de respaldo.');
      await _createProfileFallback(userId);

      // Después de la función de respaldo, intentar obtener el perfil nuevamente.
      final fallbackProfile = await _fetchProfile(userId);
      if (fallbackProfile != null) {
        currentProfile.value = fallbackProfile;
        _logger.info(
            'Perfil creado con función de respaldo para $userId: ${fallbackProfile.username}');
        _setupProfileRealtimeListener(userId);
      } else {
        // Si incluso la función de respaldo falla, lanzar una excepción.
        throw Exception(
            'No se pudo crear o obtener el perfil del usuario después de todos los intentos.');
      }
    } on PostgrestException catch (e, stackTrace) {
      // Captura errores específicos de Postgrest (base de datos).
      _logger.severe(
          'Error Postgrest en fetchOrCreateUserProfile: ${e.message}',
          e,
          stackTrace);
      _showErrorSnackbar('Error de Perfil',
          'Problema con la base de datos al cargar el perfil: ${e.message}');
      currentProfile.value = null; // Limpiar perfil en caso de error grave
    } catch (e, stackTrace) {
      // Captura cualquier otro error inesperado.
      _logger.severe(
          'Error inesperado en fetchOrCreateUserProfile: $e', e, stackTrace);
      _showErrorSnackbar('Error de Perfil',
          'Ocurrió un error inesperado al gestionar el perfil.');
      currentProfile.value = null; // Limpiar perfil en caso de error grave
    } finally {
      isLoadingProfile.value = false; // Desactivar indicador de carga
    }
  }

  /// Intento 1: Obtener perfil existente desde la tabla 'profiles'.
  /// Retorna una instancia de [UserProfile] si se encuentra el perfil, de lo contrario [null].
  Future<UserProfile?> _fetchProfile(String userId) async {
    try {
      final Map<String, dynamic>? data = await _supabaseClient
          .from('profiles')
          .select('*') // Selecciona todas las columnas
          .eq('id', userId) // Donde el ID del perfil coincida con el userId
          .maybeSingle() // Intenta obtener un solo registro, si no existe, retorna null
          .timeout(
              const Duration(seconds: 5)); // Tiempo de espera para la operación

      return data != null ? UserProfile.fromJson(data) : null;
    } on PostgrestException catch (e, stackTrace) {
      // Si hay un error de Postgrest (ej. RLS denegado, tabla no encontrada), registrar y retornar null.
      _logger.warning(
          'Error al buscar perfil para $userId: ${e.message}', e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      // Captura cualquier otro error durante la búsqueda.
      _logger.warning(
          'Error inesperado al buscar perfil para $userId: $e', e, stackTrace);
      return null;
    }
  }

  /// Intento 2: Crear un perfil básico directamente en la tabla 'profiles'.
  /// Esto se usa si el perfil no se encontró previamente.
  /// Asume que el usuario ya está autenticado y tiene un `currentUser`.
  Future<void> _createBasicProfile(String userId) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      _logger.warning('No hay usuario autenticado para crear perfil básico.');
      return;
    }

    // Obtener el nombre de usuario de los metadatos del usuario o usar un valor por defecto.
    final username =
        user.userMetadata?['username'] as String? ?? 'Usuario Tanari';

    try {
      // Insertar el nuevo perfil.
      // Las columnas 'created_at' y 'updated_at' deben ser manejadas por la base de datos
      // (ej. con valores por defecto o triggers).
      await _supabaseClient.from('profiles').insert({
        'id': userId,
        'username': username,
        'email': user.email,
        'is_admin': false, // Por defecto, el nuevo usuario no es administrador
      });
      _logger.info('Perfil básico insertado para $userId.');
    } on PostgrestException catch (e, stackTrace) {
      // Si el perfil ya existe (ej. por una violación de clave duplicada), simplemente registrarlo.
      if (e.message.contains('duplicate key')) {
        _logger.info('Perfil ya existe para $userId (duplicado), no se creó.');
      } else {
        // Si es otro tipo de error de Postgrest, registrar y re-lanzar.
        _logger.severe(
            'Error al insertar perfil básico para $userId: ${e.message}',
            e,
            stackTrace);
        rethrow;
      }
    } catch (e, stackTrace) {
      // Captura cualquier otro error inesperado durante la creación.
      _logger.severe('Error inesperado al crear perfil básico para $userId: $e',
          e, stackTrace);
      rethrow;
    }
  }

  /// Último recurso: Llama a una función RPC de Supabase (`create_profile_fallback`)
  /// para crear un perfil si los intentos anteriores fallaron.
  /// Esta función debe estar definida en tu base de datos Supabase.
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

      // Llama a la función RPC en Supabase con los parámetros necesarios.
      final Map<String, dynamic> response = await _supabaseClient.rpc(
        'create_profile_fallback',
        params: {
          'user_id': userId,
          'username_param': username,
          'email_param': user.email,
        },
      );

      // Si la respuesta de la función RPC contiene un error, lanzar una excepción.
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
  /// Esto permite que la aplicación reciba actualizaciones instantáneas del perfil
  /// si los datos cambian en la base de datos (ej. por otros usuarios o el backend).
  void _setupProfileRealtimeListener(String userId) {
    _profileStreamSubscription
        ?.cancel(); // Cancela cualquier suscripción anterior para evitar duplicados.

    // CAMBIO CLAVE AQUÍ: Revertimos a la sintaxis de .stream() compatible con versiones anteriores.
    // Esta sintaxis utiliza el método .stream() directamente, filtrando por el ID del usuario.
    _profileStreamSubscription = _supabaseClient
        .from('profiles')
        .stream(primaryKey: ['id']) // Escucha cambios en la fila con este ID
        .eq('id', userId) // Filtra para el ID del usuario actual
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            // Si hay datos, actualiza el perfil observable.
            currentProfile.value = UserProfile.fromJson(data[0]);
            _logger
                .info('Actualización de perfil en tiempo real para $userId.');
          }
        }, onError: (error, stackTrace) {
          // Manejo de errores para el stream en tiempo real.
          _logger.severe(
              'Error en el stream de perfil en tiempo real para $userId: $error',
              error,
              stackTrace);
          _showErrorSnackbar('Error de Conexión',
              'Problema con la actualización en tiempo real del perfil.');
        });
    _logger.info('Listener en tiempo real para perfil $userId configurado.');
  }

  /// Limpia el perfil de usuario actual del observable y cancela el listener en tiempo real.
  void clearUserProfile() {
    currentProfile.value = null;
    _profileStreamSubscription?.cancel();
    _logger.info('Perfil de usuario limpiado.');
  }

  /// Actualiza la información del perfil del usuario en la base de datos.
  /// Los campos `created_at` y `updated_at` son gestionados por la base de datos
  /// y no deben ser enviados en las actualizaciones desde el cliente.
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('No hay usuario autenticado para actualizar el perfil.');
      _showErrorSnackbar('Error de Autenticación',
          'No hay sesión activa para actualizar el perfil.');
      return;
    }

    isLoadingProfile.value = true; // Activar indicador de carga
    try {
      _logger.info(
          'Actualizando perfil para usuario: $userId con cambios: $updates');

      // Eliminar campos que deben ser manejados por la base de datos o que no deben ser actualizados por el cliente.
      updates.remove('updated_at'); // La DB maneja esto con triggers/defaults
      updates.remove('created_at'); // La DB maneja esto
      updates.remove('id'); // El ID no debe ser actualizable por el cliente

      // Realizar la operación de actualización en Supabase.
      await _supabaseClient.from('profiles').update(updates).eq('id',
          userId); // Actualiza la fila que coincide con el ID del usuario.

      _showSuccessSnackbar(
          'Perfil Actualizado', 'Tu perfil ha sido actualizado exitosamente.');
      // El listener en tiempo real (_setupProfileRealtimeListener) se encargará de actualizar currentProfile.value
      // automáticamente cuando la base de datos confirme la actualización.
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
        isLoadingProfile.value = false; // Desactivar indicador de carga
      }
    }
  }

  /// Sube una nueva imagen de avatar a Supabase Storage y actualiza el perfil del usuario con la URL.
  /// Genera un nombre de archivo único para evitar problemas de caché y colisiones.
  Future<void> uploadAvatar(File imageFile) async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('No hay usuario autenticado para subir avatar.');
      _showErrorSnackbar('Error de Autenticación',
          'No hay sesión activa para subir el avatar.');
      return;
    }

    isLoadingProfile.value = true; // Activar indicador de carga
    try {
      _logger.info(
          'Intentando subir avatar para ID: $userId desde ${imageFile.path}');

      // Generar un nombre de archivo único usando el ID de usuario y un timestamp.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(
          imageFile.path); // Obtener la extensión original del archivo
      final String pathInStorage =
          '$userId/${timestamp}_avatar$extension'; // Ruta en Supabase Storage

      // Subir el archivo al bucket 'avatars'.
      // `upsert: true` permite reemplazar un archivo existente con el mismo nombre en caso de colisión (aunque el timestamp lo evita).
      await _supabaseClient.storage.from('avatars').upload(
            pathInStorage, // Usar la ruta única generada
            imageFile,
            fileOptions: const FileOptions(
              cacheControl:
                  '3600', // Control de caché por 1 hora en el CDN de Supabase.
              upsert:
                  true, // Permite sobrescribir si el archivo ya existe con ese nombre
            ),
          );

      // La URL pública se obtiene con getPublicUrl, pero para almacenar en la DB,
      // a menudo solo se guarda la ruta relativa dentro del bucket (pathInStorage).
      // La función getAvatarUrl se encarga de construir la URL completa con el timestamp.
      await updateProfile(
          {'avatar_url': pathInStorage}); // Almacenar la ruta relativa en la DB

      _logger
          .info('Avatar subido y perfil actualizado con URL: $pathInStorage');
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
        isLoadingProfile.value = false; // Desactivar indicador de carga
      }
    }
  }

  /// Retorna la URL pública completa de un avatar dado su ruta de almacenamiento
  /// en Supabase Storage. Si la ruta es nula o vacía, devuelve una URL de avatar por defecto.
  ///
  /// Este método es CRUCIAL para forzar la actualización de la imagen en la UI,
  /// ya que añade un parámetro de consulta de tiempo (`?t=timestamp`) a la URL.
  /// Esto asegura que `NetworkImage` siempre cargue la versión más reciente,
  /// evitando problemas de caché del navegador o del widget.
  String getAvatarUrl(String? storedPath) {
    if (storedPath == null || storedPath.isEmpty) {
      // URL de un avatar por defecto si no hay uno configurado.
      return 'https://pfhteyhxvetjhaitlucx.supabase.co/storage/v1/object/public/avatars/default-avatar.png';
    }

    // Construir la URL base pública del bucket 'avatars'.
    // Asegúrate de que esta URL base coincida con tu configuración de Supabase.
    final String baseUrl =
        _supabaseClient.storage.from('avatars').getPublicUrl(storedPath);

    // Añadir un timestamp como parámetro de consulta para invalidar la caché.
    // Esto hace que la URL sea única cada vez que se solicita, forzando la recarga.
    return '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Muestra un snackbar de éxito en la parte inferior de la pantalla.
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

  /// Muestra un snackbar de error en la parte inferior de la pantalla.
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
