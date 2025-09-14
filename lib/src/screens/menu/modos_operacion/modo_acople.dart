import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';
import 'package:tanari_app/src/screens/menu/modos_historial/ugv_routes_screen.dart';

class ModoAcople extends StatefulWidget {
  const ModoAcople({super.key});

  @override
  State<ModoAcople> createState() => _ModoAcopleState();
}

class _ModoAcopleState extends State<ModoAcople> {
  final BleController bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final Logger _logger = Logger();

  String? _lastSentDirectionalCommand;
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);
  final Rx<OperationSession?> _selectedRoute = Rx<OperationSession?>(null);
  final RxBool _isAutoModeActive = false.obs;
  final RxBool _isAwaitingEndOfRoute = false.obs;
  Timer? _recordingTimer;
  Timer? _obstacleDialogTimer;

  @override
  void initState() {
    super.initState();
    _lastSentDirectionalCommand = BleController.stop;

    // --- INICIO DE CAMBIO: Lógica de desconexión restaurada ---
    // Si hay una sesión activa y alguno de los dispositivos se desconecta, se cierra la sesión.
    everAll([bleController.isUgvConnected, bleController.isPortableConnected],
        (callback) {
      final isUgvConn = bleController.isUgvConnected.value;
      final isDpConn = bleController.isPortableConnected.value;

      if (_currentActiveSession.value != null && (!isUgvConn || !isDpConn)) {
        if (mounted) {
          Get.snackbar(
            "Desconexión Detectada",
            "La sesión de monitoreo se ha cerrado por seguridad.",
            backgroundColor: AppColors.error,
            colorText: Colors.white,
          );
          _stopSensorRecording();
        }
      }
    });
    // --- FIN DE CAMBIO ---

    ever(bleController.activeRouteNumber, (routeNum) {
      if (routeNum == 0 &&
          (_isAutoModeActive.value || _isAwaitingEndOfRoute.value)) {
        if (mounted) {
          _logger.i(
              "Número de ruta es 0, finalizando modo automático en la UI de Acople.");
          _isAutoModeActive.value = false;
          _isAwaitingEndOfRoute.value = false;
          _selectedRoute.value = null;
          Get.snackbar(
              "Modo Automático Finalizado", "El UGV ha completado su tarea.");
        }
      }
    });

    ever(_currentActiveSession, (OperationSession? session) {
      if (session != null) {
        _startPeriodicRecording();
      } else {
        _stopPeriodicRecording();
      }
    });

    ever(bleController.obstacleAlert, (showAlert) {
      if (showAlert && mounted) {
        _showObstacleDialog();
        bleController.obstacleAlert.value = false;
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _obstacleDialogTimer?.cancel();
    super.dispose();
  }

  void _showObstacleDialog() {
    _obstacleDialogTimer?.cancel();
    _obstacleDialogTimer = Timer(const Duration(seconds: 30), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
        Get.snackbar(
          "Tiempo Expirado",
          "Regresando al inicio por defecto.",
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    });

    Get.dialog(
      AlertDialog(
        title: const Text('¡Obstáculo Detectado!'),
        content: const Text(
            'El UGV ha encontrado un obstáculo en la ruta. ¿Qué desea hacer?'),
        actions: [
          TextButton(
            onPressed: () {
              _obstacleDialogTimer?.cancel();
              Get.back();
              bleController.sendReturnToOrigin();
            },
            child: Text('Regresar al Origen',
                style: TextStyle(color: AppColors.warning)),
          ),
          ElevatedButton(
            onPressed: () {
              _obstacleDialogTimer?.cancel();
              Get.back();
              bleController.sendStopAndStay();
            },
            child: const Text('Detener Recorrido'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _startPeriodicRecording() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentActiveSession.value != null &&
          bleController.isUgvConnected.value &&
          bleController.isPortableConnected.value) {
        _saveSensorReadings();
      }
    });
  }

  void _stopPeriodicRecording() {
    _recordingTimer?.cancel();
  }

  int _batchSequence = 0;
  void _saveSensorReadings() {
    if (_currentActiveSession.value == null) return;
    _batchSequence++;
    final String sessionId = _currentActiveSession.value!.id;

    final hasFix = bleController.gpsHasFix.value;
    final lat = bleController.latitude.value;
    final lon = bleController.longitude.value;
    final double? latitude = (hasFix && lat != 0.0) ? lat : null;
    final double? longitude = (hasFix && lon != 0.0) ? lon : null;

    final readings = {
      'CO2': bleController.portableData['co2'],
      'CH4': bleController.portableData['ch4'],
      'Temperatura': bleController.portableData['temperature'],
      'Humedad': bleController.portableData['humidity'],
    };
    final units = {
      'CO2': 'ppm',
      'CH4': 'ppm',
      'Temperatura': 'ºC',
      'Humedad': '%'
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
            batchSequence: _batchSequence,
            latitude: latitude,
            longitude: longitude,
            source: 'realtime',
          );
        }
      }
    });
  }

  Future<void> _startSensorRecording() async {
    if (!bleController.isPortableConnected.value ||
        !bleController.isUgvConnected.value) {
      Get.snackbar('Dispositivos no conectados',
          'Ambos dispositivos (DP y UGV) deben estar conectados.');
      return;
    }
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
      mode: 'coupled',
    );

    if (session != null) {
      _currentActiveSession.value = session;
      _batchSequence = 0;
      Get.snackbar(
          'Monitoreo Iniciado', 'Sesión "${session.operationName}" iniciada.');
    }
  }

  Future<void> _stopSensorRecording() async {
    if (_currentActiveSession.value == null) return;
    final success = await _operationDataService
        .endOperationSession(_currentActiveSession.value!.id);
    if (success) {
      Get.snackbar('Monitoreo Detenido',
          'Sesión "${_currentActiveSession.value!.operationName}" finalizada.');
      _currentActiveSession.value = null;
    }
  }

  Future<void> _showUgvRoutesScreen() async {
    if (_isAutoModeActive.value) {
      Get.snackbar('Acción no permitida',
          'Cancele la ejecución actual para seleccionar otra ruta.');
      return;
    }
    final result =
        await Get.to<OperationSession?>(() => const UgvRoutesScreen());
    if (result != null) {
      _selectedRoute.value = result;
      Get.snackbar('Ruta Seleccionada',
          '"${result.operationName}" lista para ejecución.');
    }
  }

  void _handleAutoButton() {
    if (bleController.ugvDeviceId == null) return;
    if (_isAutoModeActive.value) {
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.cancelAuto);
      _isAwaitingEndOfRoute.value = true;
      Get.snackbar('Cancelando Ruta', 'El UGV regresará al punto de inicio.');
    } else if (_selectedRoute.value != null) {
      bleController.sendData(
          bleController.ugvDeviceId!, _selectedRoute.value!.indicator!);
      _isAutoModeActive.value = true;
      _isAwaitingEndOfRoute.value = false;
      Get.snackbar('Iniciando Ruta',
          'Ejecutando "${_selectedRoute.value!.operationName}".');
    }
  }

  void _interruptMovement() {
    if (bleController.ugvDeviceId != null) {
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.interruption);
      if (_isAutoModeActive.value) _isAutoModeActive.value = false;
      if (_isAwaitingEndOfRoute.value) _isAwaitingEndOfRoute.value = false;
      _selectedRoute.value = null;
      Get.snackbar('Interrupción de Emergencia', 'Movimiento detenido.');
    }
  }

  void _startMovement(String command) {
    if (bleController.ugvDeviceId != null && !_isAutoModeActive.value) {
      if (_lastSentDirectionalCommand != command) {
        _lastSentDirectionalCommand = command;
        bleController.sendData(bleController.ugvDeviceId!, command);
      }
    }
  }

  void _stopMovement() {
    if (bleController.ugvDeviceId != null && !_isAutoModeActive.value) {
      bleController.sendData(bleController.ugvDeviceId!, BleController.stop);
      _lastSentDirectionalCommand = BleController.stop;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('Modo Acoplado',
            style: TextStyle(
                color: AppColors.backgroundWhite, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Obx(() {
          final bool isCoupledAndReady =
              bleController.isPhysicallyCoupled.value;
          return Opacity(
            opacity: isCoupledAndReady ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: !isCoupledAndReady,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusIndicatorsPanel(Theme.of(context)),
                  const SizedBox(height: 20),
                  _buildCouplingStatusIndicator(isCoupledAndReady),
                  const SizedBox(height: 20),
                  // --- INICIO DE CAMBIO: Estandarización de UI ---
                  _buildRecordingControlPanel(), // Reemplazado por el panel estandarizado
                  // --- FIN DE CAMBIO ---
                  const SizedBox(height: 20),
                  _buildAutoExecutionPanel(),
                  const SizedBox(height: 20),
                  _buildMonitoringPanel(),
                  const SizedBox(height: 20),
                  _buildUgvControlPanel(),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatusIndicatorsPanel(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(Icons.phone_android, color: AppColors.textSecondary),
            ),
            Expanded(
                child: Obx(() => _buildConnectionStatus(theme,
                    bleController.isPortableConnected.value, "Tanari DP"))),
            const SizedBox(width: 15),
            Expanded(child: Obx(() => _buildBatteryStatus(theme, isDP: true))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child:
                  Icon(FontAwesomeIcons.robot, color: AppColors.textSecondary),
            ),
            Expanded(
                child: Obx(() => _buildConnectionStatus(
                    theme, bleController.isUgvConnected.value, "Tanari UGV"))),
            const SizedBox(width: 15),
            Expanded(child: Obx(() => _buildBatteryStatus(theme, isDP: false))),
          ],
        ),
        const SizedBox(height: 10),
        Obx(() =>
            _buildGpsStatusIndicator(theme, bleController.gpsHasFix.value)),
      ],
    );
  }

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

  Widget _buildCouplingStatusIndicator(bool isCoupled) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCoupled
            ? AppColors.accentColor.withAlpha(50)
            : AppColors.error.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isCoupled ? AppColors.accentColor : AppColors.error,
            width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isCoupled ? Icons.link : Icons.link_off,
              color: isCoupled ? AppColors.accentColor : AppColors.error),
          const SizedBox(width: 10),
          Text(isCoupled ? 'Sistema Acoplado' : 'Sistema Desacoplado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isCoupled ? AppColors.accentColor : AppColors.error,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- INICIO DE CAMBIO: Panel de grabación estandarizado ---
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
                          ? _startSensorRecording
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar'),
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Obx(() => ElevatedButton.icon(
                      onPressed: _currentActiveSession.value != null
                          ? _stopSensorRecording
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
  // --- FIN DE CAMBIO ---

  Widget _buildMonitoringPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monitoreo Tanari DP',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          Obx(() => _buildDataRow(
              'CO2:', '${bleController.portableData['co2'] ?? '--'} ppm')),
          Obx(() => _buildDataRow(
              'CH4:', '${bleController.portableData['ch4'] ?? '--'} ppm')),
          Obx(() => _buildDataRow('Temperatura:',
              '${bleController.portableData['temperature'] ?? '--'} °C')),
          Obx(() => _buildDataRow('Humedad:',
              '${bleController.portableData['humidity'] ?? '--'} %')),
        ],
      ),
    );
  }

  Widget _buildAutoExecutionPanel() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          children: [
            Text('Ejecución Automática',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Obx(() => _isAutoModeActive.value
                ? _buildAutoStatusPanel()
                : Container()),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Seleccionar Ruta'),
                    onPressed: _showUgvRoutesScreen,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary1,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15)))),
            const SizedBox(height: 16),
            Obx(() {
              final isReadyToExecute = _selectedRoute.value != null;
              final buttonText = _isAutoModeActive.value
                  ? 'Cancelar Ruta (${_selectedRoute.value?.indicator ?? ''})'
                  : isReadyToExecute
                      ? 'Ejecutar Ruta (${_selectedRoute.value?.indicator})'
                      : 'Seleccione una Ruta';
              return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                      icon: Icon(_isAutoModeActive.value
                          ? Icons.cancel
                          : FontAwesomeIcons.robot),
                      label: Text(buttonText),
                      onPressed: (isReadyToExecute || _isAutoModeActive.value)
                          ? _handleAutoButton
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _isAutoModeActive.value
                              ? AppColors.error
                              : AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15))));
            }),
          ],
        ));
  }

  Widget _buildAutoStatusPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info, width: 1),
      ),
      child: Obx(() {
        final route = bleController.activeRouteNumber.value;
        final point = bleController.activePointNumber.value;
        final arrived =
            bleController.arrivedAtPoint.value == point && point > 0;
        final statusText = arrived
            ? "En el Punto $point"
            : (point > 0 ? "Hacia el Punto $point" : "Iniciando...");

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              arrived ? Icons.location_on : Icons.route,
              color: AppColors.info,
            ),
            const SizedBox(width: 8),
            Text(
              "Ruta $route - $statusText",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.info,
                fontSize: 16,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildUgvControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        children: [
          Text('Control Manual Tanari UGV',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  icon: const Icon(FontAwesomeIcons.hand),
                  label: const Text("STOP DE EMERGENCIA"),
                  onPressed: _interruptMovement,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15)))),
          const SizedBox(height: 20),
          Obx(() {
            final controlsEnabled =
                !_isAutoModeActive.value && !_isAwaitingEndOfRoute.value;
            return Opacity(
              opacity: controlsEnabled ? 1.0 : 0.4,
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _buildDirectionButton(Icons.arrow_upward,
                        BleController.moveForward, controlsEnabled)
                  ]),
                  const SizedBox(height: 10),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDirectionButton(Icons.arrow_back,
                            BleController.moveLeft, controlsEnabled),
                        _buildDirectionButton(Icons.arrow_forward,
                            BleController.moveRight, controlsEnabled)
                      ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _buildDirectionButton(Icons.arrow_downward,
                        BleController.moveBack, controlsEnabled)
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
        ]));
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
                width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? AppColors.accentColor : AppColors.error),
          const SizedBox(width: 10),
          Text(isConnected ? 'Conectado' : 'Desconectado',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: isConnected ? AppColors.accentColor : AppColors.error,
                  fontWeight: FontWeight.bold))
        ]));
  }

  Widget _buildBatteryStatus(ThemeData theme, {required bool isDP}) {
    final int batteryLevel = isDP
        ? bleController.portableBatteryLevel.value
        : bleController.batteryLevel.value;
    final bool isConnected = isDP
        ? bleController.isPortableConnected.value
        : bleController.isUgvConnected.value;
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
            border: Border.all(color: iconColor, width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(batteryIcon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(isConnected ? '$batteryLevel%' : '--%',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: iconColor, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis))
        ]));
  }

  Widget _buildDirectionButton(IconData icon, String command, bool isEnabled) {
    return GestureDetector(
        onTapDown: isEnabled ? (_) => _startMovement(command) : null,
        onTapUp: isEnabled ? (_) => _stopMovement() : null,
        onTapCancel: isEnabled ? () => _stopMovement() : null,
        child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
                color: isEnabled ? AppColors.accent : AppColors.neutral,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(51),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3))
                ]),
            child: Icon(icon, color: Colors.white, size: 40)));
  }
}
