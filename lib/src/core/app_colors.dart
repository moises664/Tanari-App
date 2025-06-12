import 'dart:ui'; // Importar para usar la clase Color

/// Clase que define la paleta de colores principal para la aplicación.
/// Centraliza la definición de colores para asegurar coherencia en el diseño
/// y facilitar futuros cambios de tema.
class AppColors {
  // *******************
  // ** Colores Primarios y de Acento **
  // *******************

  /// Color primario de la marca. Un verde lima brillante, ideal para elementos interactivos y destacados.
  static const Color primary = Color(0xFFBFF205);

  /// Color secundario que complementa al primario. Un amarillo verdoso claro.
  static const Color secondary = Color(0xFFD7F205);

  /// Otra variante de color secundario, un verde oliva oscuro. Útil para fondos sutiles o elementos menos prominentes.
  static const Color secondary1 = Color(0xFF7D8C0B);

  /// Color de acento principal. Un azul profundo, ideal para headers o elementos importantes que necesiten contraste.
  static const Color accent = Color(0xFF040240);

  /// Color de acento específico para indicar estados activos, resaltados o éxito. Un verde vibrante.
  static const Color accentColor =
      Color(0xFF4CAF50); // Un verde vibrante para estados activos

  // *******************
  // ** Colores de Fondo **
  // *******************

  /// Color de fondo principal para la mayoría de las pantallas. Un gris muy claro que proporciona una base limpia.
  static const Color backgroundPrimary = Color(0xFFF5F5F5);

  /// Color blanco puro, ideal para elementos que requieran máxima claridad o contraste.
  static const Color backgroundWhite = Color(0xFFFFFFFF);

  /// Color de fondo secundario. Un gris medio, puede usarse para secciones o tarjetas con un contraste sutil.
  static const Color backgroundSecondary = Color(0xff707266);

  /// Color de fondo claro para paneles, tarjetas o contenedores que necesiten diferenciarse del fondo principal.
  static const Color backgroundLight = Color(0xFFE0E0E0);

  /// Color negro intenso, ideal para headers oscuros, textos en fondos claros o elementos con alto contraste.
  static const Color backgroundBlack = Color(0xFF0D0D0D);

  // *******************
  // ** Colores de Texto **
  // *******************

  /// Color principal para textos (títulos, párrafos importantes) en fondos claros. Un gris oscuro.
  static const Color textPrimary = Color(0xFF212121);

  /// Color secundario para textos menos importantes o complementarios. Un gris medio.
  static const Color textSecondary = Color(0xFF757575);
}
