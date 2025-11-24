// admin_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:tanari_app/src/models/user_profile.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart'; // Importar OperationSession
import 'package:tanari_app/src/services/api/user_profile_service.dart';

/// Servicio para operaciones administrativas
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

  /// Crea un nuevo usuario invocando la Edge Function segura.
  Future<void> addNewUser({
    required String email,
    required String password,
    required String username,
    bool isAdmin = false,
  }) async {
    isLoadingUsers.value = true;
    try {
      _logger.info('Invocando Edge Function "create-user" para: $email');

      final response = await _supabaseClient.functions.invoke(
        'create-user', // Nombre de la Edge Function
        body: {
          'email': email,
          'password': password,
          'username': username,
          'makeAdmin': isAdmin, // Parámetro para crear el usuario como admin
        },
      );

      if (response.status != 200) {
        // Si la función devuelve un error, lo mostramos.
        final errorMessage =
            response.data['error'] ?? 'Error desconocido desde la función.';
        throw Exception(errorMessage);
      }

      await _logAdminAction(
        actionType: 'user_create',
        description: 'Usuario creado vía Edge Function: $email',
      );

      _showSuccessSnackbar('Usuario Creado',
          'Se ha enviado un correo de confirmación a $email.');
      await fetchAllUsers(); // Refrescar la lista de usuarios
    } catch (e, stackTrace) {
      _logger.severe(
          'Error al crear usuario vía Edge Function: $e', e, stackTrace);
      _showErrorSnackbar('Error al Crear Usuario', e.toString());
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Elimina un usuario invocando la Edge Function segura.
  Future<void> deleteUser(String userId) async {
    isLoadingUsers.value = true;
    try {
      _logger.info('Invocando Edge Function "delete-user" para el ID: $userId');

      final response = await _supabaseClient.functions.invoke(
        'delete-user', // Nombre de la Edge Function
        body: {'user_id': userId}, // Enviamos el ID del usuario a eliminar
      );

      if (response.status != 200) {
        final errorMessage =
            response.data['error'] ?? 'Error al eliminar usuario.';
        throw Exception(errorMessage);
      }

      await _logAdminAction(
        actionType: 'user_delete',
        targetId: userId,
        description: 'Usuario eliminado vía Edge Function',
      );
      _showSuccessSnackbar(
          'Usuario Eliminado', 'El usuario fue eliminado exitosamente.');
      await fetchAllUsers(); // Refrescar la lista de usuarios
    } catch (e, stackTrace) {
      _logger.severe(
          'Error al eliminar usuario vía Edge Function: $e', e, stackTrace);
      _showErrorSnackbar('Error al Eliminar', e.toString());
    } finally {
      isLoadingUsers.value = false;
    }
  }

  /// Cambia el estado de administrador de un usuario
  Future<void> toggleUserAdminStatus(String userId, bool currentStatus) async {
    isLoadingUsers.value = true;
    try {
      _logger
          .info('Cambiando estado de admin para $userId a ${!currentStatus}');
      // La política RLS 'Admins can update any profile' permite esta operación.
      await _supabaseClient
          .from('profiles')
          .update({'is_admin': !currentStatus}).eq('id', userId);
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
      await _supabaseClient
          .from('devices')
          .insert({'name': name, 'uuid': uuid});
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

  /// Obtiene únicamente la lista de UUIDs de los dispositivos registrados.
  Future<List<String>> fetchDeviceUuids() async {
    try {
      _logger.info('Obteniendo solo los UUIDs de los dispositivos...');
      final List<Map<String, dynamic>> data =
          await _supabaseClient.from('devices').select('uuid');
      if (data.isEmpty) {
        return [];
      }
      final uuids = data.map((item) => item['uuid'] as String).toList();
      _logger.info('${uuids.length} UUIDs obtenidos.');
      return uuids;
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe('Error al obtener UUIDs de dispositivos: ${e.message}', e,
          stackTrace);
      _showErrorSnackbar('Error al cargar UUIDs', e.message);
      return [];
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado al obtener UUIDs: $e', e, stackTrace);
      _showErrorSnackbar('Error al cargar UUIDs', 'Error desconocido');
      return [];
    }
  }

  // ----- INICIO: IMPLEMENTACIÓN CORREGIDA -----
  /// Obtiene todas las sesiones de operación para un usuario específico (solo para Admins)
  Future<List<OperationSession>> fetchUserSessions(String userId) async {
    try {
      _logger.info('Admin obteniendo sesiones para el usuario: $userId');
      final List<dynamic> data = await _supabaseClient
          .from('operation_sessions')
          .select('*')
          .eq('user_id', userId)
          .order('start_time', ascending: false);

      // Convierte los datos crudos (List<Map<String, dynamic>>) a una lista de OperationSession
      return data.map((json) => OperationSession.fromMap(json)).toList();
    } on PostgrestException catch (e, stackTrace) {
      _logger.severe(
          'Error al obtener sesiones para el usuario $userId: ${e.message}',
          e,
          stackTrace);
      _showErrorSnackbar('Error al cargar sesiones', e.message);
      // DEVUELVE UNA LISTA VACÍA EN CASO DE ERROR PARA EVITAR EL TYPEERROR
      return [];
    } catch (e, stackTrace) {
      _logger.severe('Error inesperado al obtener sesiones para $userId: $e', e,
          stackTrace);
      _showErrorSnackbar('Error al cargar sesiones', 'Error desconocido');
      // DEVUELVE UNA LISTA VACÍA EN CASO DE ERROR
      return [];
    }
  }
  // ----- FIN: IMPLEMENTACIÓN CORREGIDA -----

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
