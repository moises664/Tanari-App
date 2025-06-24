import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart'; // Importa las rutas para Get.toNamed
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:get/get.dart';

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
            child: _buildLoginForm(screenHeight, screenWidth),
          ),
        ],
      ),
    );
  }

  /// Construye el formulario de inicio de sesión
  Widget _buildLoginForm(double screenHeight, double screenWidth) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.07, // Padding horizontal responsivo
        screenHeight * 0.06, // Padding superior responsivo
        screenWidth * 0.07, // Padding horizontal responsivo
        screenHeight * 0.03, // Padding inferior responsivo
      ),
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
              _buildTitle(screenWidth),
              SizedBox(height: screenHeight * 0.04), // Espacio responsivo
              _buildEmailField(screenWidth), // Pasa screenWidth
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildPasswordField(screenWidth), // Pasa screenWidth
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildRememberForgotRow(screenWidth),
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              // Envuelve el botón en Obx para reaccionar al estado de carga del AuthService
              Obx(() => _authService
                      .isLoading.value // <--- Accede al valor con .value
                  ? const CircularProgressIndicator() // Muestra un cargando
                  : _buildLoginButton(screenWidth)),
              SizedBox(height: screenHeight * 0.025), // Espacio responsivo
              _buildSignUpLink(screenWidth),
              SizedBox(
                  height: screenHeight * 0.02), // Espacio inferior responsivo
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el título del formulario
  Widget _buildTitle(double screenWidth) {
    return Text(
      'Iniciar Sesión',
      style: TextStyle(
        fontSize: screenWidth * 0.08, // Tamaño de fuente responsivo
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
    );
  }

  /// Construye el campo de entrada para el email
  Widget _buildEmailField(double screenWidth) {
    // Recibe screenWidth
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
        label: Text('Correo',
            style:
                TextStyle(fontSize: screenWidth * 0.038)), // Fuente responsiva
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
  Widget _buildPasswordField(double screenWidth) {
    // Recibe screenWidth
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
        label: Text('Contraseña',
            style:
                TextStyle(fontSize: screenWidth * 0.038)), // Fuente responsiva
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
  Widget _buildRememberForgotRow(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize:
              MainAxisSize.min, // Para que el Row ocupe lo mínimo necesario
          children: [
            Checkbox(
              value: rememberPassword,
              onChanged: (bool? value) =>
                  setState(() => rememberPassword = value!),
              activeColor: AppColors.primary,
            ),
            Flexible(
              // Usar Flexible para que el texto se ajuste
              child: Text(
                '¡Recuérdame!',
                style: TextStyle(
                    color: Colors.black45,
                    fontSize:
                        screenWidth * 0.035), // Tamaño de fuente responsivo
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Get.toNamed(Routes.forgetPassword); // Usa Get.toNamed
          },
          child: Text(
            '¿Olvidaste tu contraseña?',
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

  /// Botón principal de inicio de sesión
  Widget _buildLoginButton(double screenWidth) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.04), // Padding vertical responsivo
          backgroundColor: AppColors.backgroundBlack,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          'Inicia Sesión',
          style: TextStyle(
              fontSize: screenWidth * 0.045), // Tamaño de fuente responsivo
        ),
      ),
    );
  }

  /// Enlace para registrar nueva cuenta
  Widget _buildSignUpLink(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '¿No tienes una cuenta? ',
          style: TextStyle(
              color: Colors.black45,
              fontSize: screenWidth * 0.035), // Tamaño de fuente responsivo
        ),
        GestureDetector(
          onTap: () {
            Get.toNamed(Routes.signUp); // Usa Get.toNamed
          },
          child: Text(
            'Regístrate',
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
