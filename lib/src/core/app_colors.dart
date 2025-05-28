import 'dart:ui';

/// Clase que define los colores principales de la aplicación.
/// Incluye colores primarios, secundarios, de fondo y para texto.
class AppColors {
  /// Color primario utilizado en la identidad visual principal de la app.
  static const Color primary = Color(0xFFBFF205); // Verde lima brillante

  /// Color secundario complementario al primario.
  static const Color secondary = Color(0xFFD7F205); // Amarillo verdoso claro

  /// Otra variante de color secundario para elementos adicionales.
  static const Color secondary1 = Color(0xFF7D8C0B); // Verde oliva oscuro

  /// Color de acento para elementos destacados.
  static const Color accent = Color(0xFF040240); // Azul profundo

  /// **NUEVO: Color de acento específico para estados activos o resaltados.**
  /// Este color se utilizará para indicar un estado "activo" o "presionado"
  /// en botones o elementos interactivos, como el modo automático.
  static const Color accentColor =
      Color(0xFF4CAF50); // Un verde vibrante para estados activos

  // *******************
  // ** Backgrounds **
  // *******************

  /// Color de fondo principal utilizado en la mayoría de las pantallas.
  static const Color backgroundPrimary = Color(0xFFF5F5F5); // Gris claro

  static const Color backgroundWhite = Color(0xFFFFFFFF); // Blanco
  static const Color backgroundSecondary = Color(0xff707266); // Gris muy claro

  /// Color de fondo secundario para secciones oscuras.
  static const Color backgroundBlack = Color(0xFF0D0D0D); // Negro intenso

  // *******************
  // ** Text Styles **
  // *******************

  /// Color principal para textos (títulos, párrafos importantes).
  static const Color textPrimary = Color(0xFF212121); // Gris oscuro

  /// Color secundario para textos menos importantes o complementarios.
  static const Color textSecondary = Color(0xFF757575); // Gris medio
}
