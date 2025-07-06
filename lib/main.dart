//Main con ajustes para tener un buen flujo al inicializar las instancias.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/controllers/services/admin_services.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/operation_data_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/controllers/services/ugv_service.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart';
import 'package:tanari_app/src/screens/login/welcome_screen.dart';

const appTitle = 'TAnaRi';
// URL y clave anónima de Supabase. ¡Asegúrate de que estas sean correctas para tu proyecto!
const String supabaseUrl = 'https://pfhteyhxvetjhaitlucx.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmaHRleWh4dmV0amhhaXRsdWN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwNzMxMjcsImV4cCI6MjA2NDY0OTEyN30.93Ty5Z9JdUhHGFAgJkRW2yina0-WKkahqPC6QY9WTHk';

final _logger = Logger('Main'); // Logger para la función principal.

/// Punto de entrada principal de la aplicación Flutter.
/// Realiza la inicialización de Flutter, Supabase y las dependencias de GetX.
void main() async {
  // 1. Asegura que los bindings de Flutter estén inicializados.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Configura el sistema de logging para la aplicación.
  _configureLogging();

  try {
    // 3. Inicializa el cliente de Supabase.
    await _initializeSupabase();

    // 4. Inicializa y registra las dependencias de la aplicación con GetX.
    _initializeDependencies();

    // 5. Inicia la aplicación Flutter.
    runApp(const MyApp());
  } catch (e, stackTrace) {
    // Captura y registra cualquier error crítico durante la inicialización.
    _logger.severe('Error crítico durante la inicialización de la aplicación',
        e, stackTrace);
    // Podrías considerar mostrar una UI de error más amigable aquí si la app no puede iniciar.
  }
}

/// Configura el sistema de logging global para la aplicación.
/// Todos los logs se imprimirán en la consola de depuración.
void _configureLogging() {
  Logger.root.level =
      Level.ALL; // Establece el nivel más bajo para ver todos los logs.
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) debugPrint('Error: ${record.error}');
    if (record.stackTrace != null) debugPrint('Stack: ${record.stackTrace}');
  });
}

/// Inicializa el cliente de Supabase con la URL y la clave anónima proporcionadas.
/// Configura el tipo de flujo de autenticación como PKCE para mayor seguridad.
Future<void> _initializeSupabase() async {
  _logger.info('Inicializando Supabase...');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: true, // Habilita el modo de depuración para Supabase.
    authOptions: const FlutterAuthClientOptions(
      authFlowType:
          AuthFlowType.pkce, // Usar PKCE para un flujo de autenticación seguro.
      // Puedes añadir más configuraciones de auth aquí si es necesario, como `redirectToUrl`.
    ),
  );

  _logger.info('Supabase inicializado correctamente.');
}

/// Registra las dependencias de la aplicación utilizando GetX para la inyección de dependencias.
/// El orden de registro es crucial debido a las interdependencias entre los servicios.
void _initializeDependencies() {
  _logger.info('Registrando dependencias con GetX...');

  // 1. Registrar el cliente de Supabase. Es una dependencia fundamental para otros servicios.
  Get.put(Supabase.instance.client, permanent: true);

  // 2. Registrar UserProfileService. AuthService depende de él para la gestión de perfiles.
  Get.put(UserProfileService(), permanent: true);

  // 3. Registrar AuthService. Depende de SupabaseClient y UserProfileService.
  Get.put(AuthService(), permanent: true);

  // 4. Registrar AdminService. Depende de SupabaseClient y UserProfileService.
  Get.put(AdminService(), permanent: true); // <--- Nuevo servicio

  // 5. Registrar otros servicios de la aplicación.
  Get.put(BleController(), permanent: true);
  Get.put(OperationDataService(), permanent: true);
  Get.put(UgvService(), permanent: true);

  _logger.info('Dependencias registradas correctamente.');
}

/// [MyApp] es el widget raíz de la aplicación Flutter.
/// Configura el tema, las rutas y maneja la inicialización asíncrona de la aplicación.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false, // Desactiva la etiqueta de depuración.
      title: appTitle,
      theme: _buildAppTheme(), // Define el tema visual de la aplicación.
      initialRoute: Routes.initial, // Ruta inicial de la aplicación.
      getPages: AppPages.routes, // Lista de rutas definidas en AppPages.

      // Builder para asegurar que el escalado de texto sea consistente.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // Escala de texto fija.
          ),
          child: child ??
              _buildLoadingScreen(), // Muestra pantalla de carga si child es nulo.
        );
      },

      // FutureBuilder para manejar la inicialización asíncrona de la aplicación.
      home: FutureBuilder(
        future: _initializeApp(), // Llama al método de inicialización.
        builder: (context, snapshot) {
          // Muestra una pantalla de carga mientras la inicialización está en progreso.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }
          // Si hay un error durante la inicialización, muestra una pantalla de error.
          if (snapshot.hasError) {
            _logger.severe('Error en FutureBuilder de MyApp: ${snapshot.error}',
                snapshot.error, snapshot.stackTrace);
            return _buildErrorScreen(snapshot.error!);
          }
          // Una vez que la inicialización se completa, determina la pantalla inicial.
          return _determineInitialScreen();
        },
      ),
    );
  }

  /// Construye el tema visual de la aplicación.
  ThemeData _buildAppTheme() {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.backgroundWhite,
        secondary: AppColors.secondary,
        onSecondary: AppColors.backgroundWhite,
        surface: AppColors.backgroundWhite,
        error: AppColors.error,
        onError: AppColors.backgroundWhite,
      ),
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      fontFamily: 'Inter', // Fuente principal de la aplicación.
      useMaterial3: true, // Habilita Material 3.
    );
  }

  /// Realiza la inicialización asíncrona de la lógica de la aplicación
  /// después de que el árbol de widgets está montado.
  Future<void> _initializeApp() async {
    _logger.info('Iniciando _initializeApp (lógica de app)...');
    try {
      final authService = Get.find<AuthService>();
      // Llama a completeAppInitialization para que AuthService maneje la sesión y navegación.
      await authService.completeAppInitialization();
      _logger.info('_initializeApp completado.');
    } catch (e, stackTrace) {
      _logger.severe('Error en _initializeApp: $e', e, stackTrace);
      rethrow; // Re-lanza el error para que el FutureBuilder lo capture.
    }
  }

  /// Determina la pantalla inicial a mostrar basada en el estado de autenticación del usuario.
  Widget _determineInitialScreen() {
    final authService = Get.find<AuthService>();
    // Si el usuario está autenticado, va a la pantalla principal; de lo contrario, a la de bienvenida.
    return authService.isAuthenticated
        ? const HomeScreen()
        : const WelcomeScreen();
  }

  /// Construye la pantalla de carga que se muestra durante la inicialización.
  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.textPrimary),
            SizedBox(height: 20),
            Text(
              'Cargando Tanari...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una pantalla de error genérica para mostrar fallos críticos de inicialización.
  Widget _buildErrorScreen(Object error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: 20),
            Text(
              'Error de inicialización',
              style: TextStyle(
                fontSize: 24,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () =>
                  main(), // Permite al usuario reintentar la inicialización.
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'Reintentar',
                style:
                    TextStyle(fontSize: 18, color: AppColors.backgroundWhite),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
