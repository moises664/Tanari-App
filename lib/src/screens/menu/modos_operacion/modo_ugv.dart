import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:logger/logger.dart'; // Importar la librería Logger
import 'package:collection/collection.dart'; // Importar para firstWhereOrNull

/// Pantalla principal para el control manual y automático del UGV.
class ModoUgv extends StatefulWidget {
  const ModoUgv({super.key});

  @override
  State<ModoUgv> createState() => _ModoUgvState();
}

/// Estado que gestiona la lógica de control y visualización del UGV.
class _ModoUgvState extends State<ModoUgv> {
  //----------------------------------------------------------------------------
  // VARIABLES DE ESTADO Y CONTROL
  //----------------------------------------------------------------------------

  final BleController bleController = Get.find<BleController>();
  final Logger _logger = Logger(); // Instancia del logger

  // Puntos del recorrido para dibujar en el mapa.
  List<Offset> recorridoPoints = [const Offset(0, 0)];
  // Posición actual del UGV en el mapa.
  Offset currentPosition = const Offset(0, 0);
  // Tamaño del paso para el movimiento simulado en el mapa.
  double stepSize = 20.0;

  // ID del dispositivo UGV conectado (puede ser nulo si no hay conexión).
  String? ugvDeviceId;
  // Último comando de movimiento direccional enviado para evitar duplicados.
  String? _lastSentDirectionalCommand;

  // Estado reactivo para el botón de grabación.
  final RxBool _isRecording = false.obs;

  // Bandera para controlar la visibilidad del SnackBar de advertencia de conexión.
  bool _connectionSnackbarShown = false;

  // NUEVA VARIABLE DE ESTADO: Controla si estamos esperando la 'T' final para reactivar los controles manuales.
  final RxBool _awaitingFinalTForManualControlsReactivation = false.obs;

  //----------------------------------------------------------------------------
  // MÉTODOS DEL CICLO DE VIDA DEL WIDGET
  //----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Inicializa el ID del UGV si ya hay uno conectado.
    _initUgvDeviceId();
    // Vincula el estado de grabación del BleController con el estado local.
    _bindRecordingState();
    // Establece el último comando direccional enviado como "detener" al inicio.
    _lastSentDirectionalCommand = BleController.stop;

    // Escucha los cambios en los dispositivos conectados del BleController.
    // Esto se usa para resetear el flag del SnackBar y mostrar mensajes de conexión/desconexión.
    ever(bleController.connectedDevices, (devices) {
      // Verificar si hay un UGV específico conectado.
      if (ugvDeviceId != null &&
          bleController.isDeviceConnected(ugvDeviceId!)) {
        // Si el SnackBar de advertencia se había mostrado previamente y ahora hay conexión,
        // resetear el flag y mostrar un SnackBar de conexión restaurada.
        if (_connectionSnackbarShown) {
          _connectionSnackbarShown =
              false; // Permite que el SnackBar se muestre de nuevo si se desconecta
          Get.snackbar(
              "Conexión Restaurada", "El UGV está nuevamente conectado.",
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 2));
        }
      } else {
        // Si no hay UGV conectado (o se desconectó), asegurar que el SnackBar de advertencia pueda aparecer.
        // No mostrar un SnackBar aquí, solo resetear el flag.
        _connectionSnackbarShown = false;
        // Cuando se desconecta el UGV, también se deberían resetear los estados
        bleController.isAutomaticMode.value =
            false; // Desactivar modo automático al desconectar
        _isRecording.value = false; // Desactivar grabación al desconectar
        _awaitingFinalTForManualControlsReactivation.value =
            false; // Resetear también esta bandera
      }
    });

    // --- LÓGICA MODIFICADA PARA DATOS RECIBIDOS DEL ESP32 ---
    // Escucha los datos recibidos del ESP32 a través del BleController
    ever(bleController.receivedData, (String? data) async {
      // Asegura que 'data' es String?
      if (data == BleController.endAutoMode) {
        // Usamos endAutoMode que es 'T'
        // Se recibió 'T' del ESP32, indicando que el modo automático ha terminado.
        _logger.i("Received 'T' from ESP32. Automatic mode cycle ended.");

        // Si el modo automático está activo en la aplicación (botón rojo),
        // reenviar 'A' para iniciar el siguiente ciclo.
        if (bleController.isAutomaticMode.value) {
          _logger.i(
              "Automatic mode is active. Sending 'A' again after a short delay.");
          await Future.delayed(
              const Duration(milliseconds: 100)); // Pequeño retraso
          _sendBleCommand(BleController
              .startAutoMode); // Re-envía 'A' para el siguiente ciclo
        } else if (_awaitingFinalTForManualControlsReactivation.value) {
          // Si el modo automático NO está activo Y estábamos esperando la 'T' final,
          // entonces es el momento de reactivar los controles manuales.
          _logger.i(
              "Automatic mode was manually disabled and final 'T' received. Re-enabling manual controls.");
          _awaitingFinalTForManualControlsReactivation.value =
              false; // Reactivar controles manuales
        } else {
          _logger.i(
              "Automatic mode is not active and not awaiting final 'T'. Not re-sending 'A'.");
        }
      }
    });
  }

  /// Vincula el estado `isRecording` del `BleController` con el `RxBool` local.
  void _bindRecordingState() {
    ever(bleController.isRecording, (recording) {
      _isRecording.value = recording;
    });
  }

  /// Inicializa `ugvDeviceId` si el UGV ya está conectado al inicio o se conecta después.
  void _initUgvDeviceId() {
    // Intenta encontrar el UGV entre los dispositivos conectados al iniciar.
    if (bleController.connectedCharacteristics.isNotEmpty) {
      // Uso de firstWhereOrNull para manejar el caso donde no se encuentra,
      // evitando el error de tipo al devolver null directamente.
      final ugvEntry =
          bleController.connectedCharacteristics.entries.firstWhereOrNull(
        (entry) =>
            entry.value.uuid.toString().toLowerCase() ==
            BleController.characteristicUuidUGV,
      );
      if (ugvEntry != null) {
        // Comprobar si se encontró una entrada
        ugvDeviceId = ugvEntry.key;
      }
    }

    // Monitorea los cambios en los dispositivos conectados para asignar el ID del UGV.
    ever(bleController.connectedDevices, (devices) {
      if (ugvDeviceId == null && devices.isNotEmpty) {
        final ugvEntry =
            bleController.connectedCharacteristics.entries.firstWhereOrNull(
          (entry) =>
              entry.value.uuid.toString().toLowerCase() ==
              BleController.characteristicUuidUGV,
        );
        if (ugvEntry != null) {
          // Comprobar si se encontró una entrada
          ugvDeviceId = ugvEntry.key;
        }
      }
    });
  }

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE MOVIMIENTO Y COMUNICACIÓN BLE
  //----------------------------------------------------------------------------

  /// Inicia el movimiento del UGV en una dirección específica.
  void _startMovement(String command) {
    // Solo envía el comando direccional si es diferente al último comando direccional enviado.
    if (_lastSentDirectionalCommand != command) {
      _lastSentDirectionalCommand = command;
      _sendBleCommand(command);
      _updatePosition(command); // Actualiza la posición visual en el mapa.
      // El modo automático NO se desactiva aquí.
    }
  }

  /// Detiene el movimiento del UGV.
  void _stopMovement() {
    // Siempre envía el comando de parada al presionar el botón "Stop"
    _sendBleCommand(BleController.stop);
    _lastSentDirectionalCommand =
        BleController.stop; // Resetear el último comando direccional
    // El modo automático NO se desactiva aquí.
  }

  /// Interrumpe el movimiento actual del UGV.
  /// Este método se usa para detener cualquier movimiento en curso, como cuando se presiona el botón "Stop".
  void _interruptMovement() {
    // Interrumpe el movimiento actual del UGV.
    _sendBleCommand(BleController.interruption);
    _lastSentDirectionalCommand =
        BleController.interruption; // Resetear el último comando direccional
    // Este SÍ desactiva el modo automático de forma brusca y reactiva los controles manuales inmediatamente.
    bleController.isAutomaticMode.value = false;
    _awaitingFinalTForManualControlsReactivation.value =
        false; // Reactivar controles manuales inmediatamente
  }

  /// Envía un comando BLE al dispositivo UGV.
  /// Implementa un control para que el SnackBar de advertencia no se repita innecesariamente.
  void _sendBleCommand(String commandToSend) {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      _logger.d(
          "Attempting to send BLE command: $commandToSend to UGV ID: $ugvDeviceId"); // Log detallado
      bleController.sendData(ugvDeviceId!, commandToSend);
      _connectionSnackbarShown = false;
    } else {
      _logger.w(
          "Cannot send BLE command '$commandToSend': UGV not connected or ugvDeviceId is null."); // Log de advertencia
      // Si no hay UGV conectado, solo muestra el SnackBar si no se ha mostrado antes.
      if (!_connectionSnackbarShown) {
        Get.snackbar("Advertencia",
            "No se ha conectado al UGV. Por favor, conecte el UGV.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
        _connectionSnackbarShown =
            true; // Establecer el flag para evitar repetición
      }
    }
  }

  /// Actualiza la posición simulada del UGV en el mapa.
  void _updatePosition(String direction) {
    setState(() {
      Offset lastPosition = recorridoPoints.last;
      Offset newPosition = lastPosition;

      switch (direction) {
        case BleController.moveForward:
          newPosition = Offset(lastPosition.dx, lastPosition.dy - stepSize);
          break;
        case BleController.moveBack:
          newPosition = Offset(lastPosition.dx, lastPosition.dy + stepSize);
          break;
        case BleController.moveLeft:
          newPosition = Offset(lastPosition.dx - stepSize, lastPosition.dy);
          break;
        case BleController.moveRight:
          newPosition = Offset(lastPosition.dx + stepSize, lastPosition.dy);
          break;
        default:
          return; // No hace nada para comandos no direccionales.
      }

      // Añade la nueva posición si ha cambiado.
      if (newPosition != lastPosition) {
        recorridoPoints = List.from(recorridoPoints)..add(newPosition);
        currentPosition = newPosition;
      }
    });
  }

  /// Alterna el estado de grabación del recorrido del UGV.
  void _toggleRecording() {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      bleController.toggleRecording(ugvDeviceId!);
      _connectionSnackbarShown = false;
      // El modo automático NO se desactiva aquí.
    } else {
      // Si no hay UGV conectado, solo muestra el SnackBar si no se ha mostrado antes.
      if (!_connectionSnackbarShown) {
        Get.snackbar("Advertencia", "No hay UGV conectado para grabar.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
        _connectionSnackbarShown = true;
      }
    }
  }

  /// --- LÓGICA CORREGIDA PARA EL BOTÓN 'AUTO' ---
  /// Alterna el estado del modo automático del UGV.
  void _toggleAutomaticMode() {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      // Si el modo automático estaba activo (botón rojo) y lo vamos a desactivar
      if (bleController.isAutomaticMode.value) {
        _logger.i("Disabling automatic mode from App.");
        bleController.isAutomaticMode.value =
            false; // Desactiva el estado en el controller (botón azul)
        // Establecer la bandera para esperar la 'T' final antes de reactivar controles manuales.
        _awaitingFinalTForManualControlsReactivation.value = true;
        // ¡NO ENVIAR NINGÚN COMANDO DE STOP AQUI! El ESP32 terminará su ciclo o ya se detuvo.
      } else {
        // Si el modo automático estaba inactivo (botón azul) y lo vamos a activar
        _logger.i("Enabling automatic mode from App.");
        bleController.isAutomaticMode.value =
            true; // Activa el estado en el controller (botón rojo)
        _sendBleCommand(BleController
            .startAutoMode); // Envía 'A' para iniciar el modo automático
        bleController.isRecording.value =
            false; // Desactiva la grabación si estaba activa
        _awaitingFinalTForManualControlsReactivation.value =
            false; // Resetear la bandera si se activa Auto
      }
      _connectionSnackbarShown = false;
    } else {
      // Si no hay UGV conectado
      if (!_connectionSnackbarShown) {
        Get.snackbar(
            "Advertencia", "No hay UGV conectado para modo automático.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
        _connectionSnackbarShown = true;
      }
    }
  }

  /// Reinicia el recorrido en el mapa.
  void _resetRecorrido() {
    setState(() {
      recorridoPoints = [const Offset(0, 0)];
      currentPosition = const Offset(0, 0);
    });
  }

  @override
  void dispose() {
    // Asegurarse de limpiar los recursos cuando el widget se destruye.
    super.dispose();
  }

  //----------------------------------------------------------------------------
  // SECCIÓN DE INTERFAZ DE USUARIO (BUILD METHODS)
  //----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Encabezado de la pantalla
            Container(
              margin: const EdgeInsets.only(right: 16, bottom: 10, left: 16),
              height: 60,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Modo UGV',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.backgroundWhite,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // Sección del mapa de recorrido
            Expanded(
              flex: 3,
              child: _buildCompactMapaRecorrido(context),
            ),
            const SizedBox(height: 12),
            // Sección de control manual del UGV
            Expanded(
              flex: 4,
              child: _buildCompactControlManual(context),
            ),
          ],
        ),
      ),
      // Botones flotantes de Stop y Reset
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCompactStopButton(),
            const SizedBox(width: 250), // Espacio entre los botones
            _buildCompactResetButton(),
          ],
        ),
      ),
    );
  }

  /// Construye el widget para visualizar el mapa de recorrido.
  Widget _buildCompactMapaRecorrido(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Container(
      width: screenSize.width * 0.90,
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.3)),
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: TrayectoriaPainter(recorridoPoints),
      ),
    );
  }

  /// Construye la sección de control manual del UGV (botones direccionales).
  Widget _buildCompactControlManual(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonSize = constraints.maxWidth * 0.22;

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCompactActionButtons(context), // Botones de Grabar y Auto
            const SizedBox(height: 12),
            // Botones direccionales
            // Envuelto en Obx para que reaccione a los cambios en isAutomaticMode.value
            Obx(() {
              // Determina si los botones de movimiento deben estar habilitados.
              // Estarán habilitados si el UGV está conectado
              // Y el modo automático NO está activo
              // Y NO estamos esperando la 'T' final para reactivar los controles (solo cuando se desactiva con el botón Auto).
              final bool areMovementButtonsEnabled =
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
                    isEnabled:
                        areMovementButtonsEnabled, // Controla la habilitación
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDirectionButton(
                        icon: Icons.arrow_back,
                        command: BleController.moveLeft,
                        size: buttonSize,
                        isEnabled:
                            areMovementButtonsEnabled, // Controla la habilitación
                      ),
                      SizedBox(
                          width: constraints.maxWidth *
                              0.2), // Espacio entre Left y Right
                      _buildDirectionButton(
                        icon: Icons.arrow_forward,
                        command: BleController.moveRight,
                        size: buttonSize,
                        isEnabled:
                            areMovementButtonsEnabled, // Controla la habilitación
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDirectionButton(
                    icon: Icons.arrow_downward,
                    command: BleController.moveBack,
                    size: buttonSize,
                    isEnabled:
                        areMovementButtonsEnabled, // Controla la habilitación
                  ),
                ],
              );
            }), // Fin de Obx
          ],
        );
      },
    );
  }

  /// Construye los botones de acción (Grabar y Auto).
  Widget _buildCompactActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón "Grabar" - usa Obx para reaccionar al estado de grabación
        Obx(
          () {
            // Determina si el botón Grabar debe estar habilitado.
            // Estará habilitado si el UGV está conectado
            // Y el modo automático NO está activo
            // Y NO estamos esperando la 'T' final para reactivar los controles.
            final bool isRecordButtonEnabled =
                bleController.isUgvConnected.value &&
                    !bleController.isAutomaticMode.value &&
                    !_awaitingFinalTForManualControlsReactivation.value;

            return _buildCompactActionButton(
              text: 'Grabar',
              icon: FontAwesomeIcons.circle,
              onPressed: isRecordButtonEnabled
                  ? _toggleRecording
                  : null, // Habilitación controlada
              isActive: _isRecording.value, // El color depende de este valor
            );
          },
        ),
        const SizedBox(width: 12),
        // Botón "Auto" - usa Obx para reaccionar al estado del modo automático
        Obx(
          () => _buildCompactActionButton(
            text: 'Auto',
            icon: FontAwesomeIcons.robot,
            onPressed: bleController.isUgvConnected.value
                ? _toggleAutomaticMode // Habilitado si el UGV está conectado
                : null, // Deshabilitado si no está conectado
            isActive: bleController
                .isAutomaticMode.value, // El color depende de este valor
          ),
        ),
      ],
    );
  }

  /// Widget genérico para un botón de acción compacto.
  Widget _buildCompactActionButton({
    required String text,
    required IconData icon,
    required Function()? onPressed, // onPressed puede ser nulo
    bool isActive =
        false, // Determina el color del botón (ej. rojo para grabar, verde/azul para auto)
  }) {
    return SizedBox(
      width: 100,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null
              ? Colors.grey // Gris si está deshabilitado
              : isActive
                  ? Colors.red // Rojo si está activo (ej. grabando)
                  : Colors.blue, // Colores dinámicos
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: FaIcon(icon, size: 16, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
      ),
    );
  }

  /// Widget genérico para un botón direccional del UGV.
  Widget _buildDirectionButton({
    required IconData icon,
    required String command,
    required double size,
    bool isEnabled = true, // Nuevo parámetro para controlar la habilitación
  }) {
    return GestureDetector(
      onTapDown: isEnabled
          ? (_) => _startMovement(command)
          : null, // Solo si está habilitado
      onTapUp:
          isEnabled ? (_) => _stopMovement() : null, // Solo si está habilitado
      onTapCancel:
          isEnabled ? () => _stopMovement() : null, // Solo si está habilitado
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEnabled
              ? Colors.blue
              : Colors.grey, // Color dinámico según habilitación
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  /// Construye el botón flotante de "Stop".
  Widget _buildCompactStopButton() {
    return FloatingActionButton(
      heroTag:
          'stop', // Realmente es una interrupción, pero se usa "stop" para la UI
      mini: false,
      backgroundColor: Colors.red,
      onPressed: bleController
              .isUgvConnected.value // Habilitado solo si el UGV está conectado
          ? _interruptMovement
          : null,
      child: const FaIcon(FontAwesomeIcons.stop, size: 24, color: Colors.white),
    );
  }

  /// Construye el botón flotante de "Reset" (para el mapa).
  Widget _buildCompactResetButton() {
    return FloatingActionButton(
      heroTag: 'reset',
      mini: false,
      backgroundColor: Colors.blueAccent,
      onPressed: bleController
              .isUgvConnected.value // Habilitado solo si el UGV está conectado
          ? _resetRecorrido
          : null,
      child: const Icon(Icons.refresh, size: 24, color: Colors.white),
    );
  }
}

/// CustomPainter para dibujar la trayectoria del UGV en el mapa.
class TrayectoriaPainter extends CustomPainter {
  final List<Offset> points;

  TrayectoriaPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Offset center = Offset(size.width / 2, size.height / 2);

    if (points.isNotEmpty) {
      Offset startPoint = center;
      for (int i = 0; i < points.length; i++) {
        Offset currentPoint =
            Offset(center.dx + points[i].dx, center.dy + points[i].dy);
        canvas.drawLine(startPoint, currentPoint, paint);
        startPoint = currentPoint;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
