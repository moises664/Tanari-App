import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:tanari_app/src/controllers/data/database_helper.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/login/singin_screen.dart';
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:get/get.dart'; // ¡Importa GetX aquí también!

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
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> _handleSignUp() async {
    if (!_formSignupKey.currentState!.validate() || !agreePersonalData) return;

    // Ya no necesitas 'currentContext' si usas Get.to o Get.offAll
    try {
      final existingUser = await _dbHelper.getUser(_emailController.text);

      if (existingUser == null) {
        await _dbHelper.insertUser(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          // Puedes seguir usando context para ScaffoldMessenger
          const SnackBar(
            content: Text('Registro exitoso! Redirigiendo...'),
            duration: Duration(seconds: 1),
          ),
        );

        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;
        // --- CAMBIO AQUÍ: Usar Get.offAll para reemplazar todas las rutas anteriores ---
        Get.offAll(() => const SignInScreen());
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El email ya está registrado'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en el registro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
              _buildSignUpButton(),
              const SizedBox(height: 30.0),
              _buildSocialLoginDivider(),
              const SizedBox(height: 30.0),
              _buildSocialIconsRow(),
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
        if (value == null || value.isEmpty) return 'Nombre obligatorio';
        if (value.length < 3) return 'Mínimo 3 caracteres';
        return null;
      },
      decoration:
          _inputDecoration('Nombre completo', 'Ingrese su nombre completo'),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Email obligatorio';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
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
        const Text('Acepto el procesamiento ',
            style: TextStyle(color: Colors.black45)),
        Text('datos personales',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            )),
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
          child: Text('Iniciar sesión con',
              style: TextStyle(color: Colors.black45)),
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

  Widget _buildSocialIconsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Brand(Brands.facebook, size: 32),
        Brand(Brands.twitter, size: 32),
        Brand(Brands.google, size: 32),
        Brand(Brands.apple_logo, size: 32)
      ],
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
            // --- CAMBIO AQUÍ: Usar Get.to para navegar a la pantalla de inicio de sesión ---
            // Get.to te permite ir a una nueva pantalla.
            // Si quieres reemplazar la pantalla actual (sin poder regresar), usa Get.off(() => const SignInScreen());
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
