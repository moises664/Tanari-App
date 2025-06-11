import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/login/signup_screen.dart'; // Mantén si lo usas
import 'package:tanari_app/src/screens/login/forget_password.dart'; // Mantén si lo usas
import 'package:tanari_app/src/widgets/custom_scaffold.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:get/get.dart'; // Para Get.find y Obx

/// Pantalla de inicio de sesión que maneja autenticación con Supabase
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formSignInKey = GlobalKey<FormState>();
  bool rememberPassword = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Obtener la instancia del AuthService que ya inyectamos en main.dart
  final AuthService _authService = Get.find<AuthService>();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Carga credenciales guardadas al iniciar
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Carga las credenciales guardadas en SharedPreferences
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rememberPassword = prefs.getBool('rememberMe') ?? false;
      if (rememberPassword) {
        _emailController.text = prefs.getString('savedEmail') ?? '';
        _passwordController.text = prefs.getString('savedPassword') ?? '';
      }
    });
  }

  /// Guarda las credenciales en SharedPreferences si "Recordarme" está activado
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberPassword) {
      await prefs.setString('savedEmail', _emailController.text);
      await prefs.setString('savedPassword', _passwordController.text);
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('savedEmail');
      await prefs.remove('savedPassword');
      await prefs.setBool('rememberMe', false);
    }
  }

  /// Maneja el proceso de autenticación con Supabase
  Future<void> _handleLogin() async {
    if (_formSignInKey.currentState!.validate()) {
      // Guardar preferencias de "Recordarme"
      await _saveCredentials();

      // Llama al método signIn del AuthService
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // La navegación a HomeScreen se manejará automáticamente en AuthService
      // gracias al listener de authService.currentUser y el _onAuthChange en AuthService.
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
            child: _buildLoginForm(),
          ),
        ],
      ),
    );
  }

  /// Construye el formulario de inicio de sesión
  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.fromLTRB(25.0, 50.0, 25.0, 20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40.0),
          topRight: Radius.circular(40.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formSignInKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTitle(),
              const SizedBox(height: 40.0),
              _buildEmailField(),
              const SizedBox(height: 25.0),
              _buildPasswordField(),
              const SizedBox(height: 25.0),
              _buildRememberForgotRow(),
              const SizedBox(height: 25.0),
              // Envuelve el botón en Obx para reaccionar al estado de carga del AuthService
              Obx(() => _authService
                      .isLoading.value // <--- Accede al valor con .value
                  ? const CircularProgressIndicator() // Muestra un cargando
                  : _buildLoginButton()),
              const SizedBox(height: 25.0),
              const SizedBox(
                  height: 25.0), // Mantengo si eliminas los social logins
              _buildSignUpLink(),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el título del formulario
  Widget _buildTitle() {
    return Text(
      'Iniciar Sesión',
      style: TextStyle(
        fontSize: 30.0,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    );
  }

  /// Construye el campo de entrada para el email
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo obligatorio';
        if (!GetUtils.isEmail(value)) {
          return 'Email inválido';
        }
        return null;
      },
      decoration: InputDecoration(
        label: const Text('Correo'),
        hintText: 'Introduce tu correo electrónico',
        hintStyle: const TextStyle(color: Colors.black26),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder:
            _inputBorder(color: AppColors.primary), // Añade focusedBorder
      ),
    );
  }

  /// Construye el campo de entrada para la contraseña
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      obscuringCharacter: '*',
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo obligatorio';
        if (value.length < 6) return 'Mínimo 6 caracteres';
        return null;
      },
      decoration: InputDecoration(
        label: const Text('Contraseña'),
        hintText: 'Introduce tu contraseña',
        hintStyle: const TextStyle(color: Colors.black26),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder:
            _inputBorder(color: AppColors.primary), // Añade focusedBorder
      ),
    );
  }

  /// Estilo común para los bordes de los inputs
  OutlineInputBorder _inputBorder({Color color = Colors.black12}) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color), // Usar color en el borde
      borderRadius: BorderRadius.circular(10),
    );
  }

  /// Fila con checkbox "Recordarme" y enlace "Olvidé contraseña"
  Widget _buildRememberForgotRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: rememberPassword,
              onChanged: (bool? value) =>
                  setState(() => rememberPassword = value!),
              activeColor: AppColors.primary,
            ),
            const Text(
              '¡Recuérdame!',
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Get.to(() => const ForgetPassword());
          },
          child: Text(
            '¿Olvidaste tu contraseña?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Botón principal de inicio de sesión
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: AppColors.backgroundBlack,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Inicia Sesión',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  /// Enlace para registrar nueva cuenta
  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '¿No tienes una cuenta? ',
          style: TextStyle(color: Colors.black45),
        ),
        GestureDetector(
          onTap: () {
            Get.to(() => const SignUpScreen());
          },
          child: Text(
            'Regístrate',
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
