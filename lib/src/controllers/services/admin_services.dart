// admin_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/models/user_profile.dart';

/// Servicio para operaciones administrativas
///
/// Gestiona:
/// - Creación y eliminación de usuarios
/// - Asignación de roles de administrador
/// - Gestión de dispositivos BLE
/// - Registro de auditoría de acciones administrativas
final _logger = Logger('AdminService');

class AdminService extends GetxService {
  late final SupabaseClient _supabaseClient;
  final RxList<UserProfile> allUsers = <UserProfile>[].obs;
  final RxList<Map<String, dynamic>> registeredDevices =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoadingUsers = false.obs;
  final RxBool isLoadingDevices = false.obs;

  // Para acceso Publico
  SupabaseClient get supabaseClient => _supabaseClient;

  @override
  void onInit() {
    super.onInit();
    _supabaseClient = Get.find<SupabaseClient>();
    _logger.info('AdminService inicializado.');
  }

  /// Obtiene todos los perfiles de usuario
  ///
  /// Solo debe ser llamado por usuarios administradores
  Future<void> fetchAllUsers() async {
    isLoadingUsers.value = true;
    try {
      _logger.info('Obteniendo todos los perfiles de usuario...');
      final List<Map<String, dynamic>> data = await _supabaseClient
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      allUsers.value = data.map((json) => UserProfile.fromJson(json)).toList();
      _logger.info('${allUsers.length} perfiles obtenidos');
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe('Error al obtener usuarios: ${e.message}', e, stackTrace);
      _showErrorSnackbar('Error al cargar usuarios', e.message);
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al cargar usuarios', 'Error desconocido');
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Crea un nuevo usuario en el sistema
  ///
  /// [email]: Correo electrónico del usuario
  /// [password]: Contraseña del usuario
  /// [username]: Nombre de usuario
  /// [isAdmin]: Si el usuario será administrador
  Future<void> addNewUser({
    required String email,
    required String password,
    required String username,
    bool isAdmin = false,
  }) async {
    isLoadingUsers.value = true;
    try {
      _logger.info('Creando usuario: $email (Admin: $isAdmin)');

      // Crear usuario usando privilegios de administrador
      final response = await _supabaseClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          userMetadata: {'username': username, 'is_admin': isAdmin},
          emailConfirm: true, // Confirmar email automáticamente
        ),
      );

      if (response.user == null) {
        throw Exception('Fallo en la creación del usuario');
      }

      // Registrar acción en auditoría
      await _logAdminAction(
        actionType: 'user_create',
        targetId: response.user!.id,
        description: 'Usuario creado: $email',
      );

      _showSuccessSnackbar(
          'Usuario creado', 'El usuario $username fue creado exitosamente');
      await fetchAllUsers();
    } on AuthException catch (e, stackTrace) {
      _logger.severe('Error de autenticación: ${e.message}', e, stackTrace);
      _showErrorSnackbar('Error al crear usuario', e.message);
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al crear usuario', 'Error desconocido');
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Elimina un usuario del sistema
  ///
  /// [userId]: ID del usuario a eliminar
  Future<void> deleteUser(String userId) async {
    isLoadingUsers.value = true;
    try {
      _logger.info('Eliminando usuario: $userId');

      // Eliminar usando privilegios de administrador
      await _supabaseClient.auth.admin.deleteUser(userId);

      // Registrar acción en auditoría
      await _logAdminAction(
        actionType: 'user_delete',
        targetId: userId,
        description: 'Usuario eliminado',
      );

      _showSuccessSnackbar(
          'Usuario eliminado', 'El usuario fue eliminado exitosamente');
      await fetchAllUsers();
    } on AuthException catch (e, stackTrace) {
      _logger.severe('Error de autenticación: ${e.message}', e, stackTrace);
      _showErrorSnackbar('Error al eliminar usuario', e.message);
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al eliminar usuario', 'Error desconocido');
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Cambia el estado de administrador de un usuario
  ///
  /// [userId]: ID del usuario
  /// [currentStatus]: Estado actual del usuario
  Future<void> toggleUserAdminStatus(String userId, bool currentStatus) async {
    isLoadingUsers.value = true;
    try {
      _logger
          .info('Cambiando estado de admin para $userId a ${!currentStatus}');

      await _supabaseClient
          .from('profiles')
          .update({'is_admin': !currentStatus}).eq('id', userId);

      // Registrar acción en auditoría
      await _logAdminAction(
        actionType: 'user_update',
        targetId: userId,
        description: 'Estado admin cambiado a ${!currentStatus}',
      );

      _showSuccessSnackbar(
          'Estado actualizado', 'Rol de administrador actualizado');
      await fetchAllUsers();
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe('Error de base de datos: ${e.message}', e, stackTrace);
      _showErrorSnackbar('Error al actualizar', e.message);
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al actualizar', 'Error desconocido');
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Obtiene dispositivos registrados
  Future<void> fetchRegisteredDevices() async {
    isLoadingDevices.value = true;
    try {
      _logger.info('Obteniendo dispositivos registrados...');
      final List<Map<String, dynamic>> data = await _supabaseClient
          .from('devices')
          .select('*')
          .order('created_at', ascending: false);

      registeredDevices.value = data;
      _logger.info('${registeredDevices.length} dispositivos obtenidos');
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe('Error de base de datos: ${e.message}', e, stackTrace);
      _showErrorSnackbar('Error al cargar dispositivos', e.message);
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al cargar dispositivos', 'Error desconocido');
    } finally {
      isLoadingDevices.value = false;
    }
  }

  /// Añade un nuevo dispositivo
  Future<void> addDevice({required String name, required String uuid}) async {
    isLoadingDevices.value = true;
    try {
      _logger.info('Añadiendo dispositivo: $name ($uuid)');

      await _supabaseClient.from('devices').insert({
        'name': name,
        'uuid': uuid,
      });

      // Registrar acción en auditoría
      await _logAdminAction(
        actionType: 'device_create',
        description: 'Dispositivo añadido: $name ($uuid)',
      );

      _showSuccessSnackbar(
          'Dispositivo añadido', '$name registrado exitosamente');
      await fetchRegisteredDevices();
    } on PostgrestException catch (e, stackTrace) {
      if (e.message.contains('duplicate key')) {
        _showErrorSnackbar('Error', 'UUID ya registrado');
      } else {
        _logger.severe('Error de base de datos: ${e.message}', e, stackTrace);
        _showErrorSnackbar('Error al añadir dispositivo', e.message);
      }
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al añadir dispositivo', 'Error desconocido');
    } finally {
      isLoadingDevices.value = false;
    }
  }

  /// Actualiza un dispositivo existente
  Future<void> updateDevice(String deviceId,
      {String? name, String? uuid}) async {
    isLoadingDevices.value = true;
    try {
      _logger.info('Actualizando dispositivo: $deviceId');

      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (uuid != null) updates['uuid'] = uuid;

      await _supabaseClient.from('devices').update(updates).eq('id', deviceId);

      // Registrar acción en auditoría
      await _logAdminAction(
        actionType: 'device_update',
        targetId: deviceId,
        description: 'Dispositivo actualizado',
      );

      _showSuccessSnackbar(
          'Dispositivo actualizado', 'Cambios guardados exitosamente');
      await fetchRegisteredDevices();
    } on PostgrestException catch (e, stackTrace) {
      if (e.message.contains('duplicate key')) {
        _showErrorSnackbar('Error', 'UUID ya registrado');
      } else {
        _logger.severe('Error de base de datos: ${e.message}', e, stackTrace);
        _showErrorSnackbar('Error al actualizar', e.message);
      }
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al actualizar', 'Error desconocido');
    } finally {
      isLoadingDevices.value = false;
    }
  }

  /// Elimina un dispositivo
  Future<void> deleteDevice(String deviceId) async {
    isLoadingDevices.value = true;
    try {
      _logger.info('Eliminando dispositivo: $deviceId');

      await _supabaseClient.from('devices').delete().eq('id', deviceId);

      // Registrar acción en auditoría
      await _logAdminAction(
        actionType: 'device_delete',
        targetId: deviceId,
        description: 'Dispositivo eliminado',
      );

      _showSuccessSnackbar('Dispositivo eliminado', 'Eliminado exitosamente');
      await fetchRegisteredDevices();
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe('Error de base de datos: ${e.message}', e, stackTrace);
      _showErrorSnackbar('Error al eliminar', e.message);
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado: $e', e, stackTrace);
      _showErrorSnackbar('Error al eliminar', 'Error desconocido');
    } finally {
      isLoadingDevices.value = false;
    }
  }

  /// Registra una acción administrativa en el log de auditoría
  Future<void> _logAdminAction({
    required String actionType,
    String? targetId,
    required String description,
  }) async {
    try {
      final adminId = Get.find<UserProfileService>().currentProfile.value?.id;
      if (adminId == null) {
        _logger.warning('No se pudo registrar acción: adminId es nulo');
        return;
      }

      await _supabaseClient.from('admin_audit_log').insert({
        'admin_id': adminId,
        'action_type': actionType,
        'target_id': targetId,
        'description': description,
      });
      _logger.info('Acción registrada: $actionType');
    } catch (e, stackTrace) {
      _logger.severe('Error al registrar acción: $e', e, stackTrace);
    }
  }

  // Métodos auxiliares para mostrar notificaciones
  void _showSuccessSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  void _showErrorSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}
