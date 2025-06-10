import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/login/singin_screen.dart';
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:get/get.dart'; // Asegúrate de que Get esté importado

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

  // Obtener la instancia del AuthService que ya inyectamos en main.dart
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
      try {
        await _authService.signUp(
          _emailController.text.trim(), // Limpiar espacios
          _passwordController.text.trim(), // Limpiar espacios
          _nameController.text
              .trim(), // Pasamos el nombre como username, limpiar espacios
        );
        // Si la llamada a signUp no lanza un error (lo que significa que el Supabase
        // la aceptó), entonces navegamos al usuario al SignInScreen.
        // El SnackBar de éxito ("Registro Exitoso...") ya lo maneja el AuthService.
        Get.offAll(() =>
            const SignInScreen()); // Navega a la pantalla de inicio de sesión
      } catch (e) {
        // AuthService ya muestra el snackbar de error, no necesitamos uno aquí.
        // El `rethrow` en AuthService asegura que el error se propague aquí
        // si quisieras manejarlo de forma diferente en la UI.
      }
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
    return CustomScaffold(
      child: Column(
        children: [
          const Expanded(flex: 1, child: SizedBox(height: 10)),
          Expanded(
            flex: 7,
            child: _buildSignUpForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Container(
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
          key: _formSignupKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTitle(),
              const SizedBox(height: 40.0),
              _buildNameField(),
              const SizedBox(height: 25.0),
              _buildEmailField(),
              const SizedBox(height: 25.0),
              _buildPasswordField(),
              const SizedBox(height: 25.0),
              _buildAgreementRow(),
              const SizedBox(height: 25.0),
              // *** CORRECCIÓN: Envolver en Obx para que reaccione al estado de carga ***
              Obx(() => _authService.isLoading // Acceder a .value del RxBool
                  ? const CircularProgressIndicator() // Muestra un cargando
                  : _buildSignUpButton()),
              const SizedBox(height: 30.0),
              const SizedBox(height: 25.0),
              _buildSignInLink(),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      '¡Comienza ya!',
      style: TextStyle(
        fontSize: 30.0,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Nombre de usuario obligatorio';
        }
        if (value.length < 3) return 'Mínimo 3 caracteres';
        return null;
      },
      decoration:
          _inputDecoration('Nombre de Usuario', 'Ingrese su nombre de usuario'),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Email obligatorio';
        if (!GetUtils.isEmail(value)) {
          return 'Email inválido';
        }
        return null;
      },
      decoration:
          _inputDecoration('Correo', 'Introduzca su correo electrónico'),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      obscuringCharacter: '*',
      validator: (value) {
        if (value == null || value.isEmpty) return 'Contraseña obligatoria';
        if (value.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
      decoration: _inputDecoration('Contraseña', 'Introduzca su contraseña'),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      label: Text(label),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
      border: _inputBorder(),
      enabledBorder: _inputBorder(),
    );
  }

  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.black12),
      borderRadius: BorderRadius.circular(10),
    );
  }

  Widget _buildAgreementRow() {
    return Row(
      children: [
        Checkbox(
          value: agreePersonalData,
          onChanged: (bool? value) =>
              setState(() => agreePersonalData = value!),
          activeColor: AppColors.primary,
        ),
        const Text('Acepto el procesamiento de ',
            style: TextStyle(color: Colors.black45)),
        GestureDetector(
          onTap: () {
            Get.snackbar("Términos", "Mostrando términos y condiciones...",
                snackPosition: SnackPosition.BOTTOM);
          },
          child: Text('datos personales',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
                decoration: TextDecoration
                    .underline, // Subrayado para indicar que es clickeable
              )),
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleSignUp,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: AppColors.backgroundBlack,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('Registrarse', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('¿Ya tienes una cuenta? ',
            style: TextStyle(color: Colors.black45)),
        GestureDetector(
          onTap: () {
            Get.to(() => const SignInScreen());
          },
          child: Text(
            'Iniciar sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
