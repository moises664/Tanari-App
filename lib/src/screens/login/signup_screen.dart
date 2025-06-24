import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart'; // Importa las rutas para Get.toNamed
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:get/get.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formSignupKey = GlobalKey<FormState>();
  bool agreePersonalData = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = Get.find<AuthService>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Maneja el proceso de registro con Supabase
  Future<void> _handleSignUp() async {
    if (_formSignupKey.currentState!.validate() && agreePersonalData) {
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
    } else if (!agreePersonalData) {
      Get.snackbar(
        "Advertencia",
        "Debes aceptar el procesamiento de datos personales.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
      );
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
            child: _buildSignUpForm(screenHeight, screenWidth),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(double screenHeight, double screenWidth) {
    return Container(
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
          key: _formSignupKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTitle(screenWidth),
              SizedBox(height: screenHeight * 0.04), // Espacio responsivo
              _buildNameField(screenWidth), // Pasa screenWidth
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildEmailField(screenWidth), // Pasa screenWidth
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildPasswordField(screenWidth), // Pasa screenWidth
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildAgreementRow(screenWidth), // Pasa screenWidth
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              // Envuelve el botón en Obx para que reaccione al estado de carga
              Obx(() =>
                  _authService.isLoading.value // Acceder a .value del RxBool
                      ? const CircularProgressIndicator() // Muestra un cargando
                      : _buildSignUpButton(screenWidth)),
              SizedBox(height: screenHeight * 0.03), // Espacio responsivo
              _buildSignInLink(screenWidth), // Pasa screenWidth
              SizedBox(
                  height: screenHeight * 0.02), // Espacio inferior responsivo
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(double screenWidth) {
    return Text(
      '¡Comienza ya!',
      style: TextStyle(
        fontSize: screenWidth * 0.08, // Tamaño de fuente responsivo
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildNameField(double screenWidth) {
    // Recibe screenWidth
    return TextFormField(
      controller: _nameController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Nombre de usuario obligatorio';
        }
        if (value.length < 3) return 'Mínimo 3 caracteres';
        return null;
      },
      decoration: _inputDecoration('Nombre de Usuario',
          'Ingrese su nombre de usuario', screenWidth), // Pasa screenWidth
    );
  }

  Widget _buildEmailField(double screenWidth) {
    // Recibe screenWidth
    return TextFormField(
      controller: _emailController,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Email obligatorio';
        if (!GetUtils.isEmail(value)) {
          return 'Email inválido';
        }
        return null;
      },
      decoration: _inputDecoration('Correo', 'Introduzca su correo electrónico',
          screenWidth), // Pasa screenWidth
    );
  }

  Widget _buildPasswordField(double screenWidth) {
    // Recibe screenWidth
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      obscuringCharacter: '*',
      validator: (value) {
        if (value == null || value.isEmpty) return 'Contraseña obligatoria';
        if (value.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
      decoration: _inputDecoration('Contraseña', 'Introduzca su contraseña',
          screenWidth), // Pasa screenWidth
    );
  }

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
      focusedBorder:
          _inputBorder(color: AppColors.primary), // Añade focusedBorder
    );
  }

  OutlineInputBorder _inputBorder({Color color = Colors.black12}) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color),
      borderRadius: BorderRadius.circular(10),
    );
  }

  Widget _buildAgreementRow(double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // Alineación vertical
      children: [
        Checkbox(
          value: agreePersonalData,
          onChanged: (bool? value) =>
              setState(() => agreePersonalData = value!),
          activeColor: AppColors.primary,
        ),
        // Usar Flexible para que el texto se ajuste
        Flexible(
          child: Text('Acepto el procesamiento de ',
              style: TextStyle(
                  color: Colors.black45,
                  fontSize:
                      screenWidth * 0.035)), // Tamaño de fuente responsivo
        ),
        // CORRECCIÓN CLAVE AQUÍ: El GestureDetector ahora envuelve el texto,
        // y ambos están dentro de un Flexible, que es un hijo directo del Row.
        Flexible(
          child: GestureDetector(
            onTap: () {
              Get.snackbar("Términos", "Mostrando términos y condiciones...",
                  snackPosition: SnackPosition.BOTTOM);
            },
            child: Text('datos personales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                  fontSize: screenWidth * 0.035, // Tamaño de fuente responsivo
                  decoration: TextDecoration.underline,
                )),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(double screenWidth) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleSignUp,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.04), // Padding vertical responsivo
          backgroundColor: AppColors.backgroundBlack,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text('Registrarse',
            style: TextStyle(
                fontSize: screenWidth * 0.045)), // Tamaño de fuente responsivo
      ),
    );
  }

  Widget _buildSignInLink(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('¿Ya tienes una cuenta? ',
            style: TextStyle(
                color: Colors.black45,
                fontSize: screenWidth * 0.035)), // Tamaño de fuente responsivo
        GestureDetector(
          onTap: () {
            Get.toNamed(Routes.signIn); // Usa Get.toNamed
          },
          child: Text(
            'Iniciar sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: screenWidth * 0.035, // Tamaño de fuente responsivo
            ),
          ),
        ),
      ],
    );
  }
}
