// lib/src/screens/menu/profile_user.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/models/user_profile.dart'; // <--- ¡IMPORTANTE! Importa tu CLASE UserProfile

class ProfileUser extends GetView<UserProfileService> {
  // Extiende GetView para acceso más fácil al controlador
  const ProfileUser({super.key});

  @override
  Widget build(BuildContext context) {
    // Puedes obtener las instancias directamente o a través de 'controller' de GetView
    final UserProfileService userProfileService =
        Get.find<UserProfileService>();
    final AuthService authService = Get.find<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Obx(() {
        // Obtenemos la instancia del UserProfile o null
        final UserProfile? userProfile =
            userProfileService.currentUserProfile.value;

        if (userProfile == null) {
          // Si el perfil aún no se ha cargado, muestra un indicador de carga
          return const Center(child: CircularProgressIndicator());
        }

        // Accede a las propiedades directamente desde la instancia de UserProfile
        final String username = userProfile.username;
        final String email = userProfile.email;
        final String? avatarUrl = userProfile.avatarUrl;
        final String createdAt = userProfile.createdAt != null
            ? userProfile.createdAt!
                .toLocal()
                .toShortDateString() // Usa la extensión para formatear la fecha
            : 'N/A';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primary,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                        as ImageProvider // Castea explícitamente si es necesario
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                username,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.backgroundBlack,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              _buildProfileInfoTile(
                  icon: Icons.alternate_email,
                  title: 'Correo Electrónico',
                  subtitle: email),
              _buildProfileInfoTile(
                  icon: Icons.calendar_today,
                  title: 'Miembro desde',
                  subtitle: createdAt ??
                      'Cargando...'), // Muestra la fecha de creación del perfil
              // Agrega más campos de perfil si los tienes en tu UserProfile
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  // Acción para editar perfil
                  Get.snackbar(
                    'Funcionalidad',
                    'Editar perfil aún no implementado',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                  );
                },
                icon: const Icon(Icons.edit, color: AppColors.primary),
                label: const Text('Editar Perfil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.backgroundBlack,
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () async {
                  await authService.signOut();
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProfileInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

// Extensión para formatear la fecha si no la tienes ya en otro lugar
extension DateTimeExtension on DateTime {
  String toShortDateString() {
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
  }
}
