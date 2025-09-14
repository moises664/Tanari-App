import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';

class ModoMonitoreo extends StatefulWidget {
  const ModoMonitoreo({super.key});

  @override
  State<ModoMonitoreo> createState() => _ModoDPState();
}

class _ModoDPState extends State<ModoMonitoreo> {
  final BleController _bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();

  // Se mantiene tu lógica original de estado
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);
  int _currentBatchSequence = 0;
  Timer?
      _recordingTimer; // Cambiado de _debounceTimer a _recordingTimer para mayor claridad

  @override
  void initState() {
    super.initState();
    // En lugar de un debounce, usamos un listener que activa un timer periódico
    // para grabar datos a intervalos regulares.
    ever(_currentActiveSession, (OperationSession? session) {
      if (session != null) {
        _startPeriodicRecording();
      } else {
        _stopPeriodicRecording();
      }
    });
  }

  /// Inicia la grabación periódica de datos.
  void _startPeriodicRecording() {
    _recordingTimer?.cancel(); // Cancelar cualquier timer anterior
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentActiveSession.value != null) {
        _saveSensorReadings();
      }
    });
  }

  /// Detiene la grabación periódica.
  void _stopPeriodicRecording() {
    _recordingTimer?.cancel();
  }

  /// Guarda una instantánea de las lecturas actuales de los sensores.
  void _saveSensorReadings() {
    if (_currentActiveSession.value == null) return;

    _currentBatchSequence++;
    final String sessionId = _currentActiveSession.value!.id;

    // --- NUEVA IMPLEMENTACIÓN GPS: Capturar datos de GPS ---
    final hasFix = _bleController.gpsHasFix.value;
    final lat = _bleController.latitude.value;
    final lon = _bleController.longitude.value;

    // Guardar latitud y longitud solo si hay "fix" y no son los valores por defecto (0.0).
    final double? latitude = (hasFix && lat != 0.0) ? lat : null;
    final double? longitude = (hasFix && lon != 0.0) ? lon : null;
    // --- FIN NUEVA IMPLEMENTACIÓN GPS ---

    final readings = {
      'CO2': _bleController.portableData['co2'],
      'CH4': _bleController.portableData['ch4'],
      'Temperatura': _bleController.portableData['temperature'],
      'Humedad': _bleController.portableData['humidity'],
    };

    final units = {
      'CO2': 'ppm',
      'CH4': 'ppm',
      'Temperatura': 'ºC',
      'Humedad': '%',
    };

    readings.forEach((sensorType, valueStr) {
      if (valueStr != null) {
        final value = double.tryParse(valueStr);
        if (value != null) {
          _operationDataService.createSensorReading(
            sessionId: sessionId,
            sensorType: sensorType,
            value: value,
            unit: units[sensorType],
            batchSequence: _currentBatchSequence,
            // --- NUEVA IMPLEMENTACIÓN GPS: Pasar los valores al servicio ---
            latitude: latitude,
            longitude: longitude,
            // --- FIN NUEVA IMPLEMENTACIÓN GPS ---
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer
        ?.cancel(); // Asegurarse de cancelar el timer al salir de la pantalla
    super.dispose();
  }

  // Se mantiene tu lógica original para iniciar y detener el monitoreo
  Future<void> _startMonitoring() async {
    String? operationName;
    String? description;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.backgroundWhite,
        title: Text('Crear Nuevo Registro',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                  labelText: 'Nombre del Registro (Obligatorio)'),
              onChanged: (value) => operationName = value,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration:
                  const InputDecoration(labelText: 'Descripción (Opcional)'),
              onChanged: (value) => description = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () {
              if (operationName != null && operationName!.trim().isNotEmpty) {
                Get.back(result: true);
              } else {
                Get.snackbar('Error', 'El nombre del registro es obligatorio');
              }
            },
            child: const Text('Crear y Grabar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final session = await _operationDataService.createOperationSession(
      operationName: operationName,
      description: description,
      mode: 'manual',
    );

    if (session != null) {
      _currentActiveSession.value = session;
      _currentBatchSequence = 0;
      Get.snackbar('Monitoreo Iniciado',
          'Sesión "${session.operationName}" iniciada con éxito.');
    } else {
      Get.snackbar('Error', 'No se pudo iniciar la sesión de monitoreo.');
    }
  }

  Future<void> _stopMonitoring() async {
    if (_currentActiveSession.value != null) {
      final bool success = await _operationDataService.endOperationSession(
        _currentActiveSession.value!.id,
      );
      if (success) {
        _currentActiveSession.value = null; // Esto detendrá el timer periódico
        _currentBatchSequence = 0;
        Get.snackbar('Monitoreo Detenido', 'Sesión finalizada con éxito.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tu UI original se mantiene
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('Modo Monitoreo (DP)',
            style: TextStyle(
                color: AppColors.backgroundWhite, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusIndicatorsPanel(theme),
            const SizedBox(height: 20),
            _buildRecordingControlPanel(),
            const SizedBox(height: 25),
            Text('Monitoreo Ambiental en Tiempo Real',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 15),
            _buildSensorGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicatorsPanel(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Obx(() => _buildConnectionStatus(theme,
                    _bleController.isPortableConnected.value, "Tanari DP"))),
            const SizedBox(width: 15),
            Expanded(child: Obx(() => _buildBatteryStatus(theme))),
          ],
        ),
        const SizedBox(height: 10),
        // --- NUEVA IMPLEMENTACIÓN GPS: El widget indicador se añade aquí ---
        Obx(() =>
            _buildGpsStatusIndicator(theme, _bleController.gpsHasFix.value)),
      ],
    );
  }

  // --- NUEVA IMPLEMENTACIÓN GPS: Widget para mostrar el estado del GPS ---
  Widget _buildGpsStatusIndicator(ThemeData theme, bool hasFix) {
    final color = hasFix ? AppColors.accentColor : AppColors.error;
    final text = hasFix ? 'GPS Conectado' : 'GPS Sin Señal';
    final icon = hasFix ? Icons.gps_fixed : Icons.gps_not_fixed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(text,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // El resto de tus widgets (_buildRecordingControlPanel, _buildSensorGrid, etc.) se mantienen intactos
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
          Text('Panel de Grabación',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          Obx(() => Text(
                _currentActiveSession.value != null
                    ? 'Grabando: "${_currentActiveSession.value!.operationName}"'
                    : 'Grabación detenida.',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: _currentActiveSession.value != null
                        ? AppColors.accentColor
                        : AppColors.textSecondary),
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Obx(() => ElevatedButton.icon(
                      onPressed: _currentActiveSession.value == null
                          ? _startMonitoring
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar'),
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Obx(() => ElevatedButton.icon(
                      onPressed: _currentActiveSession.value != null
                          ? _stopMonitoring
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Detener'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        Obx(() => _buildSensorCard(
            label: 'CO2',
            value: _bleController.portableData['co2'] ?? '--',
            unit: 'ppm',
            icon: Icons.cloud_queue,
            color: AppColors.primary)),
        Obx(() => _buildSensorCard(
            label: 'CH4',
            value: _bleController.portableData['ch4'] ?? '--',
            unit: 'ppm',
            icon: Icons.local_fire_department,
            color: AppColors.error)),
        Obx(() => _buildSensorCard(
            label: 'Temperatura',
            value: _bleController.portableData['temperature'] ?? '--',
            unit: '°C',
            icon: Icons.thermostat,
            color: AppColors.warning)),
        Obx(() => _buildSensorCard(
            label: 'Humedad',
            value: _bleController.portableData['humidity'] ?? '--',
            unit: '%',
            icon: Icons.water_drop,
            color: AppColors.info)),
      ],
    );
  }

  Widget _buildSensorCard(
      {required String label,
      required String value,
      required String unit,
      required IconData icon,
      required Color color}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$value $unit',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(
      ThemeData theme, bool isConnected, String deviceName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.accentColor.withAlpha(50)
            : AppColors.error.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isConnected ? AppColors.accentColor : AppColors.error,
            width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? AppColors.accentColor : AppColors.error),
          const SizedBox(width: 10),
          Text(isConnected ? 'Conectado' : 'Desconectado',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: isConnected ? AppColors.accentColor : AppColors.error,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBatteryStatus(ThemeData theme) {
    final int batteryLevel = _bleController.portableBatteryLevel.value;
    final bool isConnected = _bleController.isPortableConnected.value;
    IconData batteryIcon;
    Color iconColor;
    if (!isConnected) {
      batteryIcon = Icons.battery_unknown;
      iconColor = AppColors.neutral;
    } else if (batteryLevel > 80) {
      batteryIcon = Icons.battery_full;
      iconColor = AppColors.accentColor;
    } else if (batteryLevel > 40) {
      batteryIcon = Icons.battery_std;
      iconColor = AppColors.warning;
    } else {
      batteryIcon = Icons.battery_alert;
      iconColor = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(batteryIcon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Text(isConnected ? '$batteryLevel%' : '--%',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: iconColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
