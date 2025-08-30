import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/services/api/auth_service.dart';
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:get/get.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AuthService _authService = Get.find<AuthService>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Maneja la solicitud de restablecimiento de contraseña
  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      await _authService
          .sendPasswordRecoveryEmail(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return CustomScaffold(
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.05), // Espacio superior responsivo
          Expanded(
            flex: 7,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.07, // Padding horizontal responsivo
                screenHeight * 0.06, // Padding superior responsivo
                screenWidth * 0.07, // Padding horizontal responsivo
                screenHeight * 0.03, // Padding inferior responsivo
              ),
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
                          fontSize:
                              screenWidth * 0.08, // Tamaño de fuente responsivo
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(
                          height: screenHeight * 0.04), // Espacio responsivo
                      Text(
                        'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:
                              screenWidth * 0.04, // Tamaño de fuente responsivo
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(
                          height: screenHeight * 0.03), // Espacio responsivo
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
                            'Correo Electrónico',
                            'ejemplo@correo.com',
                            screenWidth), // Pasa screenWidth
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(
                          height: screenHeight * 0.03), // Espacio responsivo
                      // Envuelve en Obx y accede a .value
                      Obx(
                        () => _authService.isLoading.value
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleResetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.backgroundBlack,
                                    foregroundColor: AppColors.primary,
                                    padding: EdgeInsets.symmetric(
                                        vertical: screenWidth *
                                            0.04), // Padding responsivo
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text('Enviar Enlace',
                                      style: TextStyle(
                                          fontSize: screenWidth *
                                              0.045)), // Fuente responsiva
                                ),
                              ),
                      ),
                      SizedBox(
                          height: screenHeight * 0.02), // Espacio responsivo
                      _buildSignInLink(screenWidth), // Pasa screenWidth
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
  InputDecoration _inputDecoration(
      String label, String hint, double screenWidth) {
    // Recibe screenWidth
    return InputDecoration(
      label: Text(label,
          style: TextStyle(fontSize: screenWidth * 0.038)), // Fuente responsiva
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
  Widget _buildSignInLink(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '¿Recordaste tu contraseña? ',
          style: TextStyle(
              color: Colors.black45,
              fontSize: screenWidth * 0.035), // Fuente responsiva
        ),
        GestureDetector(
          onTap: () {
            Get.back(); // Regresa a la pantalla anterior (SignInScreen)
          },
          child: Text(
            'Inicia sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: screenWidth * 0.035, // Fuente responsiva
            ),
          ),
        ),
      ],
    );
  }
}
