// En HomeScreen.dart
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/home/home_tab.dart';
import 'package:tanari_app/src/screens/menu/acerca_app.dart';
import 'package:tanari_app/src/screens/menu/comunicacion_ble.dart';
import 'package:tanari_app/src/screens/menu/historial_app.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_monitoreo.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_acople.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_ugv.dart';
import 'package:tanari_app/src/screens/menu/profile_user.dart';
import 'package:get/get.dart'; // Importar Get para el Get.offAll

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Obtener la instancia del AuthService
  final AuthService _authService = Get.find<AuthService>();

  // 1. BottomNav: Variable para el índice seleccionado en el Bottom Navigation Bar
  int _selectedIndex = 0;

  // 2. BottomNav: Lista de widgets que representan cada pestaña del Bottom Navigation Bar
  final List<Widget> _widgetOptions = <Widget>[
    const HomeTab(),
    const ModoMonitoreo(),
    const ModoUgv(),
    const HistorialApp(),
    const ProfileUser(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Nuevo método para manejar el cierre de sesión con Supabase
  void _logout() async {
    // Cierra el Drawer primero para una mejor UX
    if (Scaffold.of(context).isDrawerOpen) {
      Navigator.pop(context);
    }

    // Llama al método signOut de tu AuthService
    await _authService.signOut();

    // El AuthService ya maneja la navegación a la pantalla de login en su listener
    // Si quieres forzar una navegación inmediata aquí, puedes usar:
    // Get.offAll(() => const SignInScreen());
    // Sin embargo, es más robusto dejar que el listener en AuthService se encargue,
    // ya que reaccionará al evento de cierre de sesión de Supabase.
  }

  @override
  Widget build(BuildContext context) {
    // === CAMBIO CLAVE: PopScope para interceptar el botón de regresar ===
    return PopScope(
      canPop: false, // Impide que el botón de regresar haga pop por defecto
      onPopInvoked: (didPop) {
        if (didPop) {
          return; // Ya se hizo pop, no hagas nada más
        }
        // Opcional: Mostrar un diálogo para confirmar si el usuario quiere salir
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Salir de la aplicación'),
            content: const Text('¿Estás seguro de que quieres salir?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () {
                  // Si el usuario confirma, sal de la aplicación
                  // SystemNavigator.pop() cierra la aplicación.
                  // Solo usar si quieres que la app se cierre completamente al pulsar atrás en Home
                  // Si prefieres que simplemente no haga nada, o que vaya al fondo, puedes omitirlo.
                  Navigator.of(context).pop(true); // Cierra el diálogo
                  // SystemNavigator.pop(); // Descomenta si quieres salir de la app
                },
                child: const Text('Sí'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(50)),
            ),
            child: const Text(
              'TANARI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.backgroundBlack,
              ),
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.backgroundPrimary,
          foregroundColor: AppColors.textPrimary,
          automaticallyImplyLeading:
              true, // Deja que Flutter decida si mostrar el botón del Drawer
        ),
        drawer: _menuHome(context), // Menú lateral

        bottomNavigationBar:
            _buildCustomBottomNavigationBar(context), // Botton Navigation Bar

        backgroundColor: Colors.white,

        body: _widgetOptions.elementAt(_selectedIndex),
      ),
    );
  }

  // Método que construye tu Bottom Navigation Bar personalizada
  Widget _buildCustomBottomNavigationBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: AppColors.backgroundBlack,
          borderRadius: const BorderRadius.all(Radius.circular(50.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 10.0,
              spreadRadius: 2.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, EvaIcons.home, 'Home'),
              _buildNavItem(1, Icons.phone_android, 'Dispositivo'),
              _buildNavItem(2, Icons.car_crash, 'UGV'),
              _buildNavItem(3, EvaIcons.book, 'Historial'),
              _buildNavItem(4, LineAwesome.user_solid, 'Usuario'),
            ],
          ),
        ),
      ),
    );
  }

  // Método auxiliar para construir cada ítem de la navegación
  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width:
            MediaQuery.of(context).size.width / 5 - (24 * 2 / 5) - (10 * 2 / 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.backgroundWhite,
              size: isSelected ? 28 : 24,
            ),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? AppColors.primary : AppColors.backgroundWhite,
                fontSize: isSelected ? 11 : 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // --- El resto de tu código para _menuHome (importante: modificaremos la opción de 'Cerrar sesión') ---
  Drawer _menuHome(BuildContext context) => Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          children: [
            // UserAccountsDrawerHeader debe mostrar los datos del usuario actual de Supabase
            // Tendrás que obtener el usuario de AuthService para esto.
            // Por ahora, lo dejamos con datos quemados, pero ten en cuenta la actualización futura.
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueGrey),
              accountName: Text(_authService
                      .currentUser.value?.userMetadata?['username'] ??
                  'Usuario Tanari'), // Ejemplo: si guardaste el username en user_metadata
              accountEmail: Text(_authService.currentUser.value?.email ??
                  'correo@ejemplo.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
            ExpansionTile(
              leading: const Icon(Icons.car_rental),
              title: const Text('Modos de Operacion'),
              children: <Widget>[
                ListTile(
                  title: const Text('Tanari DP'),
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => const ModoMonitoreo());
                  },
                ),
                ListTile(
                  title: const Text('Tanari UGV'),
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => const ModoUgv());
                  },
                ),
                ListTile(
                  title: const Text('Acople'),
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => const ModoAcople());
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              children: <Widget>[
                ListTile(
                  title: const Text('Historial de Monitoreo'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const HistorialMonitoreoScreen()));
                  },
                ),
                ListTile(
                  title: const Text('Rutas'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const HistorialRutasScreen()));
                  },
                ),
                ListTile(
                  title: const Text('Ubicación'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const HistorialUbicacionScreen()));
                  },
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('Comunicacion BLE'),
              onTap: () {
                Get.to(() => ComunicacionBleScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Acerca de'),
              onTap: () {
                Get.to(() => const AcercaApp());
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                // Llama al método _logout que ahora usa AuthService
                _logout();
              },
            ),
          ],
        ),
      );
}
