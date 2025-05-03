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
        final connectedDevice = bleController.connectedDevice.value;
        if (connectedDevice != null) {
          return ConnectionPanel(
            device: connectedDevice.device,
            rssi: bleController.rssi.value ?? 0,
            onDisconnect: bleController.cleanupConnection,
            isConnected: true,
          );
        } else {
          return _DeviceList(controller: bleController);
        }
      }),
      floatingActionButton: Obx(
        () => FloatingActionButton(
          onPressed: bleController.isConnected
              ? bleController.toggleLed
              : null, // onPressed será null si no está conectado (deshabilitado)
          backgroundColor:
              bleController.isConnected ? null : Colors.grey.shade300,
          child: Icon(
            bleController.ledState.value ? Icons.toggle_on : Icons.toggle_off,
            color: bleController.isConnected
                ? null
                : Colors.grey, // Cambia el color del icono
          ), // Cambia el color del fondo
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
    return Obx(() => ListView.builder(
          // *** ENVOLVIENDO TODO EL ListView.builder CON Obx ***
          itemCount: controller.foundDevices.length,
          itemBuilder: (ctx, index) {
            final foundDevice = controller.foundDevices[index];
            return DeviceTile(
              device: foundDevice.device,
              rssi: foundDevice.rssi,
              isConnected: foundDevice.device ==
                  controller.connectedDevice.value?.device,
              onConnect: () => controller.connectToDevice(foundDevice),
            );
          },
        ));
  }
}
