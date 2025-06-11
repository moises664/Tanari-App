import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/widgets/custom_scaffold.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:get/get.dart'; // Asegúrate de que Get esté importado

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Obtener la instancia del AuthService
  final AuthService _authService = Get.find<AuthService>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Maneja la solicitud de restablecimiento de contraseña
  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      // *** CORRECCIÓN: Usar el nombre del método correcto y .trim() ***
      await _authService.sendPasswordRecoveryEmail(_emailController.text
          .trim()); // El método es sendPasswordRecoveryEmail
      // El AuthService ya muestra un snackbar de éxito o error
      // Puedes añadir navegación de vuelta al login si lo deseas aquí,
      // o dejar que el usuario permanezca en esta pantalla después del envío.
      // Get.back(); // Para regresar a la pantalla de inicio de sesión
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
                        'Restablecer Contraseña',
                        style: TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa tu correo electrónico';
                          }
                          if (!GetUtils.isEmail(value)) {
                            return 'Email inválido';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                            'Correo Electrónico', 'ejemplo@correo.com'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 30),
                      // *** CORRECCIÓN: Envuelve en Obx y accede a .value ***
                      Obx(
                        () => _authService
                                .isLoading.value // ¡Aquí está la corrección!
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleResetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.backgroundBlack,
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Enviar Enlace',
                                      style: TextStyle(fontSize: 16)),
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      _buildSignInLink(), // Enlace para volver al login
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

  // Método auxiliar para el estilo de los inputs
  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      label: Text(label),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
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

  // Enlace para volver a la pantalla de inicio de sesión
  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '¿Recordaste tu contraseña? ',
          style: TextStyle(color: Colors.black45),
        ),
        GestureDetector(
          onTap: () {
            Get.back(); // Simplemente regresa a la pantalla anterior (SignInScreen)
          },
          child: Text(
            'Inicia sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
