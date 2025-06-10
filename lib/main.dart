import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';

// Importaciones de controladores
import 'package:tanari_app/src/controllers/services/auth_service.dart';

// Importaciones de pantallas
import 'package:tanari_app/src/screens/login/welcome_screen.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart';
import 'package:tanari_app/src/screens/login/singin_screen.dart';
import 'package:tanari_app/src/screens/login/signup_screen.dart';
import 'package:tanari_app/src/screens/login/forget_password.dart';
import 'package:tanari_app/src/screens/login/splash_screen.dart'; // Importa tu SplashScreen

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

  // Inyecta AuthService en GetX para que esté disponible globalmente.
  // La lógica de inicialización de sesión se maneja en SplashScreen.
  Get.put(AuthService());

  Get.put(BleController()); //Nunca quitar el inicializador de Bluetooth

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
    // Eliminar cualquier lógica de inicialización o navegación que estaba aquí.
    // Toda la lógica de inicialización y navegación inicial ahora es responsabilidad del SplashScreen.
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
      initialRoute: '/', // La aplicación siempre comenzará en el SplashScreen
      getPages: [
        GetPage(
            name: '/',
            page: () =>
                const SplashScreen()), // Tu pantalla de carga inicial de Flutter
        GetPage(name: '/welcome', page: () => const WelcomeScreen()),
        GetPage(name: '/signIn', page: () => const SignInScreen()),
        GetPage(name: '/home', page: () => const HomeScreen()),
        GetPage(name: '/signup', page: () => const SignUpScreen()),
        GetPage(name: '/forgetPassword', page: () => const ForgetPassword()),
      ],
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
