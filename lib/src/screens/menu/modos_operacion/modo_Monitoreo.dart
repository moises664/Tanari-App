import 'package:flutter/material.dart';

/// Pantalla principal para el monitoreo ambiental que muestra valores de sensores
/// en tarjetas con diseño consistente y colores personalizados.
class ModoMonitoreo extends StatefulWidget {
  const ModoMonitoreo({super.key});

  @override
  State<ModoMonitoreo> createState() => _ModoDPState();
}

/// Estado principal de la pantalla de monitoreo
class _ModoDPState extends State<ModoMonitoreo> {
  // Valores iniciales de los sensores
  String _co2 = '--';
  String _ch4 = '--';
  String _temperatura = '--';
  String _humedad = '--';

  // Paleta de colores verde para las tarjetas
  static const Color _verdePrincipal = Color(0xFF2E7D32);
  static const Color _verdeSecundario = Color(0xFF43A047);
  static const Color _verdeClaro = Color(0xFFC8E6C9);
  static const Color _verdeOscuro = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modo Tanari DP',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(
          color: Colors.lightGreenAccent,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _actualizarDatos,
            tooltip: 'Actualizar datos',
            color: Colors.blueAccent,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: 20,
          ),
          child: _buildMainPanel(theme, screenSize),
        ),
      ),
    );
  }

  /// Construye el panel principal con tarjetas de sensores
  Widget _buildMainPanel(ThemeData theme, Size screenSize) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _verdeClaro.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _verdePrincipal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 20),
          _buildSensorGrid(screenSize),
        ],
      ),
    );
  }

  /// Construye el encabezado del panel
  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Monitoreo Ambiental',
      style: theme.textTheme.headlineSmall?.copyWith(
        color: Colors.lightGreen,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Construye el grid de tarjetas de sensores
  Widget _buildSensorGrid(Size screenSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        final childAspectRatio = crossAxisCount == 2 ? 1.8 : 3.5;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          children: [
            _SensorCard(
              label: 'CO2',
              value: _co2,
              unit: 'ppm',
              icon: Icons.cloud,
              cardColor: Colors.green,
              iconColor: Colors.grey.shade700,
            ),
            _SensorCard(
              label: 'CH4',
              value: _ch4,
              unit: 'ppm',
              icon: Icons.local_fire_department,
              cardColor: Colors.green,
              iconColor: Colors.red.shade700,
            ),
            _SensorCard(
              label: 'Temperatura',
              value: _temperatura,
              unit: 'ºC',
              icon: Icons.thermostat,
              cardColor: Colors.green,
              iconColor: Colors.orange.shade800,
            ),
            _SensorCard(
              label: 'Humedad',
              value: _humedad,
              unit: '%',
              icon: Icons.water_drop,
              cardColor: Colors.green,
              iconColor: Colors.blue.shade700,
            ),
          ],
        );
      },
    );
  }

  /// Actualiza los valores de los sensores (simulación)
  void _actualizarDatos() {
    setState(() {
      _co2 = '450';
      _ch4 = '1.2';
      _temperatura = '25.5';
      _humedad = '65';
    });
  }
}

/// Tarjeta personalizada para mostrar valores de sensores
///
/// [label]: Nombre del sensor
/// [value]: Valor actual del sensor
/// [unit]: Unidad de medida
/// [icon]: Icono a mostrar
/// [cardColor]: Color base de la tarjeta (de la paleta verde)
/// [iconColor]: Color personalizado para el ícono
class _SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color cardColor;
  final Color iconColor;

  const _SensorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.cardColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          // Contenedor del ícono
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 15),
          // Contenido textual
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Etiqueta del sensor
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cardColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                // Valor y unidad
                RichText(
                  text: TextSpan(
                    text: value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    children: [
                      TextSpan(
                        text: ' $unit',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cardColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
