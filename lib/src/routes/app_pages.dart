import 'package:get/get.dart';
import 'package:tanari_app/src/models/change_password_screen.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart';
import 'package:tanari_app/src/screens/login/forget_password.dart';
import 'package:tanari_app/src/screens/login/signup_screen.dart';
import 'package:tanari_app/src/screens/login/singin_screen.dart';
import 'package:tanari_app/src/screens/login/splash_screen.dart';
import 'package:tanari_app/src/screens/login/welcome_screen.dart';
import 'package:tanari_app/src/screens/menu/acerca_app.dart';
import 'package:tanari_app/src/screens/menu/comunicacion_ble.dart';
import 'package:tanari_app/src/screens/menu/historial_app.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_acople.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_monitoreo.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_ugv.dart';
import 'package:tanari_app/src/screens/menu/profile_screen.dart';

/// Nombres de rutas abstractos para la aplicación
///
/// Cada constante representa una ruta nombrada que puede ser utilizada
/// para la navegación en la aplicación.
abstract class Routes {
  static const String initial = '/';
  static const String welcome = '/welcome';
  static const String signIn =
      '/signIn'; // <--- Nombre de ruta para Iniciar Sesión
  static const String home = '/home';
  static const String signUp =
      '/signUp'; // <--- Nombre de ruta para Registrarse (Mantener 'signUp' para consistencia con la clase)
  static const String forgetPassword = '/forgetPassword';
  static const String changePassword = '/changePassword';
  static const String profile = '/profile';
  static const String acercaApp = '/acercaApp';
  static const String comunicacionBle = '/comunicacionBle';
  static const String historialApp = '/historialApp';
  static const String modoAcople = '/modoAcople';
  static const String modoMonitoreo = '/modoMonitoreo';
  static const String modoUgv = '/modoUgv';
}

/// Configuración de rutas de la aplicación
///
/// Define todas las rutas disponibles con sus respectivas pantallas
/// y transiciones de navegación.
class AppPages {
  static final List<GetPage> routes = [
    GetPage(
      name: Routes.initial,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: Routes.welcome,
      page: () => const WelcomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.signIn,
      page: () =>
          const SignInScreen(), // <--- ¡CORREGIDO! Ahora apunta a SignInScreen
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.signUp,
      page: () => const SignUpScreen(),
      transition: Transition.leftToRight,
    ),
    GetPage(
      name: Routes.forgetPassword,
      page: () => const ForgetPassword(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.changePassword,
      page: () => const ChangePasswordScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.profile,
      page: () => const ProfileScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.acercaApp,
      page: () => const AcercaApp(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.comunicacionBle,
      page: () => ComunicacionBleScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.historialApp,
      page: () => const HistorialApp(),
      transition: Transition.leftToRight,
    ),
    GetPage(
      name: Routes.modoAcople,
      page: () => const ModoAcople(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.modoMonitoreo,
      page: () => const ModoMonitoreo(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.modoUgv,
      page: () => const ModoUgv(),
      transition: Transition.fadeIn,
    ),
  ];
}
