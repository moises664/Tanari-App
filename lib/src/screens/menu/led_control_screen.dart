import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onConnect;
  final bool isConnected; // <- Parámetro añadido
  final int? rssi; // <- Parámetro añadido

  const DeviceTile({
    super.key,
    required this.device,
    required this.onConnect,
    required this.isConnected, // <- Añade esto
    this.rssi, // <- Añade esto
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.bluetooth,
        color: isConnected ? Colors.green : Colors.grey,
      ),
      title: Text(device.platformName),
      subtitle: Text(
        "${device.remoteId.str}${rssi != null ? ' | $rssi dBm' : ''}", // Muestra RSSI solo si existe
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.link), onPressed: onConnect),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showDeviceDetails(context), // Función interna
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Device Details'),
            content: Text(
              'ID: ${device.remoteId.str}\n'
              'Name: ${device.platformName}\n'
              'RSSI: ${rssi ?? 'N/A'} dBm',
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
}
