import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';

// Importaciones de controladores
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/routes/app_pages.dart'; // las rutas de la aplicación

// Constantes de la aplicación (¡Asegúrate que estas son EXACTAS a las de tu proyecto Supabase!)
const appTitle = 'TAnaRi';
const String SUPABASE_URL = 'https://pfhteyhxvetjhaitlucx.supabase.co';
const String SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmaHRleWh4dmV0amhhaXRsdWN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwNzMxMjcsImV4cCI6MjA2NDY0OTEyN30.93Ty5Z9JdUhHGFAgJkRW2yina0-WKkahqPC6QY9WTHk';

final _logger = Logger('Main');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración del logger para ver los mensajes en la consola
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print(record.error);
    }
    if (record.stackTrace != null) {
      print(record.stackTrace);
    }
  });

  // Inicialización de Supabase
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    debug: true,
  );

  // Inyecta AuthService y UserProfileService en GetX para que estén disponibles globalmente.
  Get.put(AuthService());
  Get.put(UserProfileService());
  Get.put(BleController()); // Nunca quitar el inicializador de Bluetooth

  // Ejecuta la aplicación
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute:
          Routes.initial, // La aplicación siempre comenzará en el SplashScreen
      getPages: AppPages.routes, // <--- ¡USAMOS AppPages.routes AQUÍ!
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
