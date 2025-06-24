import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/controllers/services/operation_data_service.dart';
import 'package:tanari_app/src/controllers/services/ugv_service.dart';
import 'package:tanari_app/src/routes/app_pages.dart';

const appTitle = 'TAnaRi';
const String supabaseUrl = 'https://pfhteyhxvetjhaitlucx.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmaHRleWh4dmV0amhhaXRsdWN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwNzMxMjcsImV4cCI6MjA2NDY0OTEyN30.93Ty5Z9JdUhHGFAgJkRW2yina0-WKkahqPC6QY9WTHk';

final _logger = Logger('Main');

/// Punto de entrada principal de la aplicación
///
/// Responsabilidades:
///   - Inicializar Flutter Engine
///   - Configurar logging
///   - Inicializar Supabase
///   - Registrar dependencias con GetX
///   - Ejecutar la aplicación con GetMaterialApp
///
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración del sistema de logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) debugPrint('${record.error}');
    if (record.stackTrace != null) debugPrint('${record.stackTrace}');
  });

  try {
    // Inicialización de Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );

    // Registro de dependencias globales
    Get.put(Supabase.instance.client, permanent: true);
    Get.put(AuthService(), permanent: true);
    Get.put(UserProfileService(), permanent: true);
    Get.put(BleController(), permanent: true);
    Get.put(OperationDataService(), permanent: true);
    Get.put(UgvService(), permanent: true);

    _logger.info('Dependencias inicializadas correctamente');
  } catch (e, stackTrace) {
    _logger.severe('Error durante la inicialización', e, stackTrace);
  }

  runApp(const MyApp());
}

/// Widget raíz de la aplicación
///
/// Utiliza GetMaterialApp en lugar de MaterialApp para habilitar:
///   - Navegación con GetX
///   - Inyección de dependencias
///   - Gestión de rutas
///   - Snackbars y diálogos globales
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: Routes.initial,
      getPages: AppPages.routes,
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
