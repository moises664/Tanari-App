import 'dart:io'; // Para usar exit(0) al cerrar la aplicación
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/home/home_tab.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/screens/menu/comunicacion_ble.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_monitoreo.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_ugv.dart';
import 'package:tanari_app/src/screens/menu/roles/admin_screen.dart';
import 'package:tanari_app/src/services/api/auth_service.dart';
import 'package:tanari_app/src/services/api/user_profile_service.dart';

/// **Pantalla Principal de la Aplicación (`HomeScreen`)**
///
/// Actúa como el contenedor principal con una barra de navegación inferior (`BottomNavigationBar`)
/// y un menú lateral (`Drawer`). Gestiona la visualización de las diferentes
/// pestañas principales de la aplicación.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = Get.find<AuthService>();
  final UserProfileService _userProfileService = Get.find<UserProfileService>();

  // Clave global para el Scaffold, necesaria para controlar el Drawer programáticamente.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Índice de la pestaña actualmente seleccionada en la barra de navegación inferior.
  int _selectedIndex = 0;

  // Lista de widgets que corresponden a cada una de las pestañas de la barra de navegación.
  final List<Widget> _widgetOptions = <Widget>[
    const HomeTab(),
    const ModoMonitoreo(), // Pantalla del Modo DP
    const ModoUgv(), // Pantalla del Modo UGV
    ComunicacionBleScreen(), // Pantalla de Conexión BLE
  ];

  /// Callback que se ejecuta cuando se toca un ítem de la barra de navegación inferior.
  /// Actualiza el estado `_selectedIndex` para cambiar la pantalla visible.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Evita que el usuario salga de la app con el botón de retroceso sin confirmación.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final bool? shouldExit = await showDialog<bool>(
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
                  Get.find<AuthService>().signOut();
                },
                child: const Text('Sí'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          exit(0); // Cierra la aplicación completamente.
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text(
            'TANARI',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.backgroundBlack,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.backgroundPrimary,
          foregroundColor: AppColors.textPrimary,
          automaticallyImplyLeading: true,
        ),
        // Menú lateral (Drawer)
        drawer: _buildMenuDrawer(context),
        // Barra de navegación inferior personalizada
        bottomNavigationBar: _buildCustomBottomNavigationBar(context),
        backgroundColor: Colors.white,
        // El cuerpo del Scaffold muestra el widget correspondiente al índice seleccionado.
        body: _widgetOptions.elementAt(_selectedIndex),
      ),
    );
  }

  /// Construye la barra de navegación inferior con un diseño personalizado.
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
              _buildNavItem(0, EvaIcons.home, 'Inicio'),
              _buildNavItem(1, Icons.phone_android, 'DP'),
              _buildNavItem(2, Icons.car_crash, 'UGV'),
              _buildNavItem(3, Icons.bluetooth, "BLE"),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye un ítem individual para la barra de navegación.
  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = screenWidth / _widgetOptions.length;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: itemWidth,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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

  /// Construye el menú lateral (`Drawer`) con las opciones de navegación.
  Drawer _buildMenuDrawer(BuildContext context) => Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Cabecera del Drawer con información del usuario.
            InkWell(
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Get.toNamed(Routes.profile);
              },
              child: Obx(() {
                final user = _authService.currentUser.value;
                final userProfile = _userProfileService.currentProfile.value;

                return UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                  ),
                  accountName: Text(
                    userProfile?.username ?? 'Usuario Tanari',
                    style: const TextStyle(
                      color: AppColors.backgroundWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  accountEmail: Text(
                    userProfile?.email ?? user?.email ?? 'correo@ejemplo.com',
                    style: TextStyle(
                      color: AppColors.backgroundWhite.withAlpha(204),
                    ),
                  ),
                  currentAccountPicture: CircleAvatar(
                    key: ValueKey(userProfile?.avatarUrl ?? 'default_avatar'),
                    backgroundColor: AppColors.primary,
                    backgroundImage: (userProfile?.avatarUrl != null &&
                            userProfile!.avatarUrl!.isNotEmpty)
                        ? NetworkImage(_userProfileService
                            .getAvatarUrl(userProfile.avatarUrl!))
                        : null,
                    child: (userProfile?.avatarUrl == null ||
                            userProfile!.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person,
                            size: 40, color: AppColors.textPrimary)
                        : null,
                  ),
                );
              }),
            ),

            // Sección de Modos de Operación
            ExpansionTile(
              leading:
                  const Icon(Icons.car_rental, color: AppColors.textPrimary),
              title: const Text('Modos de Operacion',
                  style: TextStyle(color: AppColors.textPrimary)),
              children: <Widget>[
                ListTile(
                  title: const Text('Acople',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.toNamed(Routes.modoAcople);
                  },
                ),
              ],
            ),

            // Sección de Historial
            ExpansionTile(
              leading: const Icon(Icons.history, color: AppColors.textPrimary),
              title: const Text('Historial',
                  style: TextStyle(color: AppColors.textPrimary)),
              children: <Widget>[
                ListTile(
                  title: const Text('Historial de Monitoreo',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    // **CORREGIDO:** Se utiliza la constante de ruta corregida.
                    Get.toNamed(Routes.sessionsHistorial);
                  },
                ),
                ListTile(
                  title: const Text('Rutas',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.toNamed(Routes.ugvRoute);
                  },
                ),
              ],
            ),

            // Sección de "Acerca de"
            ListTile(
              leading: const Icon(Icons.info, color: AppColors.textPrimary),
              title: const Text('Acerca de',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Get.toNamed(Routes.acercaApp);
              },
            ),
            // Sección de "Mapa Tanari"
            ListTile(
              leading: const Icon(Icons.map, color: AppColors.textPrimary),
              title: const Text('Mapa Tanari',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Get.toNamed(Routes.mapaTanari);
              },
            ),
            // Panel de Administración (visible solo para administradores)
            Obx(() {
              final currentProfile = _userProfileService.currentProfile.value;
              if (currentProfile != null && currentProfile.isAdmin) {
                return ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: AppColors.textPrimary),
                  title: const Text('Panel de Administración',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.to(() => const AdminScreen());
                  },
                );
              } else {
                return const SizedBox.shrink();
              }
            }),

            // Opción para Cerrar Sesión
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.textPrimary),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () async {
                _scaffoldKey.currentState?.closeDrawer();
                await _authService.signOut();
              },
            ),
          ],
        ),
      );
}
