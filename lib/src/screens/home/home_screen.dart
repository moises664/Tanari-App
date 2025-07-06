//HOME SCREEN
//PANTALLA PRINCIPAL

import 'dart:io'; // Para usar exit(0) al cerrar la aplicación
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/home/home_tab.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/screens/menu/historial_app.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_monitoreo.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_ugv.dart';
import 'package:tanari_app/src/screens/menu/profile_screen.dart';
import 'package:tanari_app/src/screens/menu/roles/admin_screen.dart'; // Importar pantalla de admin

/// Pantalla principal de la aplicación que actúa como contenedor de las diferentes secciones.
///
/// Utiliza un [Scaffold] con un [Drawer] para el menú lateral y una barra de navegación inferior personalizada.
/// También maneja la lógica de cierre de sesión y la confirmación al salir de la aplicación.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = Get.find<AuthService>();
  final UserProfileService _userProfileService = Get.find<UserProfileService>();

  // Clave para el Scaffold, permite controlar el drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Índice actual de la pantalla en la barra de navegación inferior
  int _selectedIndex = 0;

  // Lista de widgets que representan las diferentes pantallas de la aplicación
  final List<Widget> _widgetOptions = <Widget>[
    const HomeTab(),
    const ModoMonitoreo(),
    const ModoUgv(),
    const HistorialApp(),
    const ProfileScreen()
  ];

  /// Maneja el cambio de índice en la barra de navegación inferior
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Evita que el usuario salga de la pantalla sin confirmación
      canPop: false,
      // Callback que se invoca cuando el usuario intenta salir (ej. botón de retroceso)
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
                  // Cerrar sesión y luego salir de la aplicación
                  Navigator.of(context).pop(true);
                  Get.find<AuthService>().signOut();
                },
                child: const Text('Sí'),
              ),
            ],
          ),
        );

        // Si el usuario confirma, cerrar completamente la aplicación
        if (shouldExit == true) {
          exit(0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
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
        // Menú lateral (Drawer)
        drawer: _buildMenuDrawer(context),
        // Barra de navegación inferior personalizada
        bottomNavigationBar: _buildCustomBottomNavigationBar(context),
        backgroundColor: Colors.white,
        // Cuerpo: muestra la pantalla correspondiente al índice seleccionado
        body: _widgetOptions.elementAt(_selectedIndex),
      ),
    );
  }

  /// Construye la barra de navegación inferior personalizada
  ///
  /// Retorna un [SafeArea] que contiene un contenedor con diseño personalizado
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
              _buildNavItem(4, Icons.person, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye un elemento de la barra de navegación inferior
  ///
  /// [index]: Índice del elemento
  /// [icon]: Icono a mostrar
  /// [label]: Texto descriptivo
  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / _widgetOptions.length -
            (24 * 2 / _widgetOptions.length) -
            (10 * 2 / _widgetOptions.length),
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
  ///
  /// Contiene:
  /// - Cabecera con información del usuario
  /// - Sección de modos de operación
  /// - Historial
  /// - Comunicación BLE
  /// - Acerca de
  /// - Opción para cerrar sesión
  /// - Panel de administración (solo visible para usuarios administradores)
  Drawer _buildMenuDrawer(BuildContext context) => Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // CABECERA CON INFORMACIÓN DEL USUARIO
            InkWell(
              onTap: () {
                setState(() => _selectedIndex = 4);
                _scaffoldKey.currentState?.closeDrawer();
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
                    backgroundColor: AppColors.primary,
                    backgroundImage: (userProfile?.avatarUrl != null &&
                            userProfile!.avatarUrl!.isNotEmpty)
                        ? NetworkImage(_userProfileService.getAvatarUrl(
                            userProfile.avatarUrl)) as ImageProvider
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

            // MODOS DE OPERACIÓN
            ExpansionTile(
              leading:
                  const Icon(Icons.car_rental, color: AppColors.textPrimary),
              title: const Text('Modos de Operacion',
                  style: TextStyle(color: AppColors.textPrimary)),
              children: <Widget>[
                ListTile(
                  title: const Text('Tanari DP',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.toNamed(Routes.modoMonitoreo);
                  },
                ),
                ListTile(
                  title: const Text('Tanari UGV',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    Get.toNamed(Routes.modoUgv);
                  },
                ),
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

            // HISTORIAL
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
                    Get.toNamed(Routes.historialApp);
                  },
                ),
                ListTile(
                  title: const Text('Rutas',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
                ListTile(
                  title: const Text('Ubicación',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
              ],
            ),

            // COMUNICACIÓN BLE
            ListTile(
              leading:
                  const Icon(Icons.bluetooth, color: AppColors.textPrimary),
              title: const Text('Comunicacion BLE',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Get.toNamed(Routes.comunicacionBle);
              },
            ),

            // ACERCA DE
            ListTile(
              leading: const Icon(Icons.info, color: AppColors.textPrimary),
              title: const Text('Acerca de',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                Get.toNamed(Routes.acercaApp);
              },
            ),

            // PANEL DE ADMINISTRACIÓN (solo visible para administradores)
            // Usamos Obx para reaccionar a cambios en el estado del perfil
            Obx(() {
              final currentProfile = _userProfileService.currentProfile.value;
              // Verificamos si el usuario actual es administrador
              if (currentProfile != null && currentProfile.isAdmin) {
                return ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: AppColors.textPrimary),
                  title: const Text('Panel de Administración',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    // Navegamos a la pantalla de administración
                    Get.to(() => const AdminScreen());
                  },
                );
              } else {
                // Si no es administrador, no mostramos nada
                return const SizedBox.shrink();
              }
            }),

            // CERRAR SESIÓN
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.textPrimary),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () async {
                _scaffoldKey.currentState?.closeDrawer();
                // Cierra sesión usando el servicio de autenticación
                await _authService.signOut();
              },
            ),
          ],
        ),
      );
}
