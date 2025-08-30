import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/screens/menu/modos_historial/ugv_routes_screen.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';

//==============================================================================
// PANTALLA DE CONTROL DEL UGV
//==============================================================================
class ModoUgv extends StatefulWidget {
  const ModoUgv({super.key});
  @override
  State<ModoUgv> createState() => _ModoUgvState();
}

class _ModoUgvState extends State<ModoUgv> {
  //--------------------------------------------------------------------------
  // INYECCIÓN DE DEPENDENCIAS Y LOGGING
  //--------------------------------------------------------------------------
  final BleController bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final Logger _logger = Logger();

  //--------------------------------------------------------------------------
  // VARIABLES DE ESTADO DE LA PANTALLA
  //--------------------------------------------------------------------------
  String? _lastSentDirectionalCommand;
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _routeDescController = TextEditingController();
  final RxBool _isRecordingRoute = false.obs;
  final Rx<OperationSession?> _selectedRoute = Rx<OperationSession?>(null);
  final RxBool _isAutoModeActive = false.obs;
  final RxBool _isAwaitingEndOfRoute = false.obs;

  //--------------------------------------------------------------------------
  // MÉTODOS DEL CICLO DE VIDA
  //--------------------------------------------------------------------------
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

    ever(bleController.receivedData, (String? data) {
      if (data == BleController.endAutoMode && mounted) {
        _logger
            .i("Recibido 'T' del UGV. Finalizando modo automático en la UI.");
        _isAutoModeActive.value = false;
        _isAwaitingEndOfRoute.value = false;
        _selectedRoute.value = null;
        Get.snackbar("Ruta Finalizada", "El UGV ha completado el recorrido.");
      }
    });
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _routeDescController.dispose();
    super.dispose();
  }

  //============================================================================
  // SECCIÓN: LÓGICA DE GRABACIÓN DE RUTAS (MODIFICADA)
  //============================================================================

  /// Muestra un diálogo para que el usuario ingrese el nombre y descripción de una nueva ruta.
  Future<void> _showCreateRouteDialog() async {
    _routeNameController.clear();
    _routeDescController.clear();
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
            TextField(
              controller: _routeDescController,
              decoration:
                  const InputDecoration(labelText: 'Descripción (Opcional)'),
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

  /// Inicia el proceso de grabación de una ruta.
  Future<void> _startRouteRecording() async {
    if (bleController.memoryStatus.value) {
      Get.snackbar('Memoria Llena', 'No se puede grabar una nueva ruta.');
      return;
    }

    // Crea una sesión temporal en la BD con modo 'recording' pero SIN indicador.
    final session = await _operationDataService.createOperationSession(
      operationName: _routeNameController.text,
      description: _routeDescController.text,
      mode: 'recording',
      // El indicador se dejará nulo hasta que el UGV lo confirme.
    );

    if (session != null && bleController.ugvDeviceId != null) {
      _currentActiveSession.value = session;
      _isRecordingRoute.value = true;
      bleController.sendData(bleController.ugvDeviceId!,
          BleController.startRecording); // Envía 'G'
      Get.snackbar('Grabación Iniciada', 'Mueva el UGV y guarde los puntos.');
    }
  }

  /// Envía el comando 'W' al UGV para que guarde un punto de la ruta.
  void _recordPoint() {
    if (_isRecordingRoute.value && bleController.ugvDeviceId != null) {
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.recordPoint); // Envía 'W'
      Get.snackbar('Punto Guardado', 'Punto de la ruta registrado.',
          duration: const Duration(seconds: 1));
    }
  }

  /// Finaliza el proceso de grabación y espera la confirmación del UGV.
  Future<void> _finishRecording() async {
    if (!_isRecordingRoute.value ||
        bleController.ugvDeviceId == null ||
        _currentActiveSession.value == null) {
      return;
    }

    // 1. Envía el comando 'E' al UGV para que finalice y guarde la ruta.
    bleController.sendData(
        bleController.ugvDeviceId!, BleController.endRecording);

    // Muestra un diálogo de espera.
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

    // 2. Inicia un listener para esperar el indicador de ruta del UGV.
    StreamSubscription? subscription;
    Timer? timeout;

    // Timeout por si el UGV no responde.
    timeout = Timer(const Duration(seconds: 10), () {
      subscription?.cancel();
      if (Get.isDialogOpen ?? false) Get.back(); // Cierra el diálogo
      Get.snackbar('Error', 'El UGV no respondió a tiempo.');
      // Opcional: podrías eliminar la sesión temporal de la BD aquí.
      _resetRecordingState();
    });

    subscription = bleController.newRouteIndicator.listen((indicator) async {
      if (indicator != null) {
        timeout?.cancel();
        subscription?.cancel();
        if (Get.isDialogOpen ?? false) Get.back(); // Cierra el diálogo

        _logger.i(
            "Confirmación recibida. Actualizando sesión ${_currentActiveSession.value!.id} con indicador $indicator");

        // 3. Actualiza la sesión en la BD con el indicador recibido.
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

  /// Resetea el estado de grabación de la UI.
  void _resetRecordingState() {
    _isRecordingRoute.value = false;
    _currentActiveSession.value = null;
  }

  //============================================================================
  // SECCIÓN: LÓGICA DEL PANEL DE CONFIGURACIÓN Y OTROS (SIN CAMBIOS)
  //============================================================================

  /// Envía un comando para establecer la velocidad del UGV.
  void _setSpeed(int speed) {
    if (bleController.ugvDeviceId != null) {
      bleController.sendData(bleController.ugvDeviceId!, 'SET_VEL:$speed');
    }
  }

  /// Envía un comando para establecer el tiempo de espera en los puntos de una ruta.
  void _setWaitTime(int milliseconds) {
    if (bleController.ugvDeviceId != null) {
      bleController.sendData(
          bleController.ugvDeviceId!, 'SET_WAIT:$milliseconds');
    }
  }

  /// Muestra un diálogo para la configuración manual de velocidad y tiempo de espera.
  Future<void> _showConfigDialog() async {
    final speedController = TextEditingController(
        text: bleController.currentSpeed.value.toString());
    final waitTimeController = TextEditingController();
    final selectedUnit =
        'Segundos'.obs; // Estado para el selector de unidad de tiempo

    // Pre-llena el campo de tiempo con el valor actual convertido a segundos.
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
            style: TextButton.styleFrom(
              backgroundColor: AppColors.secondary1,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.only(
                  top: 10, bottom: 10, left: 20, right: 20),
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Procesa y envía la velocidad.
              final speed = int.tryParse(speedController.text);
              if (speed != null && speed > 0) {
                _setSpeed(speed);
              }

              // Procesa, convierte a ms y envía el tiempo de espera.
              final waitTimeValue = int.tryParse(waitTimeController.text);
              if (waitTimeValue != null && waitTimeValue >= 0) {
                int milliseconds = waitTimeValue * 1000; // a ms
                if (selectedUnit.value == 'Minutos') {
                  milliseconds *= 60; // a ms
                }
                _setWaitTime(milliseconds);
              }
              Get.back();
              Get.snackbar('Configuración Enviada',
                  'Los nuevos valores han sido enviados al UGV.');
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.secondary1,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.only(
                  top: 10, bottom: 10, left: 20, right: 20),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo con los datos extraídos en una tabla bien formateada.
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

      if (cleanedValues.length == 6) {
        tableRows.add(DataRow(cells: [
          DataCell(Text(cleanedValues[0])),
          DataCell(Text(cleanedValues[1])),
          DataCell(Text(cleanedValues[2])),
          DataCell(Text(cleanedValues[3])),
          DataCell(Text(cleanedValues[4])),
          DataCell(Text(cleanedValues[5])),
        ]));
      } else if (cleanedValues.length == 4) {
        tableRows.add(DataRow(cells: [
          DataCell(const Text('-')),
          DataCell(const Text('-')),
          DataCell(Text(cleanedValues[0])),
          DataCell(Text(cleanedValues[1])),
          DataCell(Text(cleanedValues[2])),
          DataCell(Text(cleanedValues[3])),
        ]));
      } else {
        _logger.w("Línea de datos con formato incorrecto ignorada: '$line'");
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
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 15,
                headingRowColor:
                    WidgetStateProperty.all(AppColors.primary.withOpacity(0.1)),
                columns: const [
                  DataColumn(
                      label: Text('Ruta',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Punto',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('CO2\n(ppm)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                  DataColumn(
                      label: Text('CH4\n(ppm)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                  DataColumn(
                      label: Text('Temp\n(°C)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                  DataColumn(
                      label: Text('Hum\n(%)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
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

  /// Envía el comando 'X' y gestiona el proceso de extracción de datos.
  void _extractData() {
    if (bleController.ugvDeviceId == null) return;

    bleController.ugvDatabaseData.clear();
    bleController.extractionStatus.value = null;
    bleController.isExtractingData.value = true;

    bleController.sendData(
        bleController.ugvDeviceId!, BleController.extractData);

    Get.dialog(
      AlertDialog(
        title: const Text('Extrayendo Datos'),
        content: Column(mainAxisSize: MainAxisSize.min, children: const [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Recibiendo datos del UGV...'),
        ]),
      ),
      barrierDismissible: false,
    );

    Timer(const Duration(seconds: 5), () {
      if (bleController.isExtractingData.value) {
        bleController.isExtractingData.value = false;
        bleController.extractionStatus.value = 'error';
        if (Get.isDialogOpen ?? false) Get.back();
        Get.snackbar(
            'Error de Extracción', 'No se recibieron datos del UGV a tiempo.',
            backgroundColor: AppColors.error, colorText: Colors.white);
      }
    });

    once(bleController.extractionStatus, (status) {
      if (status != null) {
        if (Get.isDialogOpen ?? false) Get.back();

        if (status == 'completed') {
          _showExtractedDataDialog(
              List<String>.from(bleController.ugvDatabaseData));
        } else if (status == 'empty') {
          Get.dialog(AlertDialog(
            title: const Text('Información'),
            content: const Text('Base de datos del UGV vacia'),
            actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
          ));
        }
      }
    });
  }

  /// Navega a la pantalla de selección de rutas.
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

  /// Gestiona el botón de ejecutar/cancelar ruta.
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

  /// Envía el comando de interrupción/emergencia 'P'.
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

  /// Inicia el movimiento en una dirección.
  void _startMovement(String command) {
    if (bleController.ugvDeviceId != null && !_isAutoModeActive.value) {
      if (_lastSentDirectionalCommand != command) {
        _lastSentDirectionalCommand = command;
        bleController.sendData(bleController.ugvDeviceId!, command);
      }
    }
  }

  /// Envía el comando de detención 'S'.
  void _stopMovement() {
    if (bleController.ugvDeviceId != null && !_isAutoModeActive.value) {
      bleController.sendData(bleController.ugvDeviceId!, BleController.stop);
      _lastSentDirectionalCommand = BleController.stop;
    }
  }

  //============================================================================
  // SECCIÓN: CONSTRUCCIÓN DE LA INTERFAZ DE USUARIO (UI)
  //============================================================================
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
    } else if (batteryLevel > 15) {
      batteryIcon = Icons.battery_alert;
      iconColor = AppColors.error;
    } else {
      batteryIcon = Icons.battery_alert_sharp;
      iconColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(50),
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
                          backgroundColor: AppColors.accent,
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
                  if (!controlsEnabled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _isAutoModeActive.value
                            ? 'Controles deshabilitados en modo automático.'
                            : _isAwaitingEndOfRoute.value
                                ? 'Esperando finalización de ruta...'
                                : 'Conecte el UGV para activar los controles.',
                        style: TextStyle(
                            color: AppColors.backgroundBlack,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
