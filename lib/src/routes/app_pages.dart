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
import 'package:tanari_app/src/screens/menu/map_tanari_screen.dart';
import 'package:tanari_app/src/screens/menu/modos_historial/sessions_history_screen.dart';
import 'package:tanari_app/src/screens/menu/modos_historial/ugv_routes_screen.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_acople.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_monitoreo.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_ugv.dart';
import 'package:tanari_app/src/screens/menu/profile_screen.dart';
import 'package:tanari_app/src/screens/menu/roles/admin_screen.dart';

/// **Clase Abstracta de Rutas Nombradas (`Routes`)**
///
/// Centraliza todas las constantes de las rutas nombradas utilizadas en la aplicación.
/// Usar constantes en lugar de strings directos previene errores tipográficos y
/// facilita el mantenimiento y la refactorización de la navegación.
abstract class Routes {
  // Rutas de Autenticación y Bienvenida
  static const String initial = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/signIn';
  static const String signUp = '/signUp';
  static const String forgetPassword = '/forgetPassword';
  static const String changePassword = '/changePassword';

  // Ruta Principal
  static const String home = '/home';

  // Rutas del Menú Lateral (Drawer)
  static const String profile = '/profile';
  static const String acercaApp = '/acercaApp';
  static const String modoAcople = '/modoAcople';

  /// **CORREGIDO:** Se ha corregido el error tipográfico de "Hitorial" a "Historial".
  static const String sessionsHistorial = '/sessionsHistorial';
  static const String ugvRoute = '/ugvRoute';
  static const String adminPanel = '/admin-panel';

  // Rutas de la Barra de Navegación Inferior (pueden o no tener rutas nombradas)
  static const String comunicacionBle = '/comunicacionBle';
  static const String modoMonitoreo = '/modoMonitoreo';
  static const String modoUgv = '/modoUgv';
  static const String ubicacionGps = '/ubicacionGps';
  static const String mapaTanari = '/mapaTanari';
}

/// **Configuración de Páginas y Rutas de la Aplicación (`AppPages`)**
///
/// Define la lista de todas las páginas (`GetPage`) disponibles en la aplicación.
/// Cada `GetPage` asocia una ruta nombrada (de la clase `Routes`) con el widget
/// de la pantalla correspondiente y permite configurar transiciones y otros
/// parámetros de navegación de GetX.
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
      page: () => const SignInScreen(),
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
      // **CORREGIDO:** Apunta a la constante corregida.
      name: Routes.sessionsHistorial,
      page: () => const SessionsHistoryScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.ugvRoute,
      page: () => const UgvRoutesScreen(),
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
    GetPage(
      name: Routes.adminPanel,
      page: () => const AdminScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.mapaTanari,
      page: () => MapTanariScreen(
        sessionId: '',
      ),
      transition: Transition.fadeIn,
    ),
  ];
}
