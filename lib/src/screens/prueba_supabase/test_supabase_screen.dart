import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Si usas GetX
import 'package:tanari_app/src/services/api/supabase_test_service.dart'; // Importa tu nuevo servicio

class TestSupabaseScreen extends StatefulWidget {
  const TestSupabaseScreen({super.key});

  @override
  State<TestSupabaseScreen> createState() => _TestSupabaseScreenState();
}

class _TestSupabaseScreenState extends State<TestSupabaseScreen> {
  // Instancia del servicio de prueba de Supabase.
  // Get.put lo hace disponible para toda la app si usas GetX,
  // o puedes crear una instancia directamente si no.
  final SupabaseTestService _supabaseService = Get.put(SupabaseTestService());
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de Comunicación con Supabase'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Mensaje para Supabase',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_textController.text.isNotEmpty) {
                  await _supabaseService
                      .insertTestReading(_textController.text);
                  _textController.clear(); // Limpia el campo después de enviar
                } else {
                  Get.snackbar(
                    "Advertencia",
                    "Por favor, ingresa un mensaje.",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Enviar Dato de Prueba a Supabase',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              '¡Verifica la consola de Supabase (Table Editor -> test_readings) '
              'para confirmar que el dato se haya insertado!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
