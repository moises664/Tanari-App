// admin_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/models/user_profile.dart';
import 'package:tanari_app/src/services/api/admin_services.dart';
import 'package:tanari_app/src/services/api/user_profile_service.dart';
import 'user_sessions_history_screen.dart';

/// Pantalla de administración con pestañas para:
/// 1. Gestión de usuarios
/// 2. Gestión de dispositivos
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = Get.find<AdminService>();
  final UserProfileService _userProfileService = Get.find<UserProfileService>();
  final RxBool _isAdmin = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this); // Ahora solo 2 pestañas
    _checkAdminStatus();
    _loadInitialData();
  }

  void _checkAdminStatus() {
    final currentUser = _userProfileService.currentProfile.value;
    _isAdmin.value = currentUser?.isAdmin ?? false;
  }

  void _loadInitialData() {
    if (_isAdmin.value) {
      _adminService.fetchAllUsers();
      _adminService.fetchRegisteredDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!_isAdmin.value) {
        return _buildAccessDeniedScreen();
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administración'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.people), text: 'Usuarios'),
              Tab(icon: Icon(Icons.devices), text: 'Dispositivos'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUserManagementTab(),
            _buildDeviceManagementTab(),
          ],
        ),
      );
    });
  }

  /// Pantalla de acceso denegado
  Widget _buildAccessDeniedScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso denegado')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 64, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'No tienes permisos de administrador',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// Pestaña de gestión de usuarios
  Widget _buildUserManagementTab() {
    return Obx(() {
      if (_adminService.isLoadingUsers.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          _buildAddUserButton(),
          Expanded(
            child: ListView.builder(
              itemCount: _adminService.allUsers.length,
              itemBuilder: (context, index) {
                final user = _adminService.allUsers[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      );
    });
  }

  /// Botón para añadir nuevo usuario
  Widget _buildAddUserButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        onPressed: () => _showAddUserDialog(context),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Añadir Nuevo Usuario',
            style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Tarjeta de usuario
  Widget _buildUserCard(UserProfile user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              user.isAdmin ? AppColors.primary : AppColors.secondary,
          child: Icon(
            user.isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(user.username,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                user.isAdmin ? Icons.star : Icons.star_border,
                color: user.isAdmin ? Colors.amber : Colors.grey,
              ),
              onPressed: () =>
                  _adminService.toggleUserAdminStatus(user.id, user.isAdmin),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteUserDialog(user),
            ),
          ],
        ),
        onTap: () {
          Get.to(() => UserSessionsHistoryScreen(user: user));
        },
      ),
    );
  }

  /// Diálogo para añadir usuario
  void _showAddUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;

    Get.dialog(
      AlertDialog(
        title: const Text('Añadir Nuevo Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            CheckboxListTile(
              title: const Text('Es administrador'),
              value: isAdmin,
              onChanged: (value) => isAdmin = value ?? false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                Get.snackbar('Error', 'Todos los campos son requeridos');
                return;
              }
              _adminService.addNewUser(
                username: nameController.text,
                email: emailController.text,
                password: passwordController.text,
                isAdmin: isAdmin,
              );
              Get.back();
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  /// Diálogo para eliminar usuario
  void _showDeleteUserDialog(UserProfile user) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Eliminar a ${user.username}? Esta acción es irreversible'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _adminService.deleteUser(user.id);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Detalles de usuario
  void _showUserDetails(UserProfile user) {
    Get.dialog(
      AlertDialog(
        title: Text('Detalles de ${user.username}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${user.id}'),
              Text('Email: ${user.email}'),
              Text('Rol: ${user.isAdmin ? 'Administrador' : 'Usuario'}'),
              Text('Creado: ${user.createdAt.toLocal()}'),
              if (user.updatedAt != null)
                Text('Actualizado: ${user.updatedAt!.toLocal()}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Pestaña de gestión de dispositivos
  Widget _buildDeviceManagementTab() {
    return Obx(() {
      if (_adminService.isLoadingDevices.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          _buildAddDeviceButton(),
          Expanded(
            child: ListView.builder(
              itemCount: _adminService.registeredDevices.length,
              itemBuilder: (context, index) {
                final device = _adminService.registeredDevices[index];
                return _buildDeviceCard(device);
              },
            ),
          ),
        ],
      );
    });
  }

  /// Botón para añadir dispositivo
  Widget _buildAddDeviceButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        onPressed: () => _showAddDeviceDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Añadir Dispositivo',
            style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Tarjeta de dispositivo
  Widget _buildDeviceCard(Map<String, dynamic> device) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.bluetooth, color: AppColors.primary),
        title: Text(device['name'],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('UUID: ${device['uuid']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.info),
              onPressed: () => _showEditDeviceDialog(device),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDeviceDialog(device),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo para añadir dispositivo
  void _showAddDeviceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final uuidController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Añadir Dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: uuidController,
              decoration: const InputDecoration(labelText: 'UUID'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty || uuidController.text.isEmpty) {
                Get.snackbar('Error', 'Todos los campos son requeridos');
                return;
              }
              _adminService.addDevice(
                name: nameController.text,
                uuid: uuidController.text,
              );
              Get.back();
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  /// Diálogo para editar dispositivo
  void _showEditDeviceDialog(Map<String, dynamic> device) {
    final nameController = TextEditingController(text: device['name']);
    final uuidController = TextEditingController(text: device['uuid']);

    Get.dialog(
      AlertDialog(
        title: const Text('Editar Dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: uuidController,
              decoration: const InputDecoration(labelText: 'UUID'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty || uuidController.text.isEmpty) {
                Get.snackbar('Error', 'Todos los campos son requeridos');
                return;
              }
              _adminService.updateDevice(
                device['id'],
                name: nameController.text,
                uuid: uuidController.text,
              );
              Get.back();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo para eliminar dispositivo
  void _showDeleteDeviceDialog(Map<String, dynamic> device) {
    Get.dialog(
      AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar dispositivo ${device['name']}?'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _adminService.deleteDevice(device['id']);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Pestaña de visualización de base de datos
  Widget _buildDatabaseViewTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Visualización de Base de Datos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seleccione una tabla para visualizar su contenido:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildTableButton('Usuarios', 'profiles'),
                _buildTableButton('Dispositivos', 'devices'),
                _buildTableButton('Operaciones', 'operations'),
                _buildTableButton('Registros', 'audit_log'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Botón para visualizar tabla
  Widget _buildTableButton(String title, String tableName) {
    return ElevatedButton(
      onPressed: () => _showTableContent(tableName),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Text(title),
    );
  }

  /// Muestra contenido de tabla
  void _showTableContent(String tableName) {
    Get.dialog(
      AlertDialog(
        title: Text('Contenido de $tableName'),
        content: FutureBuilder(
          future: _adminService.supabaseClient.from(tableName).select(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
              return const Text('No se encontraron datos');
            }

            final data = snapshot.data as List;
            return SizedBox(
              width: double.maxFinite,
              child: DataTable(
                columns: _buildColumns(data.first.keys.toList()),
                rows: _buildRows(data),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Construye columnas para DataTable
  List<DataColumn> _buildColumns(List<String> keys) {
    return keys.map((key) {
      return DataColumn(label: Text(key));
    }).toList();
  }

  /// Construye filas para DataTable
  List<DataRow> _buildRows(List<dynamic> data) {
    return data.map((item) {
      return DataRow(
        cells: item.keys.map<DataCell>((key) {
          return DataCell(Text(item[key].toString()));
        }).toList(),
      );
    }).toList();
  }
}
