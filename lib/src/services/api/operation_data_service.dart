import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/services/api/user_profile_service.dart';

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
  final UserProfileService _userProfileService = Get.find<UserProfileService>();
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
      final profile = _userProfileService.currentProfile.value;
      if (profile == null) {
        _logger.e(
            'Usuario no autenticado o perfil no cargado al obtener sesión por ID');
        return null;
      }

      var query = _supabaseClient
          .from('operation_sessions')
          .select()
          .eq('id', sessionId);

      if (!profile.isAdmin) {
        query = query.eq('user_id', profile.id);
      }

      final response = await query.maybeSingle();

      if (response == null) {
        _logger.w(
            'No se encontró la sesión $sessionId con los permisos actuales.');
        return null;
      }

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

  /// Actualiza una sesión existente.
  Future<bool> updateOperationSession({
    required String sessionId,
    String? newMode,
    String? newIndicator,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return false;
      final Map<String, dynamic> updates = {};
      if (newMode != null) updates['mode'] = newMode;
      if (newIndicator != null) updates['indicator'] = newIndicator;
      if (updates.isEmpty) return true;
      await _supabaseClient
          .from('operation_sessions')
          .update(updates)
          .eq('id', sessionId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      _logger.e('Error al actualizar sesión $sessionId: $e');
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
      // La tabla 'data_recuperada_ugv' tiene ON DELETE CASCADE, por lo que no es necesario
      // eliminar sus registros manualmente. Solo para 'sensor_readings'.
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

  /// Registra una lectura de sensor en la tabla 'sensor_readings'.
  Future<bool> createSensorReading({
    required String sessionId,
    required String sensorType,
    required double value,
    String? unit,
    DateTime? timestamp,
    required int batchSequence,
    double? latitude,
    double? longitude,
    String? source,
  }) async {
    try {
      final Map<String, dynamic> readingData = {
        'session_id': sessionId,
        'sensor_type': sensorType,
        'sensor_value': value,
        'unit': unit,
        'timestamp':
            timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'batch_sequence': batchSequence,
      };

      if (latitude != null) readingData['latitude'] = latitude;
      if (longitude != null) readingData['longitude'] = longitude;
      if (source != null) readingData['source'] = source;

      await _supabaseClient.from('sensor_readings').insert(readingData);
      return true;
    } catch (e) {
      _logger.e('Error al registrar sensor: $e');
      return false;
    }
  }

  /// Obtiene todas las lecturas de sensores para una sesión desde la tabla 'sensor_readings'.
  Future<List<Map<String, dynamic>>> getSensorReadingsForSession(
      String sessionId) async {
    if (sessionId.isEmpty) {
      _logger.w('Se intentó obtener lecturas con un sessionId vacío.');
      return [];
    }
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

  /// Obtiene los datos recuperados del UGV para una sesión específica desde la tabla 'data_recuperada_ugv'.
  Future<List<Map<String, dynamic>>> getRecoveredDataForSession(
      String sessionId) async {
    if (sessionId.isEmpty) {
      _logger.w('Se intentó obtener datos recuperados con un sessionId vacío.');
      return [];
    }
    try {
      final response = await _supabaseClient
          .from('data_recuperada_ugv')
          .select()
          .eq('session_id', sessionId)
          .order('timestamp', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _logger.e(
          'Error al obtener datos recuperados para la sesión $sessionId: $e');
      return [];
    }
  }

  /// Sube los datos recuperados del UGV a la nueva tabla 'data_recuperada_ugv'.
  Future<void> uploadRecoveredDataToNewTable(List<String> recoveredData,
      {required String name, required String description}) async {
    if (recoveredData.isEmpty) {
      _logger.i("No hay datos recuperados para subir.");
      return;
    }

    // 1. Crear una nueva sesión para estos datos
    final session = await createOperationSession(
      operationName: name,
      description: description,
      // --- Usar el valor correcto que ahora aceptará la DB ---
      mode: "data_recuperada",
    );

    if (session == null) {
      _logger.e("No se pudo crear una sesión para los datos recuperados.");
      Get.snackbar(
          "Error", "No se pudo crear una sesión para guardar los datos.");
      return;
    }

    // 2. Procesar y preparar los datos para la nueva tabla
    try {
      final List<Map<String, dynamic>> readingsToInsert = [];
      for (final line in recoveredData) {
        final values = line.split(';').map((v) => v.trim()).toList();

        int? routeNumber;
        Map<String, double?> sensorValues = {
          'co2': null,
          'ch4': null,
          'temperatura': null,
          'humedad': null
        };

        if (values.length == 6 &&
            values[0].startsWith('R') &&
            values[1].startsWith('P')) {
          routeNumber = int.tryParse(values[0].substring(1));
          sensorValues['co2'] = double.tryParse(values[2]);
          sensorValues['ch4'] = double.tryParse(values[3]);
          sensorValues['temperatura'] = double.tryParse(values[4]);
          sensorValues['humedad'] = double.tryParse(values[5]);
        } else if (values.length == 4) {
          sensorValues['co2'] = double.tryParse(values[0]);
          sensorValues['ch4'] = double.tryParse(values[1]);
          sensorValues['temperatura'] = double.tryParse(values[2]);
          sensorValues['humedad'] = double.tryParse(values[3]);
        } else {
          _logger.w(
              "Formato de línea de datos recuperados desconocido, se omite: $line");
          continue;
        }

        readingsToInsert.add({
          'session_id': session.id,
          'timestamp': DateTime.now().toIso8601String(),
          'co2': sensorValues['co2'],
          'ch4': sensorValues['ch4'],
          'temperatura': sensorValues['temperatura'],
          'humedad': sensorValues['humedad'],
          'numero_ruta': routeNumber,
        });
      }

      // 3. Insertar los datos en la nueva tabla
      if (readingsToInsert.isNotEmpty) {
        await _supabaseClient
            .from('data_recuperada_ugv') // Inserción en la tabla de telemetría
            .insert(readingsToInsert); // Inserción del lote de datos (JSON)
        _logger.i(
            "${readingsToInsert.length} registros de datos recuperados han sido subidos a la sesión ${session.id}.");
        Get.snackbar("Sincronización Exitosa",
            "Los datos recuperados se han subido a la nube.");
      }

      // 4. Finalizar la sesión inmediatamente
      await endOperationSession(session.id);
    } catch (e) {
      _logger.e("Error catastrófico al subir datos recuperados: $e");
      Get.snackbar("Error de Sincronización",
          "No se pudieron subir los datos recuperados.",
          backgroundColor: Colors.red, colorText: Colors.white);
      // Si falla, es buena idea eliminar la sesión que se creó para no dejar registros huérfanos.
      await deleteOperationSession(session.id);
    }
  }
}
