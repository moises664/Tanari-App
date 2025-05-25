import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/data/reset_password_local.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Asegúrate de importar tus colores

class ForgetPassword extends StatelessWidget {
  const ForgetPassword({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: AppColors.backgroundPrimary, // Usando tu color
        foregroundColor: AppColors.textPrimary, // Usando tu color
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Selecciona una opción para recuperar tu contraseña:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.backgroundBlack,
                ),
              ),
              const SizedBox(height: 40),

              // Opción 1: Recuperar con Correo
              _buildOptionButton(
                context: context,
                text: 'Recuperar con Correo Electrónico',
                icon: Icons.email,
                onTap: () {
                  // Muestra un mensaje temporal ya que el backend no está conectado
                  Get.snackbar(
                    'Función no disponible',
                    'La recuperación por correo no está activa aún. Por favor, contacta a soporte.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.orange,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 3),
                  );
                  // O un diálogo más formal
                  // Get.defaultDialog(
                  //   title: 'En Construcción',
                  //   middleText: 'La funcionalidad de recuperación por correo estará disponible pronto.',
                  //   textConfirm: 'Entendido',
                  //   confirmTextColor: Colors.white,
                  //   onConfirm: () => Get.back(),
                  // );
                },
                color: AppColors.primary, // Usando tu color primario
              ),

              const SizedBox(height: 20),

              // Opción 2: Acceder a la Base de Datos Local
              _buildOptionButton(
                context: context,
                text: 'Cambiar en Base de Datos Local',
                icon: Icons.data_usage,
                onTap: () {
                  Get.to(() => const ResetPasswordLocalDB());
                },
                color:
                    AppColors.backgroundBlack, // Usando tu color de fondo negro
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método auxiliar para construir los botones de opción
  Widget _buildOptionButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        icon: Icon(icon, size: 28),
        label: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
