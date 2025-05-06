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
  bool isGuardandoRecorrido = false;

  // Identificador del dispositivo UGV (deberías obtenerlo al conectar)
  String? ugvDeviceId;

  @override
  void initState() {
    super.initState();
    // Simulación de la obtención del ID del UGV al conectar
    // En una implementación real, esto se haría en el BleController y se pasaría aquí.
    if (bleController.connectedDevices.isNotEmpty) {
      ugvDeviceId = bleController.connectedDevices.keys.firstWhere(
        (key) =>
            bleController.connectedCharacteristics[key]?.uuid
                .toString()
                .toLowerCase() ==
            BleController.characteristicUuidUGV,
        orElse: () => '', // Retorna un String vacío en lugar de null
      );
    }
    // Escuchar cambios en los dispositivos conectados para obtener el ID del UGV si aún no se tiene
    ever(bleController.connectedDevices, (devices) {
      if (ugvDeviceId == null && devices.isNotEmpty) {
        ugvDeviceId = devices.keys.firstWhere(
          (key) =>
              bleController.connectedCharacteristics[key]?.uuid
                  .toString()
                  .toLowerCase() ==
              BleController.characteristicUuidUGV,
          orElse: () => '', // Retorna un String vacío en lugar de null
        );
      }
    });
  }

  void _updatePosition(String direction) {
    setState(() {
      Offset lastPosition = recorridoPoints.last;
      switch (direction) {
        case 'F':
          currentPosition = Offset(lastPosition.dx, lastPosition.dy - stepSize);
          break;
        case 'B':
          currentPosition = Offset(lastPosition.dx, lastPosition.dy + stepSize);
          break;
        case 'L':
          currentPosition = Offset(lastPosition.dx - stepSize, lastPosition.dy);
          break;
        case 'R':
          currentPosition = Offset(lastPosition.dx + stepSize, lastPosition.dy);
          break;
      }
      recorridoPoints.add(currentPosition);
    });
  }

  void _enviarComando(String comando) {
    if (ugvDeviceId != null && bleController.isDeviceConnected(ugvDeviceId!)) {
      bleController.sendData(ugvDeviceId!, comando);
      if (isGuardandoRecorrido &&
          comando != 'S' &&
          comando != 'G' &&
          comando != 'N' &&
          comando != 'A') {
        _updatePosition(comando);
      }
    } else {
      Get.snackbar("Advertencia", "No se ha conectado al UGV.");
    }
  }

  void _toggleGuardarRecorrido() {
    setState(() {
      isGuardandoRecorrido = !isGuardandoRecorrido;
      _enviarComando(isGuardandoRecorrido ? 'G' : 'N');
    });
  }

  void _enviarAutomatico() {
    _enviarComando('A');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text("Control del Carrito", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent.shade700,
      ),
      body: Column(
        children: [
          // Mapa del recorrido.
          Container(
            margin: EdgeInsets.all(20),
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CustomPaint(
                painter: RecorridoPainter(recorridoPoints, currentPosition),
                size: Size.infinite,
              ),
            ),
          ),
          // Indicadores
          Container(
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 10),
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text('Panel de indicadores'),
                  Row(),
                ],
              ),
            ),
          ),
          // Control
          Container(
            height: 300,
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 10),
            decoration: BoxDecoration(
                color: Colors.blueAccent.shade100,
                borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTapDown: (_) => _enviarComando('F'),
                    onTapUp: (_) => _enviarComando('S'),
                    onTapCancel: () => _enviarComando('S'),
                    child: Icon(Icons.arrow_upward, size: 50),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTapDown: (_) => _enviarComando('L'),
                        onTapUp: (_) => _enviarComando('S'),
                        onTapCancel: () => _enviarComando('S'),
                        child: Icon(Icons.arrow_back, size: 50),
                      ),
                      SizedBox(width: 55),
                      GestureDetector(
                        onTapDown: (_) => _enviarComando('R'),
                        onTapUp: (_) => _enviarComando('S'),
                        onTapCancel: () => _enviarComando('S'),
                        child: Icon(Icons.arrow_forward, size: 50),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTapDown: (_) => _enviarComando('B'),
                    onTapUp: (_) => _enviarComando('S'),
                    onTapCancel: () => _enviarComando('S'),
                    child: Icon(Icons.arrow_downward, size: 50),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: _toggleGuardarRecorrido,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isGuardandoRecorrido ? Colors.red : Colors.grey,
                        ),
                        child: Text(isGuardandoRecorrido
                            ? 'Detener Guardado'
                            : 'Guardar Recorrido'),
                      ),
                      ElevatedButton(
                        onPressed: _enviarAutomatico,
                        child: Text('Recorrido Automático'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecorridoPainter extends CustomPainter {
  final List<Offset> points;
  final Offset currentPos;

  RecorridoPainter(this.points, this.currentPos);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Dibujar el recorrido
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Dibujar el punto de inicio
    canvas.drawCircle(points.first, 5, Paint()..color = Colors.green);

    // Dibujar la posición actual del carrito
    var carPaint = Paint()..color = Colors.red;
    Path path = Path();
    path.moveTo(currentPos.dx, currentPos.dy - 10); // Parte superior
    path.lineTo(currentPos.dx + 8, currentPos.dy + 8); // Derecha
    path.lineTo(currentPos.dx - 8, currentPos.dy + 8); // Izquierda
    path.close();
    canvas.drawPath(path, carPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
