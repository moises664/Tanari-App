import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceTile extends StatelessWidget {
  final BluetoothDevice device; // Dispositivo BLE
  final VoidCallback onConnect; // Función para conectar
  final bool isConnected; // <- Parámetro añadido
  final int? rssi; // <- Parámetro añadido

  const DeviceTile({
    super.key,
    required this.device,
    required this.onConnect,
    required this.isConnected,
    required this.rssi,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.bluetooth,
        color: isConnected ? Colors.green : Colors.grey, // Color dinámico
      ),
      title: Text(device.platformName),
      subtitle: Text(
        "${device.remoteId.str} | RSSI: ${rssi ?? 'N/A'}  dBm",
      ), // Muestra RSSI
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.link), onPressed: onConnect),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed:
                () => showDeviceDetails(context, device), // Nueva función
          ),
        ],
      ),
    );
  }
}

void showDeviceDetails(BuildContext context, BluetoothDevice device) {
  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text('Device Details'),
          content: Text(
            'Device ID: ${device.remoteId.str}\nName: ${device.platformName}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
  );
}
