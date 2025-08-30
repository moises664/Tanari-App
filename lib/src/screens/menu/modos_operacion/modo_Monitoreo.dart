import 'dart:async'; // Necesario para usar Timer

import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:get/get.dart'; // Importar GetX para inyección y reactividad
import 'package:tanari_app/src/services/api/operation_data_service.dart'; // Importar el servicio

/// **Pantalla Principal para el Monitoreo de Datos Ambientales (Modo DP)**
///
/// Esta pantalla muestra en tiempo real los valores de los sensores recibidos
/// del dispositivo Tanari DP a través de Bluetooth Low Energy (BLE).
class ModoMonitoreo extends StatefulWidget {
  const ModoMonitoreo({super.key});

  @override
  State<ModoMonitoreo> createState() => _ModoDPState();
}

class _ModoDPState extends State<ModoMonitoreo> {
  //----------------------------------------------------------------------------
  // INYECCIÓN DE DEPENDENCIAS Y CONTROLADORES
  //----------------------------------------------------------------------------
  final BleController _bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();

  //----------------------------------------------------------------------------
  // VARIABLES DE ESTADO Y CONTROL
  //----------------------------------------------------------------------------
  final RxString _co2 = '--'.obs;
  final RxString _ch4 = '--'.obs;
  final RxString _temperatura = '--'.obs;
  final RxString _humedad = '--'.obs;
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);
  int _currentBatchSequence = 0;
  Timer? _debounceTimer;

  //----------------------------------------------------------------------------
  // MÉTODOS DEL CICLO DE VIDA DEL WIDGET
  //----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _bleController.portableData.listen((data) {
      if (mounted) {
        _co2.value = data['co2'] ?? '--';
        _ch4.value = data['ch4'] ?? '--';
        _temperatura.value = data['temperature'] ?? '--';
        _humedad.value = data['humidity'] ?? '--';
        if (_currentActiveSession.value != null) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            _currentBatchSequence++;
            final String sessionId = _currentActiveSession.value!.id;
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'CO2',
              value: double.tryParse(_co2.value) ?? 0.0,
              unit: 'ppm',
              batchSequence: _currentBatchSequence,
            );
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'CH4',
              value: double.tryParse(_ch4.value) ?? 0.0,
              unit: 'ppm',
              batchSequence: _currentBatchSequence,
            );
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'Temperatura',
              value: double.tryParse(_temperatura.value) ?? 0.0,
              unit: 'ºC',
              batchSequence: _currentBatchSequence,
            );
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'Humedad',
              value: double.tryParse(_humedad.value) ?? 0.0,
              unit: '%',
              batchSequence: _currentBatchSequence,
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE SESIÓN
  //----------------------------------------------------------------------------
  Future<void> _startMonitoring() async {
    String? operationName;
    String? description;

    await Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.backgroundWhite,
        title: Text('Crear Nuevo Registro',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Nombre del Registro (Obligatorio)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.neutralLight)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: (value) => operationName = value,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'Descripción (Opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.neutralLight)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: (value) => description = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancelar', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () {
              if (operationName != null && operationName!.isNotEmpty) {
                Get.back();
              } else {
                Get.snackbar(
                  'Error',
                  'El nombre del registro es obligatorio',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.backgroundWhite,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: Text('Crear y Grabar',
                style: TextStyle(color: AppColors.backgroundWhite)),
          ),
        ],
      ),
    );

    if (operationName == null || operationName!.isEmpty) {
      Get.snackbar(
        'Registro Cancelado',
        'La operación de monitoreo no fue iniciada.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final List<OperationSession> sessions =
        await _operationDataService.userOperationSessions;
    final OperationSession? session =
        await _operationDataService.createOperationSession(
      operationName: operationName,
      description: description,
      mode: 'manual',
      routeNumber: sessions.length + 1,
    );

    if (session != null) {
      _currentActiveSession.value = session;
      _currentBatchSequence = 0;
      Get.snackbar(
        'Monitoreo Iniciado',
        'Sesión "${session.operationName}" iniciada con éxito.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.accentColor,
        colorText: AppColors.backgroundWhite,
      );
    } else {
      Get.snackbar(
        'Error al Iniciar',
        'No se pudo iniciar la sesión de monitoreo. Intente de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.backgroundWhite,
      );
    }
  }

  Future<void> _stopMonitoring() async {
    if (_currentActiveSession.value != null) {
      final bool success = await _operationDataService.endOperationSession(
        _currentActiveSession.value!.id,
      );
      if (success) {
        _currentActiveSession.value = null;
        _currentBatchSequence = 0;
        _debounceTimer?.cancel();
        Get.snackbar(
          'Monitoreo Detenido',
          'Sesión finalizada con éxito.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.secondary,
          colorText: AppColors.textPrimary,
        );
      } else {
        Get.snackbar(
          'Error al Detener',
          'No se pudo finalizar la sesión de monitoreo.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite,
        );
      }
    } else {
      Get.snackbar(
          'Advertencia', 'No hay una sesión de monitoreo activa para detener.');
    }
  }

  //----------------------------------------------------------------------------
  // SECCIÓN DE CONSTRUCCIÓN DE LA INTERFAZ DE USUARIO (UI)
  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('Modo DP',
            style: TextStyle(
                color: AppColors.backgroundWhite, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 2,
      ),
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
              _buildStatusIndicatorsPanel(theme),
              const SizedBox(height: 20),
              _buildRecordingControlPanel(),
              const SizedBox(height: 25),
              _buildHeader(theme),
              const SizedBox(height: 15),
              _buildSensorList(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicatorsPanel(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Obx(() => _buildConnectionStatus(
              theme,
              _bleController.isPortableConnected.value,
              BleController.deviceNameDP)),
        ),
        const SizedBox(width: 15),
        Expanded(child: Obx(() => _buildBatteryStatus(theme))),
      ],
    );
  }

  Widget _buildRecordingControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.accent.withAlpha(25),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel de Grabación de Sensores',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Obx(() => ElevatedButton.icon(
                      onPressed: _currentActiveSession.value == null
                          ? _startMonitoring
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Crear Registro'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.backgroundWhite,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                      ),
                    )),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Obx(() => ElevatedButton.icon(
                      onPressed: _currentActiveSession.value != null
                          ? _stopMonitoring
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Detener Monitoreo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.backgroundWhite,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                      ),
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Monitoreo Ambiental',
      style: theme.textTheme.headlineSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSensorList() {
    return Column(
      children: [
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'CO2',
                value: _co2.value,
                unit: 'ppm',
                icon: Icons.cloud,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.accent,
              ),
            )),
        const SizedBox(height: 15),
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'CH4',
                value: _ch4.value,
                unit: 'ppm',
                icon: Icons.local_fire_department,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.error,
              ),
            )),
        const SizedBox(height: 15),
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'Temperatura',
                value: _temperatura.value,
                unit: 'ºC',
                icon: Icons.thermostat,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.secondary,
              ),
            )),
        const SizedBox(height: 15),
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'Humedad',
                value: _humedad.value,
                unit: '%',
                icon: Icons.water_drop,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.accentColor,
              ),
            )),
      ],
    );
  }

  Widget _buildSensorCardContainer(Widget sensorCard) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.backgroundBlack.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: sensorCard,
    );
  }

  Widget _buildConnectionStatus(
      ThemeData theme, bool isConnected, String deviceName) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.accentColor.withAlpha(38)
            : AppColors.error.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? AppColors.accentColor : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? AppColors.accentColor : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected ? 'Conectado' : 'Desconectado',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isConnected ? AppColors.accentColor : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// **Construye un widget para mostrar el estado de la batería en tiempo real.**
  Widget _buildBatteryStatus(ThemeData theme) {
    final int batteryLevel = _bleController.portableBatteryLevel.value;

    IconData batteryIcon;
    Color iconColor;

    if (batteryLevel == 0 || !_bleController.isPortableConnected.value) {
      batteryIcon = Icons.battery_unknown;
      iconColor = AppColors.neutral;
    } else if (batteryLevel > 80) {
      batteryIcon = Icons.battery_full;
      iconColor = AppColors.accentColor;
    } else if (batteryLevel > 40) {
      batteryIcon = Icons.battery_std;
      iconColor = AppColors.warning;
    } else if (batteryLevel > 15) {
      batteryIcon = Icons.battery_alert;
      iconColor = AppColors.warning;
    } else {
      batteryIcon = Icons.battery_alert_sharp;
      iconColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: iconColor,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(batteryIcon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              batteryLevel > 0 && _bleController.isPortableConnected.value
                  ? '$batteryLevel%'
                  : '--%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

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
              color: iconColor.withAlpha(39),
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
                    color: AppColors.textPrimary,
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
                      color: AppColors.backgroundBlack,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                    children: [
                      TextSpan(
                        text: ' $unit',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
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
