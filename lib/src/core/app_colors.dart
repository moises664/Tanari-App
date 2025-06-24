import 'package:flutter/material.dart';

/// Define una paleta de colores personalizada para la aplicación Tanari.
/// Centraliza la gestión de colores para una UI consistente.
class AppColors {
  // Colores primarios y de acento
  static const Color primary = Color(0xFF8BC34A); // Verde lima vibrante
  static const Color primaryDark =
      Color(0xFF689F38); // Verde oscuro para elementos primarios
  static const Color accent =
      Color(0xFF2196F3); // Azul profundo para elementos interactivos y gráficos
  static const Color accentColor =
      Color(0xFF4CAF50); // Un verde vibrante, usado para éxito/conexión
  static const Color secondary = Color(0xFFCDDC39); // Amarillo verdoso claro
  static const Color secondary1 = Color(0xFF42A5F5); // Un azul más claro
  static const Color secondary2 =
      Color(0xFF4CAF50); // Verde vibrante para elementos secundarios/grabar

  // Colores de texto
  static const Color textPrimary =
      Color(0xFF212121); // Gris muy oscuro para texto principal
  static const Color textSecondary =
      Color(0xFF757575); // Gris medio para texto secundario

  // Colores de fondo
  static const Color backgroundWhite =
      Color(0xFFFFFFFF); // Blanco puro para fondos y tarjetas
  static const Color backgroundLight =
      Color(0xFFF5F5F5); // Gris muy claro para fondos generales
  static const Color backgroundPrimary =
      Color(0xFFE0E0E0); // Gris más oscuro para secciones de fondo
  static const Color backgroundBlack =
      Color(0xFF000000); // Negro puro para contrastes fuertes

  // Colores de estado
  static const Color error =
      Color(0xFFD32F2F); // Rojo para errores y advertencias
  static const Color warning = Color(0xFFFFC107); // Amarillo para advertencias
  static const Color info = Color(0xFF03A9F4); // Azul claro para información
  static const Color success = Color(0xFF4CAF50); // Verde para éxito

  // Colores neutros
  static const Color neutral =
      Color(0xFF9E9E9E); // Gris neutro, útil para deshabilitado
  static const Color neutralLight = Color(0xFFE0E0E0); // Gris muy claro neutro
  static const Color neutralDark =
      Color(0xFF616161); // Nuevo color neutro oscuro

  // Colores específicos para gráficos de sensores
  static const Color chartCO2 =
      Color(0xFF8BC34A); // Un verde para CO2 (similar a primary)
  static const Color chartCH4 = Color(0xFFFF5722); // Naranja rojizo para CH4
  static const Color chartTemperature =
      Color(0xFFE53935); // Rojo para Temperatura
  static const Color chartHumidity =
      Color(0xFF2196F3); // Azul para Humedad (similar a accent)
}
