import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Importa GetX para usar Get.find y Obx
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/widgets/device_tile.dart'; // Asegúrate de que esta ruta sea correcta

class ComunicacionBleScreen extends StatelessWidget {
  ComunicacionBleScreen({super.key});

  // Obtén la instancia de tu BleController.
  // Se asume que BleController ya fue puesto en la memoria con Get.put() o Get.lazyPut().
  final BleController bleController = Get.find<BleController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunicación BLE'),
        backgroundColor: AppColors.backgroundBlack,
        foregroundColor: AppColors.primary,
        centerTitle: true, // Centra el título en la AppBar
        actions: [
          // Botón de escaneo/parada de escaneo, reactivo al estado de isScanning.
          Obx(() => IconButton(
                icon: Icon(
                  bleController.isScanning.value ? Icons.stop : Icons.search,
                  color: bleController.isScanning.value
                      ? Colors.redAccent
                      : Colors.white,
                ),
                onPressed: () {
                  if (bleController.isScanning.value) {
                    bleController.stopScan();
                  } else {
                    bleController.startScan();
                  }
                },
                tooltip: bleController.isScanning.value
                    ? 'Detener Escaneo'
                    : 'Iniciar Escaneo',
              )),
          const SizedBox(width: 8), // Espacio entre los iconos
        ],
      ),
      body: Obx(() {
        // Muestra un mensaje si no se encontraron dispositivos durante el escaneo.
        if (bleController.foundDevices.isEmpty &&
            !bleController.isScanning.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bluetooth_searching, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No se encontraron dispositivos Tanari.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Asegúrate de que estén encendidos y dentro del alcance.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        } else if (bleController.isScanning.value &&
            bleController.foundDevices.isEmpty) {
          // Muestra un indicador de carga mientras escanea y aún no hay resultados.
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Buscando dispositivos Tanari...',
                    style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        // Si hay dispositivos encontrados, los muestra en una lista.
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: bleController.foundDevices.length,
          itemBuilder: (context, index) {
            final foundDevice = bleController.foundDevices[index];
            final device = foundDevice.device;
            final deviceId = device.remoteId.str;

            // Determina si el dispositivo actual en el tile está conectado.
            final isConnected =
                bleController.connectedDevices.containsKey(deviceId);

            // Obtiene el RSSI actual del dispositivo.
            final rssi = bleController.rssiValues[deviceId];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: DeviceTile(
                device: device,
                isConnected: isConnected,
                rssi: rssi,

                // Botón de Conectar: solo activo si el dispositivo no está conectado.
                onConnect: isConnected
                    ? null
                    : () => bleController.connectToDevice(foundDevice),

                // Botón de Desconectar: solo activo si el dispositivo está conectado.
                onDisconnect: isConnected
                    ? () => bleController.disconnectDevice(deviceId)
                    : null,
              ),
            );
          },
        );
      }),
      // Puedes añadir un FloatingActionButton aquí si lo necesitas para otras acciones globales,
      // como un control maestro del UGV o navegación.
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Ejemplo: Navegar a una pantalla de control global del UGV
      //     if (bleController.isUgvConnected.value) {
      //       Get.to(() => UgvControlScreen()); // Asegúrate de definir UgvControlScreen
      //     } else {
      //       Get.snackbar("Info", "UGV no conectado.", snackPosition: SnackPosition.BOTTOM);
      //     }
      //   },
      //   child: const Icon(Icons.robot),
      //   tooltip: 'Control UGV',
      // ),
    );
  }
}
