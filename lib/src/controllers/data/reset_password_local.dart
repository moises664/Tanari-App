import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/controllers/data/database_helper.dart'; // Importa tu DatabaseHelper
import 'package:tanari_app/src/screens/login/singin_screen.dart'; // Importa tu SignInScreen para la navegación

class ResetPasswordLocalDB extends StatefulWidget {
  const ResetPasswordLocalDB({super.key});

  @override
  State<ResetPasswordLocalDB> createState() => _ResetPasswordLocalDBState();
}

class _ResetPasswordLocalDBState extends State<ResetPasswordLocalDB> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final DatabaseHelper _dbHelper =
      DatabaseHelper.instance; // Instancia de tu DatabaseHelper

  // Estilo común para los bordes de los inputs
  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.black12),
      borderRadius: BorderRadius.circular(10),
    );
  }

  /// Maneja el proceso de actualización de la contraseña en la DB local
  Future<void> _updatePassword() async {
    if (_formKey.currentState!.validate()) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        Get.snackbar(
          'Error',
          'Las contraseñas no coinciden',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // 1. Verificar si el usuario existe (solo para fines de recuperación)
      // Aunque en una app real no deberías confirmar la existencia del email si no vas a enviar un email,
      // aquí lo hacemos para la demo de la funcionalidad local.
      final user = await _dbHelper.getUser(_emailController.text);

      if (user == null) {
        Get.snackbar(
          'Error',
          'El usuario con este correo no existe.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // 2. Actualizar la contraseña en la base de datos
      final int rowsAffected = await _dbHelper.updatePassword(
        // <--- AQUÍ EL CAMBIO: llamando a updatePassword
        _emailController.text,
        _newPasswordController.text,
      );

      if (rowsAffected > 0) {
        Get.snackbar(
          'Éxito',
          'Contraseña actualizada correctamente.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        // Navegar de regreso a la pantalla de inicio de sesión después de un breve retraso
        await Future.delayed(const Duration(seconds: 2));
        Get.offAll(() =>
            const SignInScreen()); // Navega y elimina todas las rutas anteriores
      } else {
        Get.snackbar(
          'Error',
          'No se pudo actualizar la contraseña. Inténtalo de nuevo.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar Contraseña Local'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Introduce tu correo y la nueva contraseña para actualizarla en la base de datos local.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.backgroundBlack,
                  ),
                ),
                const SizedBox(height: 30),

                // Campo de correo electrónico
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obligatorio';
                    }
                    if (!GetUtils.isEmail(value)) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    label: const Text('Correo Electrónico'),
                    hintText: 'ejemplo@correo.com',
                    hintStyle: const TextStyle(color: Colors.black26),
                    border: _inputBorder(),
                    enabledBorder: _inputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo de nueva contraseña
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  obscuringCharacter: '*',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obligatorio';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    label: const Text('Nueva Contraseña'),
                    hintText: 'Mínimo 6 caracteres',
                    hintStyle: const TextStyle(color: Colors.black26),
                    border: _inputBorder(),
                    enabledBorder: _inputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo de confirmar nueva contraseña
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  obscuringCharacter: '*',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obligatorio';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    label: const Text('Confirmar Contraseña'),
                    hintText: 'Repite la nueva contraseña',
                    hintStyle: const TextStyle(color: Colors.black26),
                    border: _inputBorder(),
                    enabledBorder: _inputBorder(),
                  ),
                ),
                const SizedBox(height: 30),

                // Botón para actualizar contraseña
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Cambiar Contraseña',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Botón para volver
                TextButton(
                  onPressed: () {
                    Get.back(); // Regresar a la pantalla anterior (ForgetPassword)
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.backgroundBlack,
                  ),
                  child: const Text('Volver', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
