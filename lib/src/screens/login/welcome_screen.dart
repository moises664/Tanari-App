import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart'; // Asegúrate de que esta importación sea correcta y apunte a tu archivo app_pages.dart
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:tanari_app/src/widgets/welcome_button.dart';
import 'package:get/get.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return CustomScaffold(
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.1),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.1,
              ),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'TANARI APP\n\n\n\n',
                        style: TextStyle(
                          fontSize: screenWidth * 0.08,
                          fontWeight: FontWeight.w600,
                          color: AppColors.backgroundWhite,
                        ),
                      ),
                      TextSpan(
                        text: 'Bienvenido de Nuevo',
                        style: TextStyle(
                          fontSize: screenWidth * 0.11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.backgroundWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.03,
            ),
            child: Row(
              children: [
                Expanded(
                  child: WelcomeButton(
                    buttonText: 'Iniciar Sesión',
                    onTap: () {
                      // *** ESTA ES LA NAVEGACIÓN CORRECTA PARA INICIAR SESIÓN ***
                      Get.toNamed(Routes.signIn);
                    },
                    color: Colors.transparent,
                    textColor: AppColors.backgroundWhite,
                    borderColor: AppColors.backgroundWhite,
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: WelcomeButton(
                    buttonText: 'Registrarse',
                    onTap: () {
                      // *** ESTA ES LA NAVEGACIÓN CORRECTA PARA REGISTRARSE ***
                      Get.toNamed(Routes.signUp);
                    },
                    color: AppColors.backgroundWhite,
                    textColor: AppColors.primary,
                    borderColor: AppColors.backgroundWhite,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
        ],
      ),
    );
  }
}
