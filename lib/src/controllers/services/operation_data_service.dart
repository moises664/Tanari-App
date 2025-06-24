import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

/// Clase de modelo para representar una sesión de operación UGV.
/// Incluye información sobre el inicio/fin, modo de operación y ruta asociada.
class OperationSession {
  final String id;
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  String? operationName;
  String? description;
  String mode;
  int? routeNumber;

  OperationSession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.operationName,
    this.description,
    required this.mode,
    this.routeNumber,
  });

  /// Constructor para crear un objeto [OperationSession] desde un mapa de datos (ej. de Supabase).
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
    );
  }

  /// Convierte el objeto [OperationSession] a un mapa compatible con Supabase para inserción o actualización.
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
    };
  }
}

/// Servicio para gestionar sesiones de operación y datos de telemetría en Supabase.
///
/// Utiliza [GetxService] para una gestión sencilla del ciclo de vida y la inyección de dependencias.
class OperationDataService extends GetxService {
  final SupabaseClient _supabaseClient = Get.find<SupabaseClient>();
  final Logger _logger = Logger();

  /// Obtiene todas las sesiones del usuario actual ordenadas por fecha de inicio descendente.
  Future<List<OperationSession>> get userOperationSessions async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al obtener sesiones');
        return [];
      }

      final response = await _supabaseClient
          .from('operation_sessions')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false);

      return (response as List)
          .map((data) => OperationSession.fromMap(data))
          .toList();
    } catch (e, stackTrace) {
      _logger.e('Error en userOperationSessions: $e',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Obtiene una sesión de operación específica por su ID.
  ///
  /// Retorna [null] si la sesión no se encuentra o si el usuario no está autenticado.
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
          .single(); // Esperamos un solo resultado para un ID específico.

      return OperationSession.fromMap(response);
    } catch (e, stackTrace) {
      _logger.e('Error al obtener sesión $sessionId por ID: $e',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Crea una nueva sesión de operación en la base de datos.
  ///
  /// [operationName]: Nombre opcional de la operación.
  /// [description]: Descripción opcional de la operación.
  /// [mode]: Modo de operación (por defecto 'pending_record').
  /// [routeNumber]: Número de ruta opcional asociado a la operación.
  Future<OperationSession?> createOperationSession({
    String? operationName,
    String? description,
    String mode = 'pending_record',
    int? routeNumber,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al crear sesión');
        return null;
      }

      final response = await _supabaseClient
          .from('operation_sessions')
          .insert({
            'user_id': userId,
            'start_time': DateTime.now().toIso8601String(),
            'operation_name': operationName,
            'description': description,
            'mode': mode,
            'route_number': routeNumber,
          })
          .select()
          .single();

      _logger.i('Sesión creada: ${response['id']}');
      return OperationSession.fromMap(response);
    } catch (e, stackTrace) {
      _logger.e('Error al crear sesión: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene sesiones opcionalmente filtradas por modo (filtrado local).
  ///
  /// Nota: El filtrado por `mode` se realiza en la aplicación después de obtener
  /// todas las sesiones del usuario. Para grandes volúmenes de datos,
  /// sería más eficiente filtrar directamente en la consulta de Supabase.
  Future<List<OperationSession>> getOperationSessions({String? mode}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al obtener sesiones');
        return [];
      }

      // Obtener todas las sesiones sin filtrar por modo en la DB.
      final response = await _supabaseClient
          .from('operation_sessions')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false);

      // Convertir a objetos OperationSession
      final allSessions = (response as List)
          .map((data) => OperationSession.fromMap(data))
          .toList();

      // Aplicar filtro por modo si se especificó.
      return mode != null
          ? allSessions.where((session) => session.mode == mode).toList()
          : allSessions;
    } catch (e, stackTrace) {
      _logger.e('Error al obtener sesiones: $e',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Actualiza el estado del modo de una sesión específica.
  ///
  /// [sessionId]: ID de la sesión a actualizar.
  /// [newMode]: El nuevo modo a establecer para la sesión.
  Future<bool> updateOperationSessionMode(
      String sessionId, String newMode) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al actualizar sesión');
        return false;
      }

      final response = await _supabaseClient
          .from('operation_sessions')
          .update({'mode': newMode})
          .eq('id', sessionId)
          .eq('user_id', userId)
          .select();

      if (response.isNotEmpty) {
        _logger.i('Sesión $sessionId actualizada a modo $newMode');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error al actualizar sesión $sessionId: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Finaliza una sesión estableciendo su hora de finalización en la base de datos.
  ///
  /// [sessionId]: ID de la sesión a finalizar.
  Future<bool> endOperationSession(String sessionId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al finalizar sesión');
        return false;
      }

      final response = await _supabaseClient
          .from('operation_sessions')
          .update({'end_time': DateTime.now().toIso8601String()})
          .eq('id', sessionId)
          .eq('user_id', userId)
          .select();

      if (response.isNotEmpty) {
        _logger.i('Sesión $sessionId finalizada');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error al finalizar sesión $sessionId: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Elimina una sesión y sus datos asociados (telemetría UGV y lecturas de sensores).
  ///
  /// [sessionId]: ID de la sesión a eliminar.
  Future<bool> deleteOperationSession(String sessionId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('Usuario no autenticado al eliminar sesión');
        return false;
      }

      // Eliminar telemetría asociada (asumiendo que 'ugv_telemetry' tiene 'session_id')
      await _supabaseClient
          .from('ugv_telemetry')
          .delete()
          .eq('session_id', sessionId);

      // Eliminar sensor_readings asociados a la sesión
      await _supabaseClient
          .from('sensor_readings')
          .delete()
          .eq('session_id', sessionId);

      // Finalmente, eliminar la sesión principal
      final response = await _supabaseClient
          .from('operation_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', userId)
          .select();

      if (response.isNotEmpty) {
        _logger.i('Sesión $sessionId eliminada con éxito');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error al eliminar sesión $sessionId: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Registra una lectura de sensor en la base de datos para la tabla 'sensor_readings'.
  ///
  /// [sessionId]: ID de la sesión a la que pertenece esta lectura.
  /// [sensorType]: Tipo de sensor (ej. 'CO2', 'CH4', 'Temperatura', 'Humedad').
  /// [value]: Valor numérico de la lectura del sensor.
  /// [unit]: Unidad de medida del sensor (ej. 'ppm', 'ºC', '%').
  /// [timestamp]: Marca de tiempo de la lectura (por defecto, la hora actual).
  /// [batchSequence]: Número de secuencia para agrupar lecturas que llegan juntas.
  Future<bool> createSensorReading({
    required String sessionId,
    required String sensorType,
    required double value,
    String? unit,
    DateTime? timestamp,
    required int
        batchSequence, // Este es el parámetro crucial para la agrupación
  }) async {
    try {
      final response = await _supabaseClient.from('sensor_readings').insert({
        'session_id': sessionId,
        'sensor_type': sensorType,
        'sensor_value': value,
        'unit': unit,
        'timestamp':
            timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'batch_sequence':
            batchSequence, // ¡Importante: se inserta el batchSequence!
      }).select(); // Agregamos .select() para obtener la respuesta de la inserción y verificar si fue exitosa.

      if (response.isNotEmpty) {
        _logger.t(
            'Lectura registrada: $sensorType=$value${unit ?? ''} (Batch: $batchSequence) para sesión $sessionId');
        return true;
      }
      _logger.w(
          'La inserción de la lectura de sensor no devolvió datos para sesión $sessionId.');
      return false;
    } on PostgrestException catch (e, stackTrace) {
      _logger.e('Error de Postgrest al registrar sensor: ${e.message}',
          error: e, stackTrace: stackTrace);
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error inesperado al registrar sensor: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Obtiene todas las lecturas de sensores para una sesión específica, ordenadas por timestamp.
  ///
  /// [sessionId]: ID de la sesión de la que se quieren obtener las lecturas.
  Future<List<Map<String, dynamic>>> getSensorReadingsForSession(
      String sessionId) async {
    try {
      final response = await _supabaseClient
          .from('sensor_readings')
          .select()
          .eq('session_id', sessionId)
          .order('timestamp',
              ascending: true); // Ordenar por tiempo para los gráficos

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stackTrace) {
      _logger.e(
          'Error al obtener lecturas de sensor para sesión $sessionId: $e',
          error: e,
          stackTrace: stackTrace);
      return [];
    }
  }
}
