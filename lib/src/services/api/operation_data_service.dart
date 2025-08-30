import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

/// Clase de modelo para representar una sesión de operación UGV.
class OperationSession {
  final String id;
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  String? operationName;
  String? description;
  String mode;
  int? routeNumber;
  final String? indicator;

  OperationSession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.operationName,
    this.description,
    required this.mode,
    this.routeNumber,
    this.indicator,
  });

  factory OperationSession.fromMap(Map<String, dynamic> data) {
    return OperationSession(
      id: data['id'],
      userId: data['user_id'],
      startTime: DateTime.parse(data['start_time']),
      endTime:
          data['end_time'] != null ? DateTime.parse(data['end_time']) : null,
      operationName: data['operation_name'],
      description: data['description'],
      mode: data['mode'] ?? 'unknown',
      routeNumber: data['route_number'],
      indicator: data['indicator'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'operation_name': operationName,
      'description': description,
      'mode': mode,
      'route_number': routeNumber,
      'indicator': indicator,
    };
  }
}

/// Servicio para gestionar sesiones de operación y datos de telemetría en Supabase.
class OperationDataService extends GetxService {
  final SupabaseClient _supabaseClient = Get.find<SupabaseClient>();
  final Logger _logger = Logger();

  /// Obtiene todas las sesiones del usuario actual.
  Future<List<OperationSession>> get userOperationSessions async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return [];
      final response = await _supabaseClient
          .from('operation_sessions')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false);
      return (response as List)
          .map((data) => OperationSession.fromMap(data))
          .toList();
    } catch (e) {
      _logger.e('Error en userOperationSessions: $e');
      return [];
    }
  }

  /// Obtiene una sesión de operación específica por su ID.
  Future<OperationSession?> getSessionById(String sessionId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al obtener sesión por ID');
        return null;
      }

      final response = await _supabaseClient
          .from('operation_sessions')
          .select()
          .eq('id', sessionId)
          .eq('user_id', userId)
          .single();

      return OperationSession.fromMap(response);
    } catch (e, stackTrace) {
      _logger.e('Error al obtener sesión $sessionId por ID: $e',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Crea una nueva sesión de operación.
  Future<OperationSession?> createOperationSession({
    String? operationName,
    String? description,
    String mode = 'pending_record',
    int? routeNumber,
    String? indicator,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await _supabaseClient
          .from('operation_sessions')
          .insert({
            'user_id': userId,
            'start_time': DateTime.now().toIso8601String(),
            'operation_name': operationName,
            'description': description,
            'mode': mode,
            'route_number': routeNumber,
            'indicator': indicator,
          })
          .select()
          .single();
      _logger.i('Sesión creada: ${response['id']}');
      return OperationSession.fromMap(response);
    } catch (e) {
      _logger.e('Error al crear sesión: $e');
      return null;
    }
  }

  /// Actualiza una sesión existente con un nuevo modo y/o un nuevo indicador.
  Future<bool> updateOperationSession({
    required String sessionId,
    String? newMode,
    String? newIndicator,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al actualizar sesión');
        return false;
      }

      final Map<String, dynamic> updates = {};
      if (newMode != null) {
        updates['mode'] = newMode;
      }
      if (newIndicator != null) {
        updates['indicator'] = newIndicator;
      }

      if (updates.isEmpty) {
        _logger.w('Intento de actualizar sesión $sessionId sin cambios.');
        return true;
      }

      await _supabaseClient
          .from('operation_sessions')
          .update(updates)
          .eq('id', sessionId)
          .eq('user_id', userId);

      _logger.i('Sesión $sessionId actualizada con: $updates');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error al actualizar sesión $sessionId: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Obtiene sesiones, opcionalmente filtradas por modo.
  Future<List<OperationSession>> getOperationSessions({String? mode}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return [];
      final response = await _supabaseClient
          .from('operation_sessions')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false);
      final allSessions = (response as List)
          .map((data) => OperationSession.fromMap(data))
          .toList();
      return mode != null
          ? allSessions.where((session) => session.mode == mode).toList()
          : allSessions;
    } catch (e) {
      _logger.e('Error al obtener sesiones: $e');
      return [];
    }
  }

  /// Finaliza una sesión estableciendo su hora de finalización.
  Future<bool> endOperationSession(String sessionId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return false;
      await _supabaseClient
          .from('operation_sessions')
          .update({'end_time': DateTime.now().toIso8601String()})
          .eq('id', sessionId)
          .eq('user_id', userId);
      _logger.i('Sesión $sessionId finalizada');
      return true;
    } catch (e) {
      _logger.e('Error al finalizar sesión $sessionId: $e');
      return false;
    }
  }

  /// Elimina una sesión y sus datos asociados.
  Future<bool> deleteOperationSession(String sessionId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return false;
      await _supabaseClient
          .from('sensor_readings')
          .delete()
          .eq('session_id', sessionId);
      await _supabaseClient
          .from('operation_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', userId);
      _logger.i('Sesión $sessionId eliminada');
      return true;
    } catch (e) {
      _logger.e('Error al eliminar sesión $sessionId: $e');
      return false;
    }
  }

  /// Registra una lectura de sensor.
  Future<bool> createSensorReading({
    required String sessionId,
    required String sensorType,
    required double value,
    String? unit,
    DateTime? timestamp,
    required int batchSequence,
  }) async {
    try {
      await _supabaseClient.from('sensor_readings').insert({
        'session_id': sessionId,
        'sensor_type': sensorType,
        'sensor_value': value,
        'unit': unit,
        'timestamp':
            timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'batch_sequence': batchSequence,
      });
      return true;
    } catch (e) {
      _logger.e('Error al registrar sensor: $e');
      return false;
    }
  }

  /// Obtiene todas las lecturas de sensores para una sesión.
  Future<List<Map<String, dynamic>>> getSensorReadingsForSession(
      String sessionId) async {
    try {
      final response = await _supabaseClient
          .from('sensor_readings')
          .select()
          .eq('session_id', sessionId)
          .order('timestamp', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _logger
          .e('Error al obtener lecturas de sensor para sesión $sessionId: $e');
      return [];
    }
  }
}
