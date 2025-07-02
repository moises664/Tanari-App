// REGISTRO

import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart'; // Importa las rutas para Get.toNamed
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:get/get.dart';

/// Pantalla de registro de nuevos usuarios. Permite al usuario ingresar
/// su nombre de usuario, correo electrónico y contraseña para crear una cuenta.
///
/// Utiliza [AuthService] para manejar la lógica de registro con Supabase.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formSignupKey = GlobalKey<FormState>();
  bool agreePersonalData = true; // Estado del checkbox de aceptación de datos
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Obtener la instancia del AuthService que ya inyectamos en main.dart
  final AuthService _authService = Get.find<AuthService>();

  @override
  void dispose() {
    // Liberar los controladores para evitar fugas de memoria
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Maneja el proceso de registro con Supabase.
  ///
  /// Valida el formulario y llama al método `signUp` de [AuthService].
  /// La creación del perfil en la base de datos se maneja en el servidor
  /// de Supabase a través de un trigger.
  Future<void> _handleSignUp() async {
    if (_formSignupKey.currentState!.validate() && agreePersonalData) {
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
    } else if (!agreePersonalData) {
      // Mostrar advertencia si el usuario no acepta los términos
      Get.snackbar(
        "Advertencia",
        "Debes aceptar el procesamiento de datos personales para registrarte.",
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

  /// Construye el formulario de registro.
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
              _buildNameField(screenWidth), // Campo para el nombre de usuario
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildEmailField(screenWidth), // Campo para el correo electrónico
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildPasswordField(screenWidth), // Campo para la contraseña
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildAgreementRow(
                  screenWidth), // Checkbox de aceptación de datos
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              // Envuelve el botón en Obx para que reaccione al estado de carga de AuthService
              Obx(() =>
                  _authService.isLoading.value // Acceder a .value del RxBool
                      ? const CircularProgressIndicator(
                          color: AppColors.primary) // Muestra un cargando
                      : _buildSignUpButton(screenWidth)),
              SizedBox(height: screenHeight * 0.03), // Espacio responsivo
              _buildSignInLink(screenWidth), // Enlace para iniciar sesión
              SizedBox(
                  height: screenHeight * 0.02), // Espacio inferior responsivo
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el widget del título de la pantalla.
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

  /// Construye el campo de texto para el nombre de usuario.
  Widget _buildNameField(double screenWidth) {
    return TextFormField(
      controller: _nameController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'El nombre de usuario es obligatorio.';
        }
        if (value.length < 3) {
          return 'El nombre de usuario debe tener al menos 3 caracteres.';
        }
        return null;
      },
      decoration: _inputDecoration(
          'Nombre de Usuario', 'Ingrese su nombre de usuario', screenWidth),
    );
  }

  /// Construye el campo de texto para el correo electrónico.
  Widget _buildEmailField(double screenWidth) {
    return TextFormField(
      controller: _emailController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'El correo electrónico es obligatorio.';
        }
        if (!GetUtils.isEmail(value)) {
          return 'Por favor, introduce un correo electrónico válido.';
        }
        return null;
      },
      decoration: _inputDecoration(
          'Correo', 'Introduzca su correo electrónico', screenWidth),
      keyboardType: TextInputType.emailAddress,
    );
  }

  /// Construye el campo de texto para la contraseña.
  Widget _buildPasswordField(double screenWidth) {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      obscuringCharacter: '*',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'La contraseña es obligatoria.';
        }
        if (value.length < 6) {
          return 'La contraseña debe tener al menos 6 caracteres.';
        }
        return null;
      },
      decoration: _inputDecoration(
          'Contraseña', 'Introduzca su contraseña', screenWidth),
    );
  }

  /// Define el estilo común para los campos de entrada de texto.
  InputDecoration _inputDecoration(
      String label, String hint, double screenWidth) {
    return InputDecoration(
      label: Text(label,
          style: TextStyle(fontSize: screenWidth * 0.038)), // Fuente responsiva
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
      border: _inputBorder(),
      enabledBorder: _inputBorder(),
      focusedBorder:
          _inputBorder(color: AppColors.primary), // Borde cuando está enfocado
    );
  }

  /// Define el estilo del borde para los campos de entrada de texto.
  OutlineInputBorder _inputBorder({Color color = Colors.black12}) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color),
      borderRadius: BorderRadius.circular(10),
    );
  }

  /// Construye la fila con el checkbox para la aceptación de datos personales.
  Widget _buildAgreementRow(double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: agreePersonalData,
          onChanged: (bool? value) =>
              setState(() => agreePersonalData = value!),
          activeColor: AppColors.primary,
        ),
        Flexible(
          child: Text('Acepto el procesamiento de ',
              style: TextStyle(
                  color: Colors.black45,
                  fontSize:
                      screenWidth * 0.035)), // Tamaño de fuente responsivo
        ),
        Flexible(
          child: GestureDetector(
            onTap: () {
              // Simula la apertura de términos y condiciones
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

  /// Construye el botón principal de registro.
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

  /// Construye el enlace para navegar a la pantalla de inicio de sesión.
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
            Get.toNamed(
                Routes.signIn); // Navegar a la pantalla de inicio de sesión
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
