import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Asume que tienes este archivo

/// Widget de la pantalla de inicio con un diseño minimalista.
///
/// Se ha simplificado el diseño para enfocarse en un aspecto más limpio
/// y directo, utilizando la tipografía y colores de la aplicación.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      // Color de fondo simple en lugar de un degradado.
      color: AppColors.backgroundPrimary,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Texto principal con el nombre de la app.
            Text(
              'TANARI',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            // Un texto secundario más sutil.
            Text(
              'Gestión y control remoto de Tanari DP y UGV. Acceso seguro a tus datos en la nube.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
