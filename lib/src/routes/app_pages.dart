// lib/src/routes/app_pages.dart

import 'package:get/get.dart';
import 'package:tanari_app/src/screens/login/welcome_screen.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart';
import 'package:tanari_app/src/screens/login/singin_screen.dart';
import 'package:tanari_app/src/screens/login/signup_screen.dart';
import 'package:tanari_app/src/screens/login/forget_password.dart';
import 'package:tanari_app/src/screens/login/splash_screen.dart';
import 'package:tanari_app/src/screens/menu/profile_user_screen.dart'; // Importa la pantalla de perfil
import 'package:tanari_app/src/screens/menu/acerca_app.dart'; // Importa tus otras pantallas para rutas
import 'package:tanari_app/src/screens/menu/comunicacion_ble.dart';
import 'package:tanari_app/src/screens/menu/historial_app.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_acople.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_monitoreo.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_ugv.dart';

// Abstract class para definir los nombres de las rutas
abstract class Routes {
  static const String initial = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/signIn';
  static const String home = '/home';
  static const String signUp = '/signup';
  static const String forgetPassword = '/forgetPassword';
  static const String profile = '/profile'; // Nueva ruta para el perfil
  static const String acercaApp = '/acercaApp';
  static const String comunicacionBle = '/comunicacionBle';
  static const String historialApp = '/historialApp';
  static const String modoAcople = '/modoAcople';
  static const String modoMonitoreo = '/modoMonitoreo';
  static const String modoUgv = '/modoUgv';
}

// Lista de GetPage para el GetMaterialApp
class AppPages {
  static final List<GetPage> routes = [
    GetPage(name: Routes.initial, page: () => const SplashScreen()),
    GetPage(name: Routes.welcome, page: () => const WelcomeScreen()),
    GetPage(name: Routes.signIn, page: () => const SignInScreen()),
    GetPage(name: Routes.home, page: () => const HomeScreen()),
    GetPage(name: Routes.signUp, page: () => const SignUpScreen()),
    GetPage(name: Routes.forgetPassword, page: () => const ForgetPassword()),
    GetPage(
        name: Routes.profile,
        page: () => ProfileUserScreen()), // Define la ruta del perfil
    GetPage(name: Routes.acercaApp, page: () => const AcercaApp()),
    GetPage(name: Routes.comunicacionBle, page: () => ComunicacionBleScreen()),
    GetPage(name: Routes.historialApp, page: () => const HistorialApp()),
    GetPage(name: Routes.modoAcople, page: () => const ModoAcople()),
    GetPage(name: Routes.modoMonitoreo, page: () => const ModoMonitoreo()),
    GetPage(name: Routes.modoUgv, page: () => const ModoUgv()),
  ];
}
