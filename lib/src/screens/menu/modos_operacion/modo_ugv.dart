import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart';

/// Pantalla principal para el control manual y automático del UGV
class ModoUgv extends StatefulWidget {
  const ModoUgv({super.key});

  @override
  State<ModoUgv> createState() => _ModoUgvState();
}

/// Estado que gestiona la lógica de control y visualización del UGV
class _ModoUgvState extends State<ModoUgv> {
  // Controlador Bluetooth
  final BleController bleController = Get.find<BleController>();

  // Variables para el trazado del recorrido
  List<Offset> recorridoPoints = [Offset(0, 0)];
  Offset currentPosition = Offset(0, 0);
  double stepSize = 20.0;

  // Identificador del dispositivo UGV conectado
  String? ugvDeviceId;

  // Timer para movimiento continuo
  Timer? _movementTimer;

  // Comando actual y estado de grabación
  String _currentCommand = BleController.stop;
  final RxBool _isRecording = false.obs;

  @override
  void initState() {
    super.initState();
    _initUgvDeviceId();
    _bindRecordingState();
  }

  /// Vincula el estado de grabación del controlador BLE con el estado local
  void _bindRecordingState() {
    ever(bleController.isRecording, (recording) {
      _isRecording.value = recording;
    });
  }

  /// Inicializa el ID del dispositivo UGV desde el controlador BLE
  void _initUgvDeviceId() {
    if (bleController.connectedDevices.isNotEmpty) {
      ugvDeviceId = bleController.connectedDevices.keys.firstWhere(
        (key) =>
            bleController.connectedCharacteristics[key]?.uuid.toString() ==
            BleController.characteristicUuidUGV,
        orElse: () => '',
      );
    }

    // Actualiza el ID si se conecta un nuevo dispositivo
    ever(bleController.connectedDevices, (devices) {
      if (ugvDeviceId == null && devices.isNotEmpty) {
        ugvDeviceId = devices.keys.firstWhere(
          (key) =>
              bleController.connectedCharacteristics[key]?.uuid.toString() ==
              BleController.characteristicUuidUGV,
          orElse: () => '',
        );
      }
    });
  }

  /// Inicia el movimiento en una dirección específica
  void _startMovement(String command) {
    _currentCommand = command;
    _sendMovementCommand();
    _movementTimer?.cancel();
    // Configura un timer para enviar comandos continuos cada 100ms
    _movementTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _sendMovementCommand();
      _updatePosition(command);
    });
  }

  /// Detiene el movimiento del UGV
  void _stopMovement() {
    _currentCommand = BleController.stop;
    _sendMovementCommand();
    _movementTimer?.cancel();
  }

  /// Envía el comando actual al dispositivo BLE
  void _sendMovementCommand() {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      bleController.sendData(ugvDeviceId!, _currentCommand);
    } else {
      Get.snackbar("Advertencia", "No se ha conectado al UGV.");
    }
  }

  /// Actualiza la posición del recorrido en el mapa
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
          return;
      }

      if (newPosition != lastPosition) {
        recorridoPoints = List.from(recorridoPoints)..add(newPosition);
        currentPosition = newPosition;
      }
    });
  }

  /// Activa/desactiva la grabación del recorrido
  void _toggleRecording() {
    if (ugvDeviceId != null) {
      bleController.toggleRecording(ugvDeviceId!);
    } else {
      Get.snackbar("Advertencia", "No hay UGV conectado para grabar.");
    }
  }

  /// Activa el modo de funcionamiento automático
  void _startAutomaticMode() {
    if (ugvDeviceId != null) {
      bleController.startAutomaticMode(ugvDeviceId!);
    } else {
      Get.snackbar("Advertencia", "No hay UGV conectado para modo automático.");
    }
  }

  /// Reinicia el mapa de recorrido
  void _resetRecorrido() {
    setState(() {
      recorridoPoints = [Offset(0, 0)];
      currentPosition = Offset(0, 0);
    });
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  // SECCIÓN DE INTERFAZ DE USUARIO
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
            // Título de la pantalla (reemplaza el título del AppBar)
            Container(
              margin: const EdgeInsets.only(right: 16, bottom: 10, left: 16),
              height: 60,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 20.0,
                    bottom: 16.0), // Ajusta el padding según necesites
                child: Text(
                  'Modo UGV',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors
                            .backgroundPrimary, // Color del texto del título
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: _buildCompactMapaRecorrido(context),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 4,
              child: _buildCompactControlManual(context),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCompactStopButton(),
            const SizedBox(width: 250),
            _buildCompactResetButton(),
          ],
        ),
      ),
    );
  }

  /// Construye el contenedor del mapa de recorrido
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

  /// Construye la sección de controles manuales
  Widget _buildCompactControlManual(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonSize =
            constraints.maxWidth * 0.22; // Ajusta el tamaño del botón

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCompactActionButtons(context),
            const SizedBox(height: 12),
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
                    SizedBox(width: constraints.maxWidth * 0.2),
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

  /// Construye los botones de acción principales
  Widget _buildCompactActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCompactActionButton(
          text: 'Grabar',
          icon: FontAwesomeIcons.circle,
          onPressed: _toggleRecording,
          isActive: _isRecording.value,
        ),
        const SizedBox(width: 12),
        _buildCompactActionButton(
          text: 'Auto',
          icon: FontAwesomeIcons.robot,
          onPressed: _startAutomaticMode,
        ),
      ],
    );
  }

  /// Plantilla para botones de acción compactos
  Widget _buildCompactActionButton({
    required String text,
    required IconData icon,
    required Function() onPressed,
    bool isActive = false,
  }) {
    return SizedBox(
      width: 100,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.red : Colors.blue,
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

  /// Construye botones direccionales circulares
  Widget _buildDirectionButton({
    required IconData icon,
    required String command,
    required double size,
  }) {
    return GestureDetector(
      onTapDown: (_) => _startMovement(command),
      onTapUp: (_) => _stopMovement(),
      onTapCancel: () => _stopMovement(),
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

  /// Botón de detención de emergencia
  Widget _buildCompactStopButton() {
    return FloatingActionButton(
      heroTag: 'stop',
      mini: false,
      backgroundColor: Colors.red,
      onPressed: _stopMovement,
      child: const FaIcon(FontAwesomeIcons.stop, size: 24, color: Colors.white),
    );
  }

  /// Botón de reinicio del recorrido
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

/// CustomPainter para dibujar el trayecto del UGV
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
      // Dibuja líneas conectando todos los puntos del recorrido
      for (int i = 0; i < points.length; i++) {
        Offset currentPoint =
            Offset(center.dx + points[i].dx, center.dy + points[i].dy);
        canvas.drawLine(startPoint, currentPoint, paint);
        startPoint = currentPoint;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
