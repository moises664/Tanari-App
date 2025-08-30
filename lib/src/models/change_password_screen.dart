import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:tanari_app/src/services/api/auth_service.dart';
import 'package:tanari_app/src/widgets/custom_scaffold.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AuthService _authService = Get.find<AuthService>();
  late final bool fromRecovery;

  @override
  void initState() {
    super.initState();
    fromRecovery = Get.arguments?['fromRecovery'] ?? false;
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (_formKey.currentState!.validate()) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        Get.snackbar(
          'Error',
          'Las contraseñas no coinciden.',
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite,
        );
        return;
      }

      final success =
          await _authService.updatePassword(_newPasswordController.text);

      if (success && !_authService.isLoading.value) {
        // Muestra mensaje de éxito
        Get.snackbar(
          'Éxito',
          'Contraseña actualizada correctamente',
          backgroundColor: AppColors.success,
          colorText: AppColors.backgroundWhite,
          duration: const Duration(seconds: 2),
        );

        // Espera un momento para que el usuario vea el mensaje
        await Future.delayed(const Duration(seconds: 2));

        // Navegación contextual post-actualización
        if (fromRecovery) {
          Get.offAllNamed(Routes.home);
        } else {
          // Navega de regreso al perfil con un refresco
          Get.offNamedUntil(
            Routes.profile,
            (route) => route.settings.name == Routes.profile,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Column(
        children: [
          const Expanded(flex: 1, child: SizedBox(height: 10)),
          Expanded(
            flex: 7,
            child: Container(
              padding: const EdgeInsets.fromLTRB(25.0, 50.0, 25.0, 20.0),
              decoration: const BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Cambiar Contraseña',
                        style: TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        fromRecovery
                            ? 'Establece una nueva contraseña para tu cuenta'
                            : 'Ingresa tu nueva contraseña para actualizarla',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa tu nueva contraseña';
                          }
                          if (value.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          'Nueva Contraseña',
                          'Mínimo 6 caracteres',
                          Icons.lock_outline,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, confirma tu nueva contraseña';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          'Confirmar Contraseña',
                          'Repite tu nueva contraseña',
                          Icons.lock_reset,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Obx(
                        () => _authService.isLoading.value
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleChangePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.backgroundWhite,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Cambiar Contraseña',
                                      style: TextStyle(fontSize: 16)),
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      _buildCancelLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      label: Text(label),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: _inputBorder(),
      enabledBorder: _inputBorder(),
      focusedBorder: _inputBorder(color: AppColors.primary),
    );
  }

  OutlineInputBorder _inputBorder({Color color = Colors.black12}) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color),
      borderRadius: BorderRadius.circular(10),
    );
  }

  Widget _buildCancelLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (fromRecovery) {
              Get.offAllNamed(Routes.signIn);
            } else {
              Get.back();
            }
          },
          child: Text(
            'Cancelar',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
