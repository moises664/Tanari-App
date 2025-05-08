import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';

class ModoUgv extends StatefulWidget {
  const ModoUgv({super.key});

  @override
  State<ModoUgv> createState() => _ModoUgvState();
}

class _ModoUgvState extends State<ModoUgv> {
  final BleController bleController = Get.find<BleController>();
  List<Offset> recorridoPoints = [Offset(0, 0)];
  Offset currentPosition = Offset(0, 0);
  double stepSize = 20.0;
  String? ugvDeviceId;
  // Timer para el envío continuo de comandos
  Timer? _movementTimer;
  String _currentCommand = BleController.stop; // Inicializa con 'S' para parado
  final RxBool _isRecording = false.obs;

  @override
  void initState() {
    super.initState();
    _initUgvDeviceId();
    _bindRecordingState();
  }

  void _bindRecordingState() {
    // Vincula la variable local _isRecording con el valor de isRecording en el BleController
    ever(bleController.isRecording, (recording) {
      _isRecording.value = recording;
    });
  }

  void _initUgvDeviceId() {
    if (bleController.connectedDevices.isNotEmpty) {
      ugvDeviceId = bleController.connectedDevices.keys.firstWhere(
        (key) =>
            bleController.connectedCharacteristics[key]?.uuid.toString() ==
            BleController.characteristicUuidUGV,
        orElse: () => '',
      );
    }

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

  void _startMovement(String command) {
    _currentCommand = command; // Actualiza el comando actual
    _sendMovementCommand();
    // Cancela el timer anterior si existe
    _movementTimer?.cancel();
    // Inicia un timer para enviar el comando continuamente cada 100ms
    _movementTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _sendMovementCommand();
    });
  }

  void _stopMovement() {
    _currentCommand =
        BleController.stop; // Establece el comando a 'S' para parar
    _sendMovementCommand();
    _movementTimer?.cancel();
  }

  void _sendMovementCommand() {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      bleController.sendData(ugvDeviceId!, _currentCommand);
      if (_isRecording.value &&
          _currentCommand != BleController.stop &&
          _currentCommand != BleController.startRecording &&
          _currentCommand != BleController.stopRecording &&
          _currentCommand != BleController.startAutoMode) {
        _updatePosition(_currentCommand);
      }
    } else {
      Get.snackbar("Advertencia", "No se ha conectado al UGV.");
    }
  }

  void _updatePosition(String direction) {
    setState(() {
      Offset lastPosition = recorridoPoints.last;
      switch (direction) {
        case BleController.moveForward:
          currentPosition = Offset(lastPosition.dx, lastPosition.dy - stepSize);
          break;
        case BleController.moveBack:
          currentPosition = Offset(lastPosition.dx, lastPosition.dy + stepSize);
          break;
        case BleController.moveLeft:
          currentPosition = Offset(lastPosition.dx - stepSize, lastPosition.dy);
          break;
        case BleController.moveRight:
          currentPosition = Offset(lastPosition.dx + stepSize, lastPosition.dy);
          break;
        default:
          return;
      }
      recorridoPoints = List.from(recorridoPoints)..add(currentPosition);
    });
  }

  void _toggleRecording() {
    if (ugvDeviceId != null) {
      bleController.toggleRecording(ugvDeviceId!);
    } else {
      Get.snackbar("Advertencia", "No hay UGV conectado para grabar.");
    }
  }

  void _startAutomaticMode() {
    if (ugvDeviceId != null) {
      bleController.startAutomaticMode(ugvDeviceId!);
    } else {
      Get.snackbar("Advertencia", "No hay UGV conectado para modo automático.");
    }
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control UGV'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Control Manual',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Controles de movimiento
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTapDown: (_) => _startMovement(BleController.moveForward),
                  onTapUp: (_) => _stopMovement(),
                  onTapCancel: () => _stopMovement(),
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('↑'),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTapDown: (_) => _startMovement(BleController.moveLeft),
                  onTapUp: (_) => _stopMovement(),
                  onTapCancel: () => _stopMovement(),
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('←'),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => _stopMovement(),
                  child: const Text('Parar'),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTapDown: (_) => _startMovement(BleController.moveRight),
                  onTapUp: (_) => _stopMovement(),
                  onTapCancel: () => _stopMovement(),
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('→'),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTapDown: (_) => _startMovement(BleController.moveBack),
                  onTapUp: (_) => _stopMovement(),
                  onTapCancel: () => _stopMovement(),
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('↓'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleRecording,
              child: Obx(() => Text(_isRecording.value
                  ? 'Detener Grabación'
                  : 'Iniciar Grabación')),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startAutomaticMode,
              child: const Text('Modo Automático'),
            ),
            const SizedBox(height: 20),
            // Visualización del recorrido
            const Text(
              'Recorrido',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                color: Colors.grey[200],
              ),
              child: CustomPaint(
                painter: TrayectoriaPainter(recorridoPoints),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrayectoriaPainter extends CustomPainter {
  final List<Offset> points;

  TrayectoriaPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (points.isNotEmpty) {
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(
          Offset(points[i].dx + 150, points[i].dy + 150),
          Offset(points[i + 1].dx + 150, points[i + 1].dy + 150),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
