import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/screens/menu/modos_historial/ugv_routes_screen.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';

class ModoUgv extends StatefulWidget {
  const ModoUgv({super.key});
  @override
  State<ModoUgv> createState() => _ModoUgvState();
}

class _ModoUgvState extends State<ModoUgv> {
  final BleController bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final Logger _logger = Logger();

  String? _lastSentDirectionalCommand;
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _routeOriginDescController =
      TextEditingController();
  final RxBool _isRecordingRoute = false.obs;
  final Rx<OperationSession?> _selectedRoute = Rx<OperationSession?>(null);
  final RxBool _isAutoModeActive = false.obs;
  final RxBool _isAwaitingEndOfRoute = false.obs;
  Timer? _obstacleDialogTimer;

  @override
  void initState() {
    super.initState();
    _lastSentDirectionalCommand = BleController.stop;

    ever(bleController.isUgvConnected, (isConnected) {
      if (!isConnected && mounted) {
        _logger.w("UGV Desconectado. Reseteando todos los estados de la UI.");
        if (_currentActiveSession.value != null) {
          _operationDataService
              .endOperationSession(_currentActiveSession.value!.id);
        }
        _currentActiveSession.value = null;
        _isRecordingRoute.value = false;
        _isAutoModeActive.value = false;
        _selectedRoute.value = null;
        _isAwaitingEndOfRoute.value = false;
      }
    });

    ever(bleController.activeRouteNumber, (routeNum) {
      if (routeNum == 0 &&
          (_isAutoModeActive.value || _isAwaitingEndOfRoute.value)) {
        if (mounted) {
          _logger
              .i("Número de ruta es 0, finalizando modo automático en la UI.");
          _isAutoModeActive.value = false;
          _isAwaitingEndOfRoute.value = false;
          _selectedRoute.value = null;
          Get.snackbar(
              "Modo Automático Finalizado", "El UGV ha completado su tarea.");
        }
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
    _routeNameController.dispose();
    _routeOriginDescController.dispose();
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

  Future<void> _showCreateRouteDialog() async {
    _routeNameController.clear();
    _routeOriginDescController.clear();

    if (bleController.gpsHasFix.value) {
      _routeOriginDescController.text =
          'Coordenadas GPS: ${bleController.latitude.value.toPrecision(6)}, ${bleController.longitude.value.toPrecision(6)}';
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Crear Nueva Ruta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _routeNameController,
              decoration: const InputDecoration(labelText: 'Nombre de la Ruta'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _routeOriginDescController,
              decoration: const InputDecoration(
                  labelText: 'Descripción del Punto de Origen'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (_routeNameController.text.isNotEmpty) {
                Get.back();
                _startRouteRecording();
              } else {
                Get.snackbar('Error', 'El nombre de la ruta es obligatorio.');
              }
            },
            child: const Text('Crear y Grabar'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRouteRecording() async {
    if (bleController.memoryStatus.value) {
      Get.snackbar('Memoria Llena', 'No se puede grabar una nueva ruta.');
      return;
    }

    final session = await _operationDataService.createOperationSession(
      operationName: _routeNameController.text,
      description: _routeOriginDescController.text,
      mode: 'recording',
    );

    if (session != null && bleController.ugvDeviceId != null) {
      _currentActiveSession.value = session;
      _isRecordingRoute.value = true;
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.startRecording);
      Get.snackbar('Grabación Iniciada', 'Mueva el UGV y guarde los puntos.');
    }
  }

  void _recordPoint() {
    if (_isRecordingRoute.value && bleController.ugvDeviceId != null) {
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.recordPoint);
      Get.snackbar('Punto Guardado', 'Punto de la ruta registrado.',
          duration: const Duration(seconds: 1));
    }
  }

  Future<void> _finishRecording() async {
    if (!_isRecordingRoute.value ||
        bleController.ugvDeviceId == null ||
        _currentActiveSession.value == null) {
      return;
    }

    bleController.sendData(
        bleController.ugvDeviceId!, BleController.endRecording);

    Get.dialog(
      const AlertDialog(
        title: Text('Guardando Ruta'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Esperando confirmación del UGV...'),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    StreamSubscription? subscription;
    Timer? timeout;

    timeout = Timer(const Duration(seconds: 10), () {
      subscription?.cancel();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('Error', 'El UGV no respondió a tiempo.');
      _resetRecordingState();
    });

    subscription = bleController.newRouteIndicator.listen((indicator) async {
      if (indicator != null) {
        timeout?.cancel();
        subscription?.cancel();
        if (Get.isDialogOpen ?? false) Get.back();

        await _operationDataService.updateOperationSession(
          sessionId: _currentActiveSession.value!.id,
          newMode: 'recorded',
          newIndicator: indicator,
        );

        Get.snackbar('Ruta Guardada', 'Indicador asignado por UGV: $indicator');
        _resetRecordingState();
      }
    });
  }

  void _resetRecordingState() {
    _isRecordingRoute.value = false;
    _currentActiveSession.value = null;
  }

  void _setSpeed(int speed) {
    if (bleController.ugvDeviceId != null) {
      bleController.sendData(bleController.ugvDeviceId!, 'SET_VEL:$speed');
    }
  }

  void _setWaitTime(int milliseconds) {
    if (bleController.ugvDeviceId != null) {
      bleController.sendData(
          bleController.ugvDeviceId!, 'SET_WAIT:$milliseconds');
    }
  }

  Future<void> _showConfigDialog() async {
    final speedController = TextEditingController(
        text: bleController.currentSpeed.value.toString());
    final waitTimeController = TextEditingController();
    final selectedUnit = 'Segundos'.obs;

    if (bleController.currentWaitTime.value >= 1000) {
      waitTimeController.text =
          (bleController.currentWaitTime.value / 1000).toStringAsFixed(0);
    }

    await Get.dialog(
      AlertDialog(
        title: const Text('Configuración Manual'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Velocidad (RPM)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: speedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Ej. 180'),
              ),
              const SizedBox(height: 20),
              const Text('Tiempo de Espera',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: waitTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Ej. 5'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Obx(() => DropdownButton<String>(
                        value: selectedUnit.value,
                        items: ['Segundos', 'Minutos'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            selectedUnit.value = newValue;
                          }
                        },
                      )),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final speed = int.tryParse(speedController.text);
              if (speed != null && speed > 0) {
                _setSpeed(speed);
              }

              final waitTimeValue = int.tryParse(waitTimeController.text);
              if (waitTimeValue != null && waitTimeValue >= 0) {
                int milliseconds = waitTimeValue * 1000;
                if (selectedUnit.value == 'Minutos') {
                  milliseconds *= 60;
                }
                _setWaitTime(milliseconds);
              }
              Get.back();
              Get.snackbar('Configuración Enviada',
                  'Los nuevos valores han sido enviados al UGV.');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // --- INICIO DE CAMBIO: Lógica de extracción de datos modificada ---
  Future<void> _extractData() async {
    if (bleController.ugvDeviceId == null) return;

    // 1. Pedir nombre y descripción para la nueva sesión
    String? name;
    String? description;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Nueva Sesión para Datos Recuperados'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                  labelText: 'Nombre de la Sesión (Obligatorio)'),
              onChanged: (value) => name = value,
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name != null && name!.trim().isNotEmpty) {
                Get.back(result: true);
              } else {
                Get.snackbar('Error', 'El nombre de la sesión es obligatorio.');
              }
            },
            child: const Text('Extraer y Guardar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 2. Iniciar el proceso de extracción desde el UGV
    bleController.ugvDatabaseData.clear();
    bleController.extractionStatus.value = null;
    bleController.isExtractingData.value = true;

    bleController.sendData(
        bleController.ugvDeviceId!, BleController.extractData);

    Get.dialog(
      const AlertDialog(
        title: Text('Extrayendo Datos'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Recibiendo datos del UGV...'),
        ]),
      ),
      barrierDismissible: false,
    );

    Timer(const Duration(seconds: 15), () {
      if (bleController.isExtractingData.value) {
        bleController.isExtractingData.value = false;
        bleController.extractionStatus.value = 'error';
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar(
            'Error de Extracción', 'No se recibieron datos del UGV a tiempo.',
            backgroundColor: AppColors.error, colorText: Colors.white);
      }
    });

    // 3. Esperar el resultado y subir a la nueva tabla
    once(bleController.extractionStatus, (status) async {
      if (status != null) {
        if (Get.isDialogOpen ?? false) Get.back();

        if (status == 'completed') {
          final data = List<String>.from(bleController.ugvDatabaseData);
          _showExtractedDataDialog(data);
          await _operationDataService.uploadRecoveredDataToNewTable(data,
              name: name!,
              description:
                  description ?? 'Datos recuperados del UGV en modo manual.');
        } else if (status == 'empty') {
          Get.dialog(AlertDialog(
            title: const Text('Información'),
            content: const Text('La base de datos del UGV está vacía.'),
            actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
          ));
        }
      }
    });
  }
  // --- FIN DE CAMBIO ---

  void _showExtractedDataDialog(List<String> data) {
    if (data.isEmpty) {
      Get.snackbar(
          'Información', 'La extracción se completó sin datos para mostrar.');
      return;
    }

    List<DataRow> tableRows = [];

    for (var line in data) {
      final values = line.split(';');
      final cleanedValues = values.map((v) => v.trim()).toList();

      if (cleanedValues.length >= 4) {
        List<DataCell> cells = [];
        if (cleanedValues.length == 6) {
          cells.add(DataCell(Text(cleanedValues[0]))); // Ruta
          cells.add(DataCell(Text(cleanedValues[1]))); // Punto
          cells.add(DataCell(Text(cleanedValues[2]))); // CO2
          cells.add(DataCell(Text(cleanedValues[3]))); // CH4
          cells.add(DataCell(Text(cleanedValues[4]))); // Temp
          cells.add(DataCell(Text(cleanedValues[5]))); // Hum
        } else {
          cells.add(const DataCell(Text('-')));
          cells.add(const DataCell(Text('-')));
          cells.add(DataCell(Text(cleanedValues[0]))); // CO2
          cells.add(DataCell(Text(cleanedValues[1]))); // CH4
          cells.add(DataCell(Text(cleanedValues[2]))); // Temp
          cells.add(DataCell(Text(cleanedValues[3]))); // Hum
        }
        tableRows.add(DataRow(cells: cells));
      }
    }

    if (tableRows.isEmpty) {
      Get.snackbar('Advertencia',
          'No se encontraron datos con formato válido para mostrar.');
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Datos Extraídos del UGV'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Ruta')),
                  DataColumn(label: Text('Punto')),
                  DataColumn(label: Text('CO2')),
                  DataColumn(label: Text('CH4')),
                  DataColumn(label: Text('Temp')),
                  DataColumn(label: Text('Hum')),
                ],
                rows: tableRows,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cerrar'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
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
          '"${result.operationName}" (${result.indicator}) lista para ejecución.');
    }
  }

  void _handleAutoButton() {
    if (bleController.ugvDeviceId == null) return;
    if (_isAutoModeActive.value) {
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.cancelAuto);
      _isAwaitingEndOfRoute.value = true;
      Get.snackbar('Cancelando Ruta',
          'El UGV regresará al punto de inicio y se detendrá.');
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
      if (_selectedRoute.value != null) _selectedRoute.value = null;
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
        title: Text('Modo UGV',
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
            _buildStatusIndicatorsPanel(Theme.of(context)),
            const SizedBox(height: 20),
            _buildConfigPanel(),
            const SizedBox(height: 20),
            _buildAutoPanel(),
            const SizedBox(height: 20),
            _buildRecordingPanel(),
            const SizedBox(height: 20),
            _buildManualControlPanel(),
          ],
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
                bleController.isUgvConnected.value,
                BleController.deviceNameUGV,
              )),
        ),
        const SizedBox(width: 15),
        Expanded(child: Obx(() => _buildBatteryStatus(theme))),
      ],
    );
  }

  Widget _buildBatteryStatus(ThemeData theme) {
    final int batteryLevel = bleController.batteryLevel.value;
    final bool isConnected = bleController.isUgvConnected.value;

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
          Expanded(
            child: Text(
              isConnected ? '$batteryLevel%' : '--%',
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
          Text(
            isConnected ? 'Conectado' : 'Desconectado',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isConnected ? AppColors.accentColor : AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.accentColor.withAlpha(25),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Panel de Configuración',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: bleController.isUgvConnected.value
                    ? _showConfigDialog
                    : null,
                tooltip: 'Configuración Manual',
              ),
            ],
          ),
          const Divider(height: 20),
          Obx(() => _buildConfigItem(
              'Velocidad Actual: ${bleController.currentSpeed.value} RPM')),
          Obx(() => _buildConfigItem(
              'Tiempo de Espera: ${bleController.currentWaitTime.value} ms')),
          Obx(() => _buildConfigItem(
              'Memoria: ${bleController.memoryStatus.value ? "Llena" : "Disponible"}',
              isWarning: bleController.memoryStatus.value)),
          Obx(() => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildConfigItem('Evasión de Obstáculos:'),
                  Switch(
                    value: bleController.evasionModeActive.value,
                    onChanged: (bleController.isUgvConnected.value)
                        ? (value) => bleController.sendEvadeMode(value)
                        : null,
                    activeColor: AppColors.accentColor,
                  ),
                ],
              )),
          const SizedBox(height: 10),
          SizedBox(
              width: double.infinity,
              child: _buildConfigButton('Extraer Base de Datos', _extractData)),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String title, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              color: isWarning ? AppColors.error : AppColors.textPrimary,
              fontWeight: isWarning ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildConfigButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: bleController.isUgvConnected.value ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(text),
    );
  }

  Widget _buildAutoPanel() {
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
          ],
        ),
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
                onPressed: bleController.isUgvConnected.value
                    ? _showUgvRoutesScreen
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary1,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ),
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
                  onPressed: bleController.isUgvConnected.value &&
                          (isReadyToExecute || _isAutoModeActive.value)
                      ? _handleAutoButton
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAutoModeActive.value
                        ? AppColors.error
                        : AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              );
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

  Widget _buildRecordingPanel() {
    return Obx(() => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: _isRecordingRoute.value
                ? Border.all(color: AppColors.error, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Text('Grabación de Ruta',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Crear'),
                      onPressed: bleController.isUgvConnected.value &&
                              !_isRecordingRoute.value
                          ? _showCreateRouteDialog
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text('Punto'),
                      onPressed: _isRecordingRoute.value ? _recordPoint : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.stop_circle),
                      label: const Text('Finalizar'),
                      onPressed:
                          _isRecordingRoute.value ? _finishRecording : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ));
  }

  Widget _buildManualControlPanel() {
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
        ],
      ),
      child: Column(
        children: [
          Text('Control Manual',
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
              onPressed: bleController.isUgvConnected.value
                  ? _interruptMovement
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ),
          const SizedBox(height: 20),
          Obx(() {
            final controlsEnabled = bleController.isUgvConnected.value &&
                !_isAutoModeActive.value &&
                !_isAwaitingEndOfRoute.value;

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
                            BleController.moveRight, controlsEnabled),
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
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }
}
