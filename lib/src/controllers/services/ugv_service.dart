import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

/// Servicio para gestionar los datos de telemetría del UGV con Supabase.
class UgvService extends GetxService {
  final SupabaseClient _supabaseClient = Get.find<SupabaseClient>();
  final Logger _logger = Logger();

  /// Crea un nuevo registro de telemetría para el UGV.
  Future<bool> createUgvTelemetry({
    required String sessionId,
    required String commandType,
    required String commandValue,
    required DateTime timestamp,
    String status = 'enviado',
    String? ugvId, // ID del UGV (ej. dirección MAC)
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('No hay usuario autenticado para registrar telemetría.');
        return false;
      }

      final response = await _supabaseClient.from('ugv_telemetry').insert({
        'session_id': sessionId,
        'user_id': userId, // Asociar telemetría al usuario también
        'timestamp': timestamp.toIso8601String(),
        'command_type': commandType,
        'command_value': commandValue,
        'status': status,
        'ugv_id': ugvId,
        'notes': notes,
        'latitude': latitude,
        'longitude': longitude,
      }).select(); // Select para obtener el registro insertado y confirmar

      if (response.isNotEmpty) {
        _logger.i(
            'Telemetría UGV registrada para sesión $sessionId: $commandValue');
        return true;
      } else {
        _logger.e('Respuesta nula al registrar telemetría UGV.');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error al registrar telemetría UGV para sesión $sessionId: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Obtiene los datos de telemetría para una sesión específica.
  Future<List<Map<String, dynamic>>> getUgvTelemetry(
      {required String sessionId}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        _logger.e('No hay usuario autenticado para obtener telemetría.');
        return [];
      }

      final List<Map<String, dynamic>> response = await _supabaseClient
          .from('ugv_telemetry')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id',
              userId) // Asegurarse de obtener solo la telemetría del usuario
          .order('timestamp',
              ascending:
                  true); // Ordenar por timestamp para la secuencia correcta de comandos

      _logger.i(
          'Obtenidos ${response.length} registros de telemetría para sesión $sessionId.');
      return response;
    } catch (e, stackTrace) {
      _logger.e('Error al obtener telemetría UGV para sesión $sessionId: $e',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Puedes añadir más métodos aquí si necesitas actualizar o eliminar telemetría específica.
}
