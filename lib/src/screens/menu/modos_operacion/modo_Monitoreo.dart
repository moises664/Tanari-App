import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart'; // Importar GetX

/// Pantalla principal para el monitoreo de datos ambientales (Modo DP)
/// Muestra valores de sensores en tarjetas con diseño consistente y persistencia de datos.
class ModoMonitoreo extends StatefulWidget {
  const ModoMonitoreo({super.key});

  @override
  State<ModoMonitoreo> createState() => _ModoDPState();
}

/// Estado que gestiona la lógica de carga, actualización y visualización de los datos de los sensores.
class _ModoDPState extends State<ModoMonitoreo> {
  //----------------------------------------------------------------------------
  // VARIABLES DE ESTADO Y CONTROL
  //----------------------------------------------------------------------------

  // Inyectar el BleController
  final BleController _bleController = Get.find<BleController>();

  // Instancia de SharedPreferences para la persistencia de datos.
  SharedPreferences? _prefs;

  //----------------------------------------------------------------------------
  // MÉTODOS DEL CICLO DE VIDA DEL WIDGET
  //----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadSensorData(); // Carga los datos guardados al iniciar la pantalla

    // Observar los cambios en portableData del BleController
    _bleController.portableData.listen((data) {
      if (mounted) {
        // Asegúrate de que el widget aún esté montado
        setState(() {
          // Asigna los datos recibidos del BleController a las variables locales
          _co2 = data['co2'] ?? '--';
          _ch4 = data['ch4'] ?? '--';
          _temperatura = data['temperature'] ?? '--';
          _humedad = data['humidity'] ?? '--';
        });
        _saveSensorData(); // Guarda los nuevos datos automáticamente
      }
    });
  }

  // Las variables de sensor ahora son locales y se actualizan desde portableData
  String _co2 = '--';
  String _ch4 = '--';
  String _temperatura = '--';
  String _humedad = '--';

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE NEGOCIO Y PERSISTENCIA (Existentes)
  //----------------------------------------------------------------------------

  /// Carga los datos de los sensores desde SharedPreferences.
  Future<void> _loadSensorData() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _co2 = _prefs!.getString('co2') ?? '--';
      _ch4 = _prefs!.getString('ch4') ?? '--';
      _temperatura = _prefs!.getString('temperatura') ?? '--';
      _humedad = _prefs!.getString('humedad') ?? '--';
    });
  }

  /// Guarda los valores actuales de los sensores en SharedPreferences.
  Future<void> _saveSensorData() async {
    if (_prefs != null) {
      await _prefs!.setString('co2', _co2);
      await _prefs!.setString('ch4', _ch4);
      await _prefs!.setString('temperatura', _temperatura);
      await _prefs!.setString('humedad', _humedad);
    } else {
      debugPrint(
          "Advertencia: SharedPreferences no inicializado aún. No se pueden guardar datos.");
    }
  }

  // Ya no se necesita _actualizarDatos() porque la data viene del BLE

  //----------------------------------------------------------------------------
  // SECCIÓN DE INTERFAZ DE USUARIO
  //----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitleContainer(theme),
              const SizedBox(height: 20),
              _buildHeader(theme),
              const SizedBox(height: 20),
              // Nuevo: Indicador de estado de conexión del Tanari DP
              Obx(() => _buildConnectionStatus(
                  theme,
                  _bleController.isPortableConnected.value,
                  BleController.deviceNameDP)),
              const SizedBox(height: 20),
              _buildSensorList(),
              const SizedBox(height: 25),
              // Botones de control BLE para el Tanari DP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Obx(
                      () => ElevatedButton.icon(
                        onPressed: _bleController.isScanning.value
                            ? null
                            : () => _bleController.startScan(),
                        icon: _bleController.isScanning.value
                            ? const CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2)
                            : const Icon(Icons.bluetooth_searching,
                                color: AppColors.primary),
                        label: Text(
                          _bleController.isScanning.value
                              ? 'Escaneando...'
                              : 'Escanear BLE',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.backgroundBlack,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Obx(
                      () => ElevatedButton.icon(
                        onPressed: _bleController.isPortableConnected.value
                            ? () => _bleController.disconnectDevice(
                                _bleController.portableDeviceId!)
                            : null, // Solo habilitar si conectado
                        icon: const Icon(Icons.bluetooth_disabled,
                            color: AppColors.primary),
                        label: Text(
                          'Desconectar DP', // Texto específico para el DP
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.backgroundBlack,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el contenedor del título principal de la pantalla.
  Widget _buildTitleContainer(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Modo DP',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: AppColors.backgroundWhite,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Construye el encabezado (subtítulo) de la sección de monitoreo.
  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Monitoreo Ambiental',
      style: theme.textTheme.headlineSmall?.copyWith(
        color: AppColors.backgroundBlack,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Construye la lista de tarjetas de sensores.
  Widget _buildSensorList() {
    return Column(
      children: [
        _buildSensorCardContainer(
          _SensorCard(
            label: 'CO2',
            value: _co2,
            unit: 'ppm',
            icon: Icons.cloud,
            cardColor: Colors.green,
            iconColor: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 15),
        _buildSensorCardContainer(
          _SensorCard(
            label: 'CH4',
            value: _ch4,
            unit: 'ppm',
            icon: Icons.local_fire_department,
            cardColor: Colors.green,
            iconColor: Colors.red.shade700,
          ),
        ),
        const SizedBox(height: 15),
        _buildSensorCardContainer(
          _SensorCard(
            label: 'Temperatura',
            value: _temperatura,
            unit: 'ºC',
            icon: Icons.thermostat,
            cardColor: Colors.green,
            iconColor: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 15),
        _buildSensorCardContainer(
          _SensorCard(
            label: 'Humedad',
            value: _humedad,
            unit: '%',
            icon: Icons.water_drop,
            cardColor: Colors.green,
            iconColor: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  /// Envolver una _SensorCard en un Container con estilo para resaltarla.
  Widget _buildSensorCardContainer(Widget sensorCard) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: sensorCard,
    );
  }

  // Widget para mostrar el estado de la conexión BLE de un dispositivo específico
  Widget _buildConnectionStatus(
      ThemeData theme, bool isConnected, String deviceName) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
          ),
          const SizedBox(width: 10),
          Text(
            isConnected
                ? '$deviceName: Conectado'
                : '$deviceName: Desconectado',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de tarjeta individual para mostrar el valor de un sensor.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color.alphaBlend(cardColor.withAlpha(51), Colors.white),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cardColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    text: value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                    children: [
                      TextSpan(
                        text: ' $unit',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Color.alphaBlend(
                              cardColor.withAlpha(204), Colors.white),
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
