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
import 'package:get/get.dart';

/// Pantalla principal de la aplicación después del login.
/// Muestra un menú lateral (Drawer) y una barra de navegación inferior personalizada.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Obtener la instancia del AuthService usando GetX
  final AuthService _authService = Get.find<AuthService>();

  // DECLARACIÓN DE LA GLOBALKEY PARA EL SCAFFOLD
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Variable para el índice seleccionado en el Bottom Navigation Bar
  int _selectedIndex = 0;

  // Lista de widgets que representan cada pestaña del Bottom Navigation Bar
  final List<Widget> _widgetOptions = <Widget>[
    const HomeTab(),
    const ModoMonitoreo(),
    const ModoUgv(),
    const HistorialApp(),
    const ProfileUser(),
  ];

  /// Maneja el cambio de pestaña en la barra de navegación inferior
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Utilizamos PopScope para interceptar el botón de regresar del dispositivo
    return PopScope(
      canPop: false, // Impide que el botón de regresar haga pop por defecto
      onPopInvoked: (didPop) {
        if (didPop) return;

        // Muestra diálogo de confirmación al intentar salir
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
                  Navigator.of(context).pop(true);
                  // Para cerrar completamente la app:
                  // SystemNavigator.pop();
                },
                child: const Text('Sí'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        key: _scaffoldKey, // ASIGNAR LA GLOBALKEY AL SCAFFOLD
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
          automaticallyImplyLeading: true,
        ),
        drawer: _buildMenuDrawer(context), // Menú lateral
        bottomNavigationBar:
            _buildCustomBottomNavigationBar(context), // Barra inferior
        backgroundColor: Colors.white,
        body: _widgetOptions.elementAt(_selectedIndex), // Contenido principal
      ),
    );
  }

  /// Construye la barra de navegación inferior personalizada
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

  /// Construye un ítem individual de la barra de navegación
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

  /// Construye el menú lateral (Drawer)
  Drawer _buildMenuDrawer(BuildContext context) => Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          children: [
            // Cabecera con información del usuario
            Obx(() {
              final user =
                  _authService.currentUser; // <-- CORRECCIÓN FINAL AQUÍ
              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.blueGrey),
                accountName:
                    Text(user?.userMetadata?['username'] ?? 'Usuario Tanari'),
                accountEmail: Text(user?.email ?? 'correo@ejemplo.com'),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
              );
            }),

            // Sección de Modos de Operación
            ExpansionTile(
              leading: const Icon(Icons.car_rental),
              title: const Text('Modos de Operacion'),
              children: <Widget>[
                ListTile(
                  title: const Text('Tanari DP'),
                  onTap: () {
                    // Cierra el drawer usando la GlobalKey
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.to(() => const ModoMonitoreo());
                  },
                ),
                ListTile(
                  title: const Text('Tanari UGV'),
                  onTap: () {
                    // Cierra el drawer usando la GlobalKey
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.to(() => const ModoUgv());
                  },
                ),
                ListTile(
                  title: const Text('Acople'),
                  onTap: () {
                    // Cierra el drawer usando la GlobalKey
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.to(() => const ModoAcople());
                  },
                ),
              ],
            ),

            // Sección de Historial
            ExpansionTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              children: <Widget>[
                ListTile(
                  title: const Text('Historial de Monitoreo'),
                  onTap: () {
                    // Cierra el drawer usando la GlobalKey
                    _scaffoldKey.currentState?.closeDrawer();
                    // Implementar navegación a Historial de Monitoreo
                  },
                ),
                ListTile(
                  title: const Text('Rutas'),
                  onTap: () {
                    // Cierra el drawer usando la GlobalKey
                    _scaffoldKey.currentState?.closeDrawer();
                    // Implementar navegación a Rutas
                  },
                ),
                ListTile(
                  title: const Text('Ubicación'),
                  onTap: () {
                    // Cierra el drawer usando la GlobalKey
                    _scaffoldKey.currentState?.closeDrawer();
                    // Implementar navegación a Ubicación
                  },
                ),
              ],
            ),

            // Comunicación BLE
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('Comunicacion BLE'),
              onTap: () {
                // Cierra el drawer usando la GlobalKey
                _scaffoldKey.currentState?.closeDrawer();
                Get.to(() => ComunicacionBleScreen());
              },
            ),

            // Acerca de
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Acerca de'),
              onTap: () {
                // Cierra el drawer usando la GlobalKey
                _scaffoldKey.currentState?.closeDrawer();
                Get.to(() => const AcercaApp());
              },
            ),

            // Cerrar sesión - SOLUCIÓN FINAL CON GLOBALKEY
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                // CIERRA EL DRAWER USANDO LA GLOBALKEY
                _scaffoldKey.currentState?.closeDrawer();

                // Cerramos la sesión usando AuthService
                await _authService.signOut();
              },
            ),
          ],
        ),
      );
}
