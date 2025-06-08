import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart'; // Para Get.snackbar
import 'package:logger/logger.dart'; // Opcional, si lo añadiste

class SupabaseTestService extends GetxService {
  // Extiende GetxService si usas GetX
  // Obtiene la instancia del cliente Supabase inicializada en main.dart
  final _supabaseClient = Supabase.instance.client;
  final Logger _logger = Logger(); // Opcional: Instancia para logging

  /// Inserta un dato de prueba en la tabla 'test_readings'.
  Future<void> insertTestReading(String message) async {
    try {
      // Realiza la inserción en la tabla 'test_readings'
      await _supabaseClient
          .from('test readings') // Nombre de tu tabla de prueba
          .insert({
        'value': message, // El valor que vamos a insertar
      });

      // Si la inserción es exitosa, se llega a este punto
      _logger.i('Dato de prueba insertado exitosamente: "$message"');
      Get.snackbar(
        "Éxito",
        "Dato '$message' insertado en Supabase.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on PostgrestException catch (e) {
      // Manejo de errores específicos de Supabase (PostgreSQL)
      _logger.e('Error de Supabase al insertar dato: ${e.message}');
      Get.snackbar(
        "Error de Supabase",
        "No se pudo insertar el dato: ${e.message}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      // Manejo de cualquier otro tipo de error inesperado
      _logger.e('Error inesperado al insertar dato: $e');
      Get.snackbar(
        "Error Inesperado",
        "Ocurrió un error inesperado al insertar el dato: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
