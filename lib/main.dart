// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // <--- ¡Asegúrate de importar GetX!
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/screens/login/welcome_screen.dart';
import 'package:tanari_app/src/screens/prueba_supabase/test_supabase_screen.dart';

const appTitle = 'TAnaRi';
const String SUPABASE_URL = 'https://pfhteyhxvetjhaitlucx.supabase.co';
const String SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmaHRleWh4dmV0amhhaXRsdWN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwNzMxMjcsImV4cCI6MjA2NDY0OTEyN30.93Ty5Z9JdUhHGFAgJkRW2yina0-WKkahqPC6QY9WTHk';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Supabase con tu URL y clave anónima
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    debug:
        true, // Esto te mostrará logs de Supabase en la consola de depuración
  );

  // Inicialización controlada de controladores
  await _initializeApp();

  runApp(const MyApp());
}

final _logger = Logger('Main');

Future<void> _initializeApp() async {
  try {
    await Get.putAsync<BleController>(() async => BleController());
  } catch (e) {
    _logger.severe('Error initializing controllers', e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // <--- ¡CAMBIADO A GETMATERIALAPP!
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const TestSupabaseScreen(),
      // Pantalla de carga inicial
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
