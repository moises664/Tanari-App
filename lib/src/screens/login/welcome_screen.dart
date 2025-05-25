import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/login/signup_screen.dart';
import 'package:tanari_app/src/screens/login/singin_screen.dart';
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:tanari_app/src/widgets/welcome_button.dart';
import 'package:get/get.dart'; // ¡Asegúrate de que esta importación esté presente!

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Column(
        children: [
          Flexible(
              flex: 8,
              child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 40,
                  ),
                  child: Center(
                    child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: ' TANARI APP\n\n\n\n',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            TextSpan(
                                text: 'Bienvenido de Nuevo',
                                style: TextStyle(
                                    fontSize: 45,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        )),
                  ))),
          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                children: [
                  Expanded(
                      child: WelcomeButton(
                    buttonText: 'Iniciar Sesión',
                    // Ahora esto es válido porque WelcomeButton espera una función
                    onTap: () {
                      Get.to(() => const SignInScreen());
                    },
                    color: Colors.transparent,
                    textColor: AppColors.backgroundWhite,
                  )),
                  Expanded(
                      child: WelcomeButton(
                    buttonText: 'Registrarse',
                    // Y esto también es válido
                    onTap: () {
                      Get.to(() => const SignUpScreen());
                    },
                    color: AppColors.backgroundWhite,
                    textColor: AppColors.primary,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
