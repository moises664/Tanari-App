import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Asegúrate de que esta ruta sea correcta

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
      // Usar firstWhere con orElse para manejar el caso donde no se encuentra.
      final ugvEntry =
          bleController.connectedCharacteristics.entries.firstWhere(
        (entry) =>
            entry.value.uuid.toString().toLowerCase() ==
            BleController.characteristicUuidUGV,
        orElse: () => MapEntry(
            '',
            bleController.connectedCharacteristics.values.isNotEmpty
                ? bleController.connectedCharacteristics.values.first
                : throw Exception(
                    'No BluetoothCharacteristic found')), // Devuelve una entrada vacía si no se encuentra
      );
      if (ugvEntry.value != null) {
        // Verificar si realmente se encontró una característica
        ugvDeviceId = ugvEntry.key;
      }
    }

    // Monitorea los cambios en los dispositivos conectados para asignar el ID del UGV.
    ever(bleController.connectedDevices, (devices) {
      if (ugvDeviceId == null && devices.isNotEmpty) {
        final ugvEntry =
            bleController.connectedCharacteristics.entries.firstWhere(
          (entry) =>
              entry.value.uuid.toString().toLowerCase() ==
              BleController.characteristicUuidUGV,
          orElse: () => MapEntry(
              '',
              bleController.connectedCharacteristics.values.isNotEmpty
                  ? bleController.connectedCharacteristics.values.first
                  : throw Exception(
                      'No BluetoothCharacteristic found')), // Devuelve una entrada vacía si no se encuentra
        );
        if (ugvEntry.value != null) {
          // Verificar si realmente se encontró una característica
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
      bleController.isAutomaticMode.value =
          false; // Desactivar modo automático al iniciar movimiento manual
    }
  }

  /// Detiene el movimiento del UGV.
  void _stopMovement() {
    // Siempre envía el comando de parada al presionar el botón "Stop"
    _sendBleCommand(BleController.stop);
    _lastSentDirectionalCommand =
        BleController.stop; // Resetear el último comando direccional
    bleController.isAutomaticMode.value =
        false; // Desactivar modo automático al parar
  }

  /// Envía un comando BLE al dispositivo UGV.
  /// Implementa un control para que el SnackBar de advertencia no se repita innecesariamente.
  void _sendBleCommand(String commandToSend) {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      bleController.sendData(ugvDeviceId!, commandToSend);
      _connectionSnackbarShown = false;
    } else {
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
      // Al iniciar grabación, podríamos querer desactivar el modo automático si estaba activo
      if (_isRecording.value) {
        // Si se acaba de activar la grabación
        bleController.isAutomaticMode.value = false;
      }
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

  /// Inicia el modo automático del UGV.
  void _startAutomaticMode() {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      bleController.startAutomaticMode(ugvDeviceId!);
      _connectionSnackbarShown = false;
      // Al activar el modo automático, desactivar la grabación si estaba activa
      bleController.isRecording.value = false;
    } else {
      // Si no hay UGV conectado, solo muestra el SnackBar si no se ha mostrado antes.
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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDirectionButton(
                  icon: Icons.arrow_upward,
                  command: BleController.moveForward,
                  size: buttonSize,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDirectionButton(
                      icon: Icons.arrow_back,
                      command: BleController.moveLeft,
                      size: buttonSize,
                    ),
                    SizedBox(
                        width: constraints.maxWidth *
                            0.2), // Espacio entre Left y Right
                    _buildDirectionButton(
                      icon: Icons.arrow_forward,
                      command: BleController.moveRight,
                      size: buttonSize,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDirectionButton(
                  icon: Icons.arrow_downward,
                  command: BleController.moveBack,
                  size: buttonSize,
                ),
              ],
            ),
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
          () => _buildCompactActionButton(
            text: 'Grabar',
            icon: FontAwesomeIcons.circle,
            onPressed: _toggleRecording,
            isActive: _isRecording.value, // El color depende de este valor
          ),
        ),
        const SizedBox(width: 12),
        // Botón "Auto" - usa Obx para reaccionar al estado del modo automático
        Obx(
          () => _buildCompactActionButton(
            text: 'Auto',
            icon: FontAwesomeIcons.robot,
            onPressed: _startAutomaticMode,
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
    required Function() onPressed,
    bool isActive =
        false, // Determina el color del botón (ej. rojo para grabar, verde/azul para auto)
  }) {
    return SizedBox(
      width: 100,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
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
  }) {
    return GestureDetector(
      onTapDown: (_) => _startMovement(command), // Al presionar
      onTapUp: (_) => _stopMovement(), // Al soltar
      onTapCancel: () => _stopMovement(), // Al cancelar (ej. arrastrar fuera)
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.blue,
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
      heroTag: 'stop',
      mini: false,
      backgroundColor: Colors.red,
      onPressed: _stopMovement, // Llama directamente a _stopMovement
      child: const FaIcon(FontAwesomeIcons.stop, size: 24, color: Colors.white),
    );
  }

  /// Construye el botón flotante de "Reset" (para el mapa).
  Widget _buildCompactResetButton() {
    return FloatingActionButton(
      heroTag: 'reset',
      mini: false,
      backgroundColor: Colors.blueAccent,
      onPressed: _resetRecorrido,
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
