import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Importa tus colores personalizados
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart'; // Importa tu BleController
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Para los íconos de los botones de control
import 'package:logger/logger.dart'; // Importar la librería Logger
// Importar para firstWhereOrNull

// Importa los nuevos servicios de base de datos
import 'package:tanari_app/src/controllers/services/operation_data_service.dart';
import 'package:tanari_app/src/controllers/services/ugv_service.dart';

/// Pantalla principal para el control en Modo Acople (DP + UGV).
class ModoAcople extends StatefulWidget {
  const ModoAcople({super.key});

  @override
  State<ModoAcople> createState() => _ModoAcopleState();
}

class _ModoAcopleState extends State<ModoAcople> {
  // Obtenemos las instancias de los controladores y servicios
  final BleController bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final UgvService _ugvService = Get.find<UgvService>();
  final Logger _logger = Logger(); // Instancia del logger

  // Último comando de movimiento direccional enviado para evitar duplicados.
  String? _lastSentDirectionalCommand;

  // NUEVA VARIABLE DE ESTADO: Controla si estamos esperando la 'T' final para reactivar los controles manuales.
  // Esto previene que se puedan enviar comandos manuales inmediatamente después de detener el modo automático,
  // hasta que el UGV confirme la finalización del ciclo con 'T'.
  final RxBool _awaitingFinalTForManualControlsReactivation = false.obs;

  // Variable reactiva para la sesión de operación actualmente activa.
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);

  // Contador de secuencia para agrupar las lecturas de sensores que llegan al mismo tiempo.
  int _currentBatchSequence = 0;

  // Bandera para controlar la visibilidad del SnackBar de advertencia de conexión.
  bool _connectionSnackbarShown = false;

  @override
  void initState() {
    super.initState();
    // Establece el último comando direccional enviado como "detener" al inicio.
    _lastSentDirectionalCommand = BleController.stop;

    // Escucha los cambios en los dispositivos conectados para detectar desconexiones
    ever(bleController.connectedDevices, (devices) {
      // Si el UGV o el DP se desconectan mientras hay una sesión activa, finalizarla.
      if ((bleController.ugvDeviceId != null &&
              !bleController.isDeviceConnected(bleController.ugvDeviceId!)) ||
          (bleController.portableDeviceId != null &&
              !bleController
                  .isDeviceConnected(bleController.portableDeviceId!))) {
        if (_currentActiveSession.value != null) {
          _logger.w('Device disconnected, ending coupled operation session.');
          _endCoupledSession(); // Finaliza la sesión automáticamente
        }
        _connectionSnackbarShown =
            false; // Resetear para mostrar la advertencia de nuevo.
      } else {
        // Si todo está conectado (o se reconecta), resetear el flag del SnackBar
        _connectionSnackbarShown = false;
      }
    });

    // Escucha los datos recibidos del ESP32 a través del BleController
    // Esto es crucial para saber cuándo un ciclo automático ha terminado.
    ever(bleController.receivedData, (String? data) async {
      // Usamos 'data == BleController.endAutoMode' para la comparación
      // ya que receivedData puede ser null.
      if (data == BleController.endAutoMode) {
        // Se recibió 'T' del ESP32, indicando que el modo automático (o un ciclo) ha terminado.
        // Si el modo automático está activo en la aplicación (botón rojo),
        // reenviar 'A' para iniciar el siguiente ciclo.
        if (bleController.isAutomaticMode.value) {
          // Si estamos en modo automático y recibimos 'T', significa que un ciclo terminó,
          // y debemos re-enviar 'A' para el siguiente ciclo si el usuario no ha cancelado.
          _logger.i("Received 'T' from ESP32. Automatic mode cycle ended.");
          await Future.delayed(const Duration(
              milliseconds: 100)); // Pequeño retraso antes de reenviar
          _sendBleCommand(BleController.startAutoMode,
              isInternal: true); // Re-envía 'A' para el siguiente ciclo
        } else if (_awaitingFinalTForManualControlsReactivation.value) {
          // Si el modo automático NO está activo Y estábamos esperando la 'T' final,
          // entonces es el momento de reactivar los controles manuales.
          _awaitingFinalTForManualControlsReactivation.value =
              false; // Reactivar controles manuales
          Get.snackbar(
            "Modo Automático Finalizado",
            "Los controles manuales han sido reactivados.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.secondary, // Un color más suave
            colorText: AppColors.textPrimary,
            duration: const Duration(seconds: 3),
          );
        }
      }
    });

    // Escucha los cambios en portableData del BleController para guardar en Supabase.
    // Esto es donde los datos de los sensores son recibidos y procesados.
    bleController.portableData.listen((data) {
      if (mounted && _currentActiveSession.value != null) {
        _currentBatchSequence++; // Incrementa la secuencia de lote para este envío.

        final String sessionId = _currentActiveSession.value!.id;
        final double co2Value = double.tryParse(data['co2'] ?? '0.0') ?? 0.0;
        final double ch4Value = double.tryParse(data['ch4'] ?? '0.0') ?? 0.0;
        final double temperaturaValue =
            double.tryParse(data['temperature'] ?? '0.0') ?? 0.0;
        final double humedadValue =
            double.tryParse(data['humidity'] ?? '0.0') ?? 0.0;

        // Guardar cada lectura de sensor en la base de datos usando UgvService.
        _ugvService.createUgvTelemetry(
          sessionId: sessionId,
          commandType: 'SENSOR_READING',
          commandValue: 'CO2:$co2Value ppm',
          timestamp: DateTime.now(),
          status: 'recibido',
          notes: 'Lectura de sensor CO2 (Batch: $_currentBatchSequence)',
        );
        _ugvService.createUgvTelemetry(
          sessionId: sessionId,
          commandType: 'SENSOR_READING',
          commandValue: 'CH4:$ch4Value ppm',
          timestamp: DateTime.now(),
          status: 'recibido',
          notes: 'Lectura de sensor CH4 (Batch: $_currentBatchSequence)',
        );
        _ugvService.createUgvTelemetry(
          sessionId: sessionId,
          commandType: 'SENSOR_READING',
          commandValue: 'Temperatura:$temperaturaValue ºC',
          timestamp: DateTime.now(),
          status: 'recibido',
          notes:
              'Lectura de sensor Temperatura (Batch: $_currentBatchSequence)',
        );
        _ugvService.createUgvTelemetry(
          sessionId: sessionId,
          commandType: 'SENSOR_READING',
          commandValue: 'Humedad:$humedadValue %',
          timestamp: DateTime.now(),
          status: 'recibido',
          notes: 'Lectura de sensor Humedad (Batch: $_currentBatchSequence)',
        );
      }
    });
  }

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE SESIÓN Y COMUNICACIÓN BLE
  //----------------------------------------------------------------------------

  /// Inicia una nueva sesión de operación en modo 'coupled'.
  Future<void> _startCoupledSession() async {
    // Verificar que ambos dispositivos (DP y UGV) estén conectados
    if (!bleController.isPortableConnected.value ||
        !bleController.isUgvConnected.value) {
      _showConnectionWarningSnackbar(
          'Ambos dispositivos (DP y UGV) deben estar conectados para iniciar el modo acoplado.');
      return;
    }

    String? operationName;
    int? routeNumber;

    await Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.backgroundWhite,
        title: Text('Iniciar Operación Acoplado',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Nombre de la Operación (Ej. Ruta Estacionamiento)',
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
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Número de Ruta (Opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.neutralLight)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: (value) => routeNumber = int.tryParse(value),
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
                Get.back(); // Cierra el diálogo
              } else {
                Get.snackbar(
                    'Error', 'El nombre de la operación es obligatorio',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.error,
                    colorText: AppColors.backgroundWhite);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Iniciar',
                style: TextStyle(color: AppColors.backgroundWhite)),
          ),
        ],
      ),
    );

    if (operationName == null || operationName!.isEmpty) {
      _logger.w('Operation initiation cancelled by user or invalid name.');
      return;
    }

    _logger.i('Attempting to start Coupled operation session: $operationName');
    final OperationSession? session =
        await _operationDataService.createOperationSession(
      operationName: operationName,
      description: 'Sesión de operación en modo acoplado (DP + UGV).',
      mode: 'coupled', // Establece el modo de operación
      routeNumber: routeNumber,
    );

    if (session != null) {
      _currentActiveSession.value = session;
      _currentBatchSequence =
          0; // Reinicia la secuencia de lote para la nueva sesión.
      // Puedes reiniciar el mapa del UGV si tienes uno aquí también
      // _resetRecorrido();
      _logger.i('Coupled Operation Session started: ${session.id}');
    } else {
      _logger.e('Failed to start Coupled Operation Session.');
    }
  }

  /// Finaliza la sesión de operación acoplada actualmente activa.
  Future<void> _endCoupledSession() async {
    if (_currentActiveSession.value == null) {
      Get.snackbar('Advertencia',
          'No hay una sesión de operación acoplada activa para detener.');
      return;
    }
    _logger.i(
        'Attempting to end Coupled operation session: ${_currentActiveSession.value!.id}');

    final bool success = await _operationDataService.endOperationSession(
      _currentActiveSession.value!.id,
    );
    if (success) {
      _currentActiveSession.value = null; // Limpia la sesión activa
      _logger.i('Coupled Operation Session ended.');
    } else {
      _logger.e('Failed to end Coupled Operation Session.');
    }
  }

  /// Inicia el movimiento del UGV en una dirección específica.
  void _startMovement(String command) {
    if (_currentActiveSession.value == null) {
      _showSessionRequiredSnackbar();
      return;
    }
    if (bleController.isUgvConnected.value &&
        !bleController.isAutomaticMode.value &&
        !_awaitingFinalTForManualControlsReactivation.value) {
      if (_lastSentDirectionalCommand != command) {
        _lastSentDirectionalCommand = command;
        _sendBleCommand(command);
      }
    } else {
      _showControlDisabledSnackbar();
    }
  }

  /// Detiene el movimiento del UGV.
  void _stopMovement() {
    if (_currentActiveSession.value == null) {
      _showSessionRequiredSnackbar();
      return;
    }
    if (bleController.isUgvConnected.value &&
        !bleController.isAutomaticMode.value &&
        !_awaitingFinalTForManualControlsReactivation.value) {
      _sendBleCommand(BleController.stop);
      _lastSentDirectionalCommand = BleController.stop;
    } else {
      _showControlDisabledSnackbar();
    }
  }

  /// Interrumpe el movimiento actual del UGV (tanto manual como automático).
  void _interruptMovement() {
    if (_currentActiveSession.value == null) {
      _showSessionRequiredSnackbar();
      return;
    }
    if (bleController.isUgvConnected.value) {
      _sendBleCommand(BleController.interruption);
      _lastSentDirectionalCommand = BleController.interruption;
      bleController.isAutomaticMode.value =
          false; // Desactiva el modo automático en la app
      _awaitingFinalTForManualControlsReactivation.value =
          false; // Asegura que los controles se reactiven
      Get.snackbar(
        "Interrupción",
        "El UGV ha sido detenido. Modo automático desactivado.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.backgroundWhite,
        duration: const Duration(seconds: 3),
      );
    } else {
      _showConnectionWarningSnackbar('No hay UGV conectado para interrumpir.');
    }
  }

  /// Envía un comando BLE al dispositivo UGV y registra en la base de datos.
  void _sendBleCommand(String commandToSend, {bool isInternal = false}) {
    if (bleController.ugvDeviceId != null &&
        bleController.isDeviceConnected(bleController.ugvDeviceId!)) {
      if (_currentActiveSession.value == null) {
        if (!isInternal) {
          _showSessionRequiredSnackbar();
        }
        return;
      }

      _logger.d(
          "Attempting to send BLE command: $commandToSend to UGV ID: ${bleController.ugvDeviceId}");
      bleController.sendData(bleController.ugvDeviceId!, commandToSend);

      // Registrar el comando en la base de datos
      _ugvService.createUgvTelemetry(
        sessionId: _currentActiveSession.value!.id,
        commandType: _getCommandType(commandToSend),
        commandValue: commandToSend,
        status: 'enviado',
        ugvId: bleController.ugvDeviceId,
        notes: 'Comando enviado desde la app (Modo Acoplado).',
        latitude: null, // Asume null por ahora, el hardware enviaría esto
        longitude: null, // Asume null por ahora, el hardware enviaría esto
        timestamp: DateTime.now(), // Agrega el timestamp requerido
      );
    } else {
      if (!isInternal) {
        _showConnectionWarningSnackbar(
            'No hay UGV conectado para enviar comandos.');
      }
    }
  }

  /// Mapea el comando BLE a un tipo de comando más descriptivo para la BD.
  String _getCommandType(String command) {
    switch (command) {
      case BleController.moveForward:
        return 'MOVER_ADELANTE';
      case BleController.moveBack:
        return 'MOVER_ATRAS';
      case BleController.moveLeft:
        return 'GIRAR_IZQUIERDA';
      case BleController.moveRight:
        return 'GIRAR_DERECHA';
      case BleController.stop:
        return 'DETENER';
      case BleController.interruption:
        return 'INTERRUPCION_MANUAL';
      case BleController.startRecording:
        return 'INICIAR_GRABACION';
      case BleController.stopRecording:
        return 'DETENER_GRABACION';
      case BleController.startAutoMode:
        return 'INICIAR_MODO_AUTOMATICO';
      case BleController.endAutoMode:
        return 'FINALIZAR_MODO_AUTOMATICO';
      default:
        return 'COMANDO_DESCONOCIDO';
    }
  }

  /// Muestra un SnackBar de advertencia si no hay un dispositivo conectado.
  void _showConnectionWarningSnackbar(String message) {
    if (!_connectionSnackbarShown) {
      Get.snackbar("Advertencia", message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite,
          duration: const Duration(seconds: 3));
      _connectionSnackbarShown = true;
    }
  }

  /// Muestra un SnackBar si se requiere iniciar una sesión.
  void _showSessionRequiredSnackbar() {
    Get.snackbar("Sesión Requerida",
        "Por favor, inicie una operación en modo acoplado antes de continuar.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning,
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 3));
  }

  /// Muestra un SnackBar si los controles están deshabilitados (ej. modo automático activo).
  void _showControlDisabledSnackbar() {
    Get.snackbar("Controles Deshabilitados",
        "Los controles manuales están deshabilitados en modo automático o mientras se espera confirmación del UGV.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.info, // Un color informativo
        colorText: AppColors.backgroundBlack,
        duration: const Duration(seconds: 3));
  }

  /// Alterna el estado del modo automático del UGV.
  void _toggleAutomaticMode() {
    if (_currentActiveSession.value == null) {
      _showSessionRequiredSnackbar();
      return;
    }
    if (bleController.ugvDeviceId != null &&
        bleController.isDeviceConnected(bleController.ugvDeviceId!)) {
      if (bleController.isAutomaticMode.value) {
        // Si el modo automático está activo, lo desactivamos y enviamos comando de finalización
        _logger.i("Disabling automatic mode from App.");
        _sendBleCommand(BleController
            .endAutoMode); // Envía 'T' para detener el ciclo actual
        bleController.isAutomaticMode.value = false;
        _awaitingFinalTForManualControlsReactivation.value =
            true; // Esperar 'T' del UGV
        Get.snackbar(
          "Modo Automático",
          "Solicitando finalización del modo automático. Esperando confirmación del UGV...",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 4),
        );
      } else {
        // Si el modo automático está inactivo, lo activamos y enviamos comando de inicio
        _logger.i("Enabling automatic mode from App.");
        _sendBleCommand(BleController.startAutoMode);
        bleController.isAutomaticMode.value = true;
        _awaitingFinalTForManualControlsReactivation.value =
            false; // No estamos esperando 'T'
        Get.snackbar(
          "Modo Automático",
          "Modo automático iniciado.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.accentColor, // Color verde vibrante
          colorText: AppColors.backgroundWhite,
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      _showConnectionWarningSnackbar(
          'No hay UGV conectado para activar/desactivar el modo automático.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary, // Fondo consistente
      appBar: AppBar(
        title: Text(
          'Modo de Acople',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.backgroundWhite,
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.accent, // Usar el color principal del AppBar
        foregroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador de estado de conexión del Tanari DP y UGV
              Obx(() => _buildConnectionStatus(
                  Theme.of(context),
                  bleController.isPortableConnected.value,
                  BleController.deviceNameDP)),
              const SizedBox(height: 10),
              Obx(() => _buildConnectionStatus(
                  Theme.of(context),
                  bleController.isUgvConnected.value,
                  BleController.deviceNameUGV)),
              const SizedBox(height: 20),

              // Indicador de estado de la sesión de operación acoplada
              Obx(() {
                final bool isActive = _currentActiveSession.value != null;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accentColor.withOpacity(0.15)
                        : AppColors.secondary1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? AppColors.accentColor
                          : AppColors.secondary1,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? Icons.link : Icons.link_off,
                        color: isActive
                            ? AppColors.accentColor
                            : AppColors.secondary1,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        // Usar Flexible para evitar desbordamiento de texto
                        child: Text(
                          isActive
                              ? 'Operación Acoplada: ${_currentActiveSession.value?.operationName ?? 'Activa'}'
                              : 'Operación Acoplada Inactiva',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: isActive
                                        ? AppColors.accentColor
                                        : AppColors.secondary1,
                                    fontWeight: FontWeight.bold,
                                  ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Botones de Iniciar/Detener Operación Acoplado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                          onPressed: _currentActiveSession.value == null
                              ? _startCoupledSession
                              : null,
                          icon: const Icon(Icons.play_circle_fill),
                          label: const Text('Iniciar Acople'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.accentColor, // Verde vibrante
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
                              ? _endCoupledSession
                              : null,
                          icon: const Icon(Icons.stop_circle),
                          label: const Text('Detener Acople'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.error, // Rojo para detener
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
              const SizedBox(height: 20),

              // Sección de Monitoreo del DP
              _buildMonitoringPanel(),
              const SizedBox(height: 20),
              // Sección de Control del UGV
              _buildUgvControlPanel(),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el widget para mostrar el estado de la conexión BLE de un dispositivo.
  Widget _buildConnectionStatus(
      ThemeData theme, bool isConnected, String deviceName) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.accentColor.withOpacity(0.15)
            : AppColors.error.withOpacity(0.15),
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
          Text(
            isConnected
                ? '$deviceName: Conectado'
                : '$deviceName: Desconectado',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isConnected ? AppColors.accentColor : AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el panel de monitoreo (datos del Tanari DP).
  Widget _buildMonitoringPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight, // Usa el color claro para el panel
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.backgroundBlack
                .withAlpha((255 * 0.1).round()), // Usa .withAlpha()
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monitoreo del Tanari DP:',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const Divider(height: 20, color: AppColors.neutral),
          Obx(() => _buildDataRow('CO2:',
              '${bleController.portableData['co2'] ?? '--'} ppm', Icons.cloud)),
          Obx(() => _buildDataRow(
              'CH4:',
              '${bleController.portableData['ch4'] ?? '--'} ppm',
              Icons.local_gas_station)),
          Obx(() => _buildDataRow(
              'Temperatura:',
              '${bleController.portableData['temperature'] ?? '--'} °C',
              Icons.thermostat)),
          Obx(() => _buildDataRow(
              'Humedad:',
              '${bleController.portableData['humidity'] ?? '--'} %',
              Icons.water_drop)),
        ],
      ),
    );
  }

  /// Construye una fila para mostrar un dato específico.
  Widget _buildDataRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.accent, // Usar color de énfasis para los valores
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el panel de control del UGV.
  Widget _buildUgvControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight, // Usa el color claro para el panel
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.backgroundBlack
                .withAlpha((255 * 0.1).round()), // Usa .withAlpha()
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Control del Tanari UGV:',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const Divider(height: 20, color: AppColors.neutral),
          const SizedBox(height: 10),
          _buildActionButtons(context), // Botones de Auto y Stop (Interrupción)
          const SizedBox(height: 20),
          _buildDirectionalControls(context), // Botones direccionales
        ],
      ),
    );
  }

  /// Construye los botones de acción (Auto e Interrumpir).
  Widget _buildActionButtons(BuildContext context) {
    // Determine if action buttons should be enabled
    final bool areActionButtonsEnabled = _currentActiveSession.value != null &&
        bleController.isUgvConnected.value &&
        !_awaitingFinalTForManualControlsReactivation.value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón "Auto"
        Obx(
          () => _buildActionButton(
            text: 'Auto',
            icon: FontAwesomeIcons.robot,
            onPressed: areActionButtonsEnabled ? _toggleAutomaticMode : null,
            isActive: bleController.isAutomaticMode.value,
          ),
        ),
        const SizedBox(width: 20),
        // Botón "Interrumpir"
        Obx(() => _buildActionButton(
              text: 'Interrumpir',
              icon: FontAwesomeIcons.stop,
              onPressed: _currentActiveSession.value != null &&
                      bleController.isUgvConnected.value
                  ? _interruptMovement
                  : null,
              isPrimaryColor: false, // Para que sea rojo
            )),
      ],
    );
  }

  /// Widget genérico para un botón de acción compacto.
  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Function()? onPressed,
    bool isActive = false,
    bool isPrimaryColor =
        true, // true para color primario/accent, false para rojo (interrumpir)
  }) {
    Color buttonColor;
    Color fgColor =
        AppColors.backgroundWhite; // Color de texto blanco por defecto

    if (onPressed == null) {
      buttonColor = AppColors.neutral; // Gris si está deshabilitado
    } else {
      if (isPrimaryColor) {
        buttonColor = isActive
            ? AppColors.accent
            : AppColors
                .primary; // Azul profundo para activo, Verde lima para inactivo
      } else {
        buttonColor = AppColors.error; // Rojo para Interrumpir
      }
    }

    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 5,
          shadowColor: buttonColor.withOpacity(0.5),
        ),
        icon: FaIcon(icon, size: 20, color: fgColor),
        label: Text(
          text,
          style:
              const TextStyle(fontSize: 14, color: AppColors.backgroundWhite),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Construye los controles direccionales para el UGV.
  Widget _buildDirectionalControls(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonSize = constraints.maxWidth * 0.22;

        return Obx(() {
          // Los botones de movimiento solo se habilitan si:
          // - Hay una sesión acoplada activa
          // - El UGV está conectado
          // - NO está en modo automático
          // - NO estamos esperando la 'T' final del UGV.
          final bool areMovementButtonsEnabled =
              _currentActiveSession.value != null &&
                  bleController.isUgvConnected.value &&
                  !bleController.isAutomaticMode.value &&
                  !_awaitingFinalTForManualControlsReactivation.value;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDirectionButton(
                icon: Icons.arrow_upward,
                command: BleController.moveForward,
                size: buttonSize,
                isEnabled: areMovementButtonsEnabled,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDirectionButton(
                    icon: Icons.arrow_back,
                    command: BleController.moveLeft,
                    size: buttonSize,
                    isEnabled: areMovementButtonsEnabled,
                  ),
                  SizedBox(
                      width: constraints.maxWidth *
                          0.25), // Espacio entre Left y Right
                  _buildDirectionButton(
                    icon: Icons.arrow_forward,
                    command: BleController.moveRight,
                    size: buttonSize,
                    isEnabled: areMovementButtonsEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDirectionButton(
                icon: Icons.arrow_downward,
                command: BleController.moveBack,
                size: buttonSize,
                isEnabled: areMovementButtonsEnabled,
              ),
            ],
          );
        });
      },
    );
  }

  /// Widget genérico para un botón direccional del UGV.
  Widget _buildDirectionButton({
    required IconData icon,
    required String command,
    required double size,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTapDown: isEnabled ? (_) => _startMovement(command) : null,
      onTapUp: isEnabled ? (_) => _stopMovement() : null,
      onTapCancel: isEnabled ? () => _stopMovement() : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.primaryDark
              : AppColors.neutral, // Azul si está habilitado, gris si no
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.backgroundBlack.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.backgroundWhite, size: size * 0.5),
      ),
    );
  }
}
