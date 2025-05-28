import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tanari_app/src/controllers/data/database_helper.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart';
import 'package:tanari_app/src/screens/login/signup_screen.dart';
import 'package:tanari_app/src/screens/login/forget_password.dart'; // ¡Asegúrate de importar ForgetPassword!
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:get/get.dart';

/// Pantalla de inicio de sesión que maneja autenticación local
/// utilizando SQLite para almacenamiento de usuarios y SharedPreferences
/// para recordar credenciales.
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
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Carga credenciales guardadas al iniciar
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

  /// Maneja el proceso de autenticación
  Future<void> _handleLogin() async {
    if (_formSignInKey.currentState!.validate()) {
      // Verificar credenciales en la base de datos
      final user = await _dbHelper.getUser(_emailController.text);

      if (user != null && user['password'] == _passwordController.text) {
        await _saveCredentials(); // Guardar preferencias

        // Mostrar feedback al usuario
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autenticación exitosa'),
            duration: Duration(seconds: 1),
          ),
        );

        // Navegar a HomeScreen después de 1 segundo
        await Future.delayed(const Duration(seconds: 1));

        // --- CAMBIO AQUÍ: Usar Get.offAll para reemplazar todas las rutas anteriores ---
        Get.offAll(() => const HomeScreen());
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas'),
            backgroundColor: Colors.red,
          ),
        );
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
              _buildRememberForgotRow(), // Aquí está el cambio
              const SizedBox(height: 25.0),
              _buildLoginButton(),
              const SizedBox(height: 25.0),
              _buildSocialLoginDivider(),
              const SizedBox(height: 25.0),
              _buildSocialIconsRow(),
              const SizedBox(height: 25.0),
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
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
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
      ),
    );
  }

  /// Estilo común para los bordes de los inputs
  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.black12),
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
          // --- CAMBIO CLAVE AQUÍ: Agregar el onTap para navegar a ForgetPassword ---
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

  /// Divisor para login con redes sociales
  Widget _buildSocialLoginDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Divider(
            thickness: 0.7,
            color: Colors.grey.withAlpha(128),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Iniciar sesión con',
            style: TextStyle(color: Colors.black45),
          ),
        ),
        Expanded(
          child: Divider(
            thickness: 0.7,
            color: Colors.grey.withAlpha(128),
          ),
        ),
      ],
    );
  }

  /// Iconos de redes sociales para login
  Widget _buildSocialIconsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Brand(Brands.facebook, size: 32),
        Brand(Brands.twitter, size: 32),
        Brand(Brands.google, size: 32),
        Brand(Brands.apple_logo, size: 32),
      ],
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
            // --- CAMBIO AQUÍ: Usar Get.to para navegar a la pantalla de registro ---
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
