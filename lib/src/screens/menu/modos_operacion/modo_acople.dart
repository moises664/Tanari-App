import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';
import 'package:tanari_app/src/screens/menu/modos_historial/ugv_routes_screen.dart';

//==============================================================================
// PANTALLA DE MODO ACOPLE
//==============================================================================
/// Pantalla principal para el control y monitoreo en Modo Acople (DP + UGV).
///
/// Esta pantalla unifica las funcionalidades clave del Modo DP (monitoreo de sensores)
/// y Modo UGV (control manual y autónomo). La interfaz se activa únicamente
/// cuando el sistema detecta un acople físico entre ambos dispositivos,
/// permitiendo la grabación de datos de sensores georreferenciados durante
/// la operación del UGV.
class ModoAcople extends StatefulWidget {
  const ModoAcople({super.key});

  @override
  State<ModoAcople> createState() => _ModoAcopleState();
}

class _ModoAcopleState extends State<ModoAcople> {
  //----------------------------------------------------------------------------
  // SECCIÓN: INYECCIÓN DE DEPENDENCIAS Y LOGGING
  //----------------------------------------------------------------------------
  final BleController bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final Logger _logger = Logger();

  //----------------------------------------------------------------------------
  // SECCIÓN: VARIABLES DE ESTADO DE LA PANTALLA
  //----------------------------------------------------------------------------

  /// Almacena el último comando direccional enviado para evitar el envío redundante de datos.
  String? _lastSentDirectionalCommand;

  /// Sesión de operación activa en la base de datos. Es `null` si no hay grabación activa.
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);

  /// Almacena la ruta que el usuario ha seleccionado para su posterior ejecución autónoma.
  final Rx<OperationSession?> _selectedRoute = Rx<OperationSession?>(null);

  /// Estado reactivo que indica si el UGV está en modo de ejecución automática.
  final RxBool _isAutoModeActive = false.obs;

  /// Estado reactivo que indica si se ha cancelado una ruta y se está esperando
  /// que el UGV termine su recorrido de vuelta al punto de inicio.
  final RxBool _isAwaitingEndOfRoute = false.obs;

  //----------------------------------------------------------------------------
  // SECCIÓN: MÉTODOS DEL CICLO DE VIDA (Lifecycle Methods)
  //----------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _lastSentDirectionalCommand = BleController.stop;

    // Listener reactivo que se dispara si el UGV o el DP se desconectan.
    everAll([bleController.isUgvConnected, bleController.isPortableConnected],
        (_) {
      // Si alguno de los dos se desconecta, reseteamos la UI del modo acople.
      if ((!bleController.isUgvConnected.value ||
              !bleController.isPortableConnected.value) &&
          mounted) {
        _logger.w(
            "Un dispositivo se ha desconectado. Reseteando estados de Acople.");
        // Si había una sesión de grabación activa, se finaliza para no dejarla abierta.
        if (_currentActiveSession.value != null) {
          _operationDataService
              .endOperationSession(_currentActiveSession.value!.id);
        }
        // Resetea todos los estados de la UI a sus valores iniciales.
        _currentActiveSession.value = null;
        _isAutoModeActive.value = false;
        _selectedRoute.value = null;
        _isAwaitingEndOfRoute.value = false;
      }
    });

    // Listener que reacciona a los datos de estado recibidos del UGV.
    ever(bleController.receivedData, (String? data) {
      // Si el UGV envía 'T', significa que la ruta automática ha terminado.
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

  //============================================================================
  // SECCIÓN: LÓGICA DE SESIÓN Y GRABACIÓN (CON CORRECCIÓN)
  //============================================================================

  /// Inicia una nueva sesión de operación en modo 'coupled'. (VERSIÓN CORREGIDA)
  ///
  /// Muestra un diálogo para que el usuario ingrese un nombre para el registro.
  /// Utiliza un patrón robusto que espera un resultado del diálogo para evitar
  /// problemas de estado, garantizando que la sesión solo se cree si el usuario
  /// confirma con un nombre válido.
  Future<void> _startSensorRecording() async {
    // 1. Verificación de Precondiciones (ambos dispositivos conectados)
    if (!bleController.isPortableConnected.value ||
        !bleController.isUgvConnected.value) {
      Get.snackbar('Dispositivos no conectados',
          'Ambos dispositivos (DP y UGV) deben estar conectados.');
      return;
    }

    // Se utilizará una variable local al diálogo para mayor seguridad de estado.
    String localOperationName = '';

    // 2. Esperamos a que el diálogo devuelva un resultado booleano.
    final bool? shouldCreate = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Crear Nuevo Registro de Acople'),
        content: TextField(
          autofocus: true, // Mejora la experiencia de usuario
          decoration: const InputDecoration(
              labelText: 'Nombre del Registro (Obligatorio)'),
          // El onChanged actualiza la variable local del diálogo.
          onChanged: (value) => localOperationName = value,
        ),
        actions: [
          TextButton(
            // Al cancelar, devolvemos 'false'.
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (localOperationName.trim().isNotEmpty) {
                // Al confirmar, devolvemos 'true'.
                Get.back(result: true);
              } else {
                Get.snackbar('Error', 'El nombre del registro es obligatorio.');
              }
            },
            child: const Text('Crear y Grabar'),
          ),
        ],
      ),
    );

    // 3. Verificamos el resultado del diálogo.
    // Si shouldCreate no es 'true', significa que el usuario canceló o cerró el diálogo.
    if (shouldCreate != true) {
      _logger.i("Creación de registro cancelada por el usuario.");
      return;
    }

    // 4. Creación de la Sesión
    // Si llegamos aquí, es seguro que tenemos un nombre válido.
    final session = await _operationDataService.createOperationSession(
      operationName: localOperationName.trim(), // Usamos el valor capturado
      description: 'Sesión de operación en modo acoplado (DP + UGV).',
      mode: 'coupled',
    );

    if (session != null) {
      _currentActiveSession.value = session;
      Get.snackbar('Monitoreo Iniciado',
          'Sesión "${session.operationName}" iniciada con éxito.');
    }
  }

  /// Finaliza la sesión de operación acoplada actualmente activa.
  Future<void> _stopSensorRecording() async {
    if (_currentActiveSession.value == null) return;
    final success = await _operationDataService
        .endOperationSession(_currentActiveSession.value!.id);
    if (success) {
      _currentActiveSession.value = null;
      Get.snackbar('Monitoreo Detenido', 'Sesión finalizada con éxito.');
    }
  }

  //============================================================================
  // SECCIÓN: LÓGICA DE EJECUCIÓN AUTOMÁTICA
  //============================================================================

  /// Abre la pantalla de selección de rutas para que el usuario elija una para ejecutar.
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

  /// Gestiona el botón principal de ejecución/cancelación de ruta automática.
  void _handleAutoButton() {
    if (bleController.ugvDeviceId == null) return;

    if (_isAutoModeActive.value) {
      // Si la ruta está activa, envía el comando de cancelación ('N').
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.cancelAuto);
      _isAwaitingEndOfRoute.value = true;
      Get.snackbar('Cancelando Ruta', 'El UGV regresará al punto de inicio.');
    } else if (_selectedRoute.value != null) {
      // Si hay una ruta seleccionada, envía su indicador para iniciarla.
      bleController.sendData(
          bleController.ugvDeviceId!, _selectedRoute.value!.indicator!);
      _isAutoModeActive.value = true;
      _isAwaitingEndOfRoute.value = false;
      Get.snackbar('Iniciando Ruta',
          'Ejecutando "${_selectedRoute.value!.operationName}".');
    }
  }

  //============================================================================
  // SECCIÓN: LÓGICA DE CONTROL MANUAL Y EMERGENCIA
  //============================================================================

  /// Envía el comando de interrupción/emergencia ('P') para detener todo movimiento.
  void _interruptMovement() {
    if (bleController.ugvDeviceId != null) {
      bleController.sendData(
          bleController.ugvDeviceId!, BleController.interruption);
      // Resetea todos los estados de modo automático.
      if (_isAutoModeActive.value) _isAutoModeActive.value = false;
      if (_isAwaitingEndOfRoute.value) _isAwaitingEndOfRoute.value = false;
      if (_selectedRoute.value != null) _selectedRoute.value = null;
      Get.snackbar('Interrupción de Emergencia', 'Movimiento detenido.');
    }
  }

  /// Inicia el movimiento en una dirección (usado por los botones direccionales).
  void _startMovement(String command) {
    if (bleController.ugvDeviceId != null && !_isAutoModeActive.value) {
      if (_lastSentDirectionalCommand != command) {
        _lastSentDirectionalCommand = command;
        bleController.sendData(bleController.ugvDeviceId!, command);
      }
    }
  }

  /// Envía el comando de detención ('S') al levantar un botón direccional.
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
        title: Text('Modo Acoplado',
            style: TextStyle(
                color: AppColors.backgroundWhite, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Obx(() {
          // La variable principal que controla si la UI está activa.
          final bool isCoupledAndReady =
              bleController.isPhysicallyCoupled.value;

          // Opacity y AbsorbPointer envuelven toda la UI.
          // Si no está acoplado, la UI se ve semitransparente y no es interactiva.
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
                  _buildSensorRecordingPanel(),
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

  /// Construye el panel superior con los indicadores de estado de ambos dispositivos.
  Widget _buildStatusIndicatorsPanel(ThemeData theme) {
    return Column(
      children: [
        // Fila para el Tanari DP
        Row(children: [
          Expanded(
              child: Obx(() => _buildConnectionStatus(theme,
                  bleController.isPortableConnected.value, "Tanari DP"))),
          const SizedBox(width: 15),
          Expanded(child: Obx(() => _buildBatteryStatus(theme, isDP: true))),
        ]),
        const SizedBox(height: 10),
        // Fila para el Tanari UGV
        Row(children: [
          Expanded(
              child: Obx(() => _buildConnectionStatus(
                  theme, bleController.isUgvConnected.value, "Tanari UGV"))),
          const SizedBox(width: 15),
          Expanded(child: Obx(() => _buildBatteryStatus(theme, isDP: false))),
        ]),
      ],
    );
  }

  /// Construye el indicador visual del estado de acople físico del sistema.
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
          Text(
            isCoupled ? 'Sistema Acoplado' : 'Sistema Desacoplado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isCoupled ? AppColors.accentColor : AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  /// Construye el panel para iniciar y detener la grabación de datos de sensores.
  Widget _buildSensorRecordingPanel() {
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
          Obx(() => Text(
                _currentActiveSession.value != null
                    ? 'Grabando sesión: "${_currentActiveSession.value!.operationName}"'
                    : 'No hay grabación activa.',
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
                      // El botón se deshabilita si ya hay una sesión activa.
                      onPressed: _currentActiveSession.value == null
                          ? _startSensorRecording
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text(
                        'Crear Registro',
                        style: TextStyle(color: AppColors.backgroundWhite),
                      ),
                      style: ElevatedButton.styleFrom(
                          iconColor: AppColors.backgroundWhite,
                          backgroundColor: AppColors.accent),
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Obx(() => ElevatedButton.icon(
                      // El botón se habilita solo si hay una sesión activa.
                      onPressed: _currentActiveSession.value != null
                          ? _stopSensorRecording
                          : null,
                      icon: const Icon(Icons.stop_circle),
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

  /// Construye el panel que muestra los datos de los sensores del DP en tiempo real.
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
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monitoreo Tanari DP',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          // Las filas de datos se actualizan automáticamente gracias a Obx.
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

  /// Construye el panel para la selección y ejecución de rutas automáticas.
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
                onPressed: _showUgvRoutesScreen,
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
                  // El botón se habilita si hay una ruta lista o si una está en ejecución.
                  onPressed: (isReadyToExecute || _isAutoModeActive.value)
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

  /// Construye el panel para el control manual del UGV.
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
        ],
      ),
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
                  padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ),
          const SizedBox(height: 20),
          Obx(() {
            // Los controles direccionales se deshabilitan en modo automático.
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

  //============================================================================
  // SECCIÓN: WIDGETS AUXILIARES REUTILIZABLES DE UI
  //============================================================================

  /// Construye una fila estandarizada para mostrar un dato de sensor.
  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Construye un widget para mostrar el estado de conexión BLE.
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

  /// Construye un widget para mostrar el estado de la batería (para DP o UGV).
  Widget _buildBatteryStatus(ThemeData theme, {required bool isDP}) {
    // Determina qué valor de batería y estado de conexión usar.
    final int batteryLevel = isDP
        ? bleController.portableBatteryLevel.value
        : bleController.batteryLevel.value;
    final bool isConnected = isDP
        ? bleController.isPortableConnected.value
        : bleController.isUgvConnected.value;

    IconData batteryIcon;
    Color iconColor;

    // Lógica para seleccionar el ícono y color según el nivel de batería.
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
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: iconColor, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un botón circular para el control de dirección manual.
  Widget _buildDirectionButton(IconData icon, String command, bool isEnabled) {
    return GestureDetector(
      // Detecta cuándo se presiona y se suelta el botón.
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
