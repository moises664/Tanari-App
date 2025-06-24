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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = Get.find<AuthService>();
  final UserProfileService _userProfileService = Get.find<UserProfileService>();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const HomeTab(),
    const ModoMonitoreo(),
    const ModoUgv(),
    const HistorialApp(),
    const ProfileScreen()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sí'),
              ),
            ],
          ),
        );
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
        drawer: _buildMenuDrawer(context),
        bottomNavigationBar: _buildCustomBottomNavigationBar(context),
        backgroundColor: Colors.white,
        body: _widgetOptions.elementAt(_selectedIndex),
      ),
    );
  }

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
                      color: AppColors.backgroundWhite.withOpacity(0.8),
                    ),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    backgroundImage: (userProfile?.avatarUrl != null &&
                            userProfile!.avatarUrl!.isNotEmpty)
                        ? NetworkImage(userProfile.avatarUrl!) as ImageProvider
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

            // CERRAR SESIÓN
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
