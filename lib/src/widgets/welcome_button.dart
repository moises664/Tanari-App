import 'package:flutter/material.dart';

class WelcomeButton extends StatelessWidget {
  final String? buttonText;
  // CAMBIO CLAVE AQUÍ: 'onTap' ahora es una VoidCallback (una función que no devuelve nada y no toma argumentos)
  final VoidCallback? onTap; // Ahora acepta una función, y puede ser nula.
  final Color? color;
  final Color? textColor;

  const WelcomeButton({
    super.key,
    this.buttonText,
    required this.onTap, // Lo hacemos requerido para asegurar que siempre haya una acción
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Ahora, 'onTap' del GestureDetector es directamente la función 'onTap' que recibe WelcomeButton
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: color!,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
          ),
        ),
        child: Text(
          buttonText!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor!,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
