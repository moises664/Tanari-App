import 'package:flutter/material.dart';

class WelcomeButton extends StatelessWidget {
  final String? buttonText;
  final VoidCallback? onTap;
  final Color? color;
  final Color? textColor;
  final Color? borderColor; // ¡Asegúrate de que este parámetro exista!

  const WelcomeButton({
    super.key,
    this.buttonText,
    required this.onTap,
    this.color,
    this.textColor,
    this.borderColor, // Se recibe aquí
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor ??
                Colors
                    .transparent, // Usa el color del borde si está definido, sino transparente
            width: 2,
          ),
        ),
        child: Text(
          buttonText!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
