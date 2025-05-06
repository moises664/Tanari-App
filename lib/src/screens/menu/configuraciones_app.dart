import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/widgets/connection_panel.dart';
import 'package:tanari_app/src/widgets/device_tile.dart';

class ConfiguracionesApp extends StatelessWidget {
  const ConfiguracionesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final BleController bleController = Get.find<BleController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent.shade700,
        title: const Text('Control BLE'),
        actions: [
          Obx(
            () => IconButton(
              icon: Icon(
                bleController.isScanning.value ? Icons.stop : Icons.search,
              ),
              onPressed: bleController.isScanning.value
                  ? bleController.stopScan
                  : bleController.startScan,
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (bleController.connectedDevices.isNotEmpty) {
          // Usa firstKey para obtener el ID del primer dispositivo conectado.
          final deviceId = bleController.connectedDevices.keys.first;
          final connectedDevice = bleController.connectedDevices[deviceId]!;
          final rssi = bleController.rssiValues[deviceId] ?? 0;
          return ConnectionPanel(
            device: connectedDevice,
            rssi: rssi,
            onDisconnect: () => bleController.disconnectDevice(deviceId),
            isConnected: true,
          );
        } else {
          return _DeviceList(controller: bleController);
        }
      }),
      floatingActionButton: Obx(
        () => FloatingActionButton(
          onPressed: bleController.connectedDevices.isNotEmpty
              ? () {
                  // Enviar el id del primer dispositivo conectado.
                  final deviceId = bleController.connectedDevices.keys.first;
                  bleController.sendData(
                      deviceId, bleController.ledStateUGV.value ? 'L' : 'H');
                }
              : null,
          backgroundColor: bleController.connectedDevices.isNotEmpty
              ? null
              : Colors.grey.shade300,
          child: Icon(
            bleController.ledStateUGV.value
                ? Icons.toggle_on
                : Icons.toggle_off,
            color:
                bleController.connectedDevices.isNotEmpty ? null : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// Widget separado para la lista de dispositivos (optimiza reconstrucciones)
class _DeviceList extends StatelessWidget {
  final BleController controller;

  const _DeviceList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Wrap the ListView.builder with Obx
      return ListView.builder(
        itemCount: controller.foundDevices.length,
        itemBuilder: (ctx, index) {
          final foundDevice = controller.foundDevices[index];
          final isConnected = controller.connectedDevices
              .containsKey(foundDevice.device.remoteId.str);
          return DeviceTile(
            device: foundDevice.device,
            rssi: foundDevice.rssi,
            isConnected: isConnected,
            onConnect: () => controller.connectToDevice(foundDevice),
          );
        },
      );
    });
  }
}
