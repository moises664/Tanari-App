import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/models/user_profile.dart'; // Necesario para el nombre de usuario
import 'package:tanari_app/src/screens/menu/modos_historial/session_details_screen.dart';
import 'package:tanari_app/src/services/api/admin_services.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';

/// Controlador para la pantalla de historial de sesiones de un usuario específico (vista de Admin).
class UserSessionsHistoryController extends GetxController {
  final String userId;
  final String username;
  final AdminService _adminService = Get.find<AdminService>();

  final RxList<OperationSession> sessions = <OperationSession>[].obs;
  final RxBool isLoading = true.obs;

  UserSessionsHistoryController({required this.userId, required this.username});

  @override
  void onInit() {
    super.onInit();
    fetchUserSessions();
  }

  /// Carga las sesiones de operación para el usuario especificado.
  Future<void> fetchUserSessions() async {
    isLoading.value = true;
    final fetchedSessions = await _adminService.fetchUserSessions(userId);
    sessions.assignAll(fetchedSessions);
    isLoading.value = false;
  }
}

/// Pantalla para que un administrador vea el historial de sesiones de un usuario específico.
class UserSessionsHistoryScreen extends StatelessWidget {
  final UserProfile user;

  const UserSessionsHistoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UserSessionsHistoryController(
        userId: user.id, username: user.username));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Historial de ${user.username}',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.backgroundWhite,
        elevation: 2,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.sessions.isEmpty) {
          return Center(
            child: Text(
              'Este usuario no tiene sesiones registradas.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: controller.sessions.length,
          itemBuilder: (context, index) {
            final session = controller.sessions[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  session.mode == 'coupled' ? Icons.link : Icons.route,
                  color: AppColors.primary,
                ),
                title: Text(
                  session.operationName ?? 'Sesión Sin Nombre',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Inicio: ${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Get.to(() => SessionDetailsScreen(sessionId: session.id));
                },
              ),
            );
          },
        );
      }),
    );
  }
}
