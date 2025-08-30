import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart';
import 'package:tanari_app/src/widgets/custom_scaffold.dart';
import 'package:tanari_app/src/widgets/welcome_button.dart';
import 'package:get/get.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos las dimensiones de la pantalla para un diseño responsivo.
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return CustomScaffold(
      // Usamos un Column para organizar los elementos de la pantalla de forma vertical.
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // Estiramos los hijos horizontalmente.
        children: [
          // Espacio en la parte superior, ajustado a un porcentaje de la altura de la pantalla.
          SizedBox(height: screenHeight * 0.15),

          // El contenido principal se expande para llenar el espacio restante.
          Expanded(
            child: Padding(
              // Padding horizontal responsivo.
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment
                    .center, // Centramos el contenido en el eje vertical.
                children: [
                  // Título principal "TANARI APP"
                  Text(
                    'TANARI APP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth *
                          0.1, // El tamaño del texto es responsivo.
                      fontWeight: FontWeight.w700,
                      color: AppColors.backgroundWhite,
                    ),
                  ),

                  // Pequeño espacio entre el título y el texto secundario.
                  SizedBox(height: screenHeight * 0.02),

                  // Texto de los desarrolladores.
                  Text(
                    'Desarrolladores:\n Jose Mendez\n Moises Rivera',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w600,
                      color: AppColors.backgroundWhite,
                    ),
                  ),

                  // Gran espacio para separar la información de bienvenida de los botones.
                  SizedBox(height: screenHeight * 0.15),

                  // El mensaje de bienvenida.
                  Text(
                    '¡Bienvenido!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.09,
                      fontWeight: FontWeight.w800,
                      color: AppColors.backgroundWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Espacio para los botones de la parte inferior.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.03,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botón de Iniciar Sesión.
                Expanded(
                  child: WelcomeButton(
                    buttonText: 'Iniciar Sesión',
                    onTap: () {
                      // Navegación correcta para Iniciar Sesión.
                      Get.toNamed(Routes.signIn);
                    },
                    color: Colors.transparent,
                    textColor: AppColors.backgroundWhite,
                    borderColor: AppColors.backgroundWhite,
                  ),
                ),

                // Espacio entre los botones.
                SizedBox(width: screenWidth * 0.04),

                // Botón de Registrarse.
                Expanded(
                  child: WelcomeButton(
                    buttonText: 'Registrarse',
                    onTap: () {
                      // Navegación correcta para Registrarse.
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

          // Espacio en la parte inferior de la pantalla.
          SizedBox(height: screenHeight * 0.05),
        ],
      ),
    );
  }
}
