import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Importa Font Awesome

const Color _connectedColor = Colors.green;
const Color _disconnectedColor = Colors.grey;

class DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onConnect;
  final bool isConnected;
  final int? rssi;

  const DeviceTile({
    super.key,
    required this.device,
    required this.onConnect,
    required this.isConnected,
    required this.rssi,
  });

  @override
  Widget build(BuildContext context) {
    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : 'Nombre Desconocido';
    return ListTile(
      leading: Icon(
        Icons.bluetooth,
        color: isConnected ? _connectedColor : _disconnectedColor,
      ),
      title: Text(deviceName),
      subtitle: _RssiInfo(rssi: rssi), // Widget para mostrar el RSSI
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.link), onPressed: onConnect),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showDeviceDetails(context, device),
          ),
        ],
      ),
    );
  }
}

class _RssiInfo extends StatelessWidget {
  final int? rssi;

  const _RssiInfo({this.rssi});

  @override
  Widget build(BuildContext context) {
    String rssiText = rssi != null ? '$rssi dBm' : 'N/A';
    Color rssiColor = Colors.grey;
    IconData rssiIcon =
        FontAwesomeIcons.signal; // Icono por defecto de Font Awesome

    if (rssi != null) {
      if (rssi! >= -70) {
        rssiColor = Colors.green;
        rssiIcon = FontAwesomeIcons.signal; // Señal completa
      } else if (rssi! >= -80) {
        rssiColor = Colors.lightGreen;
        rssiIcon = FontAwesomeIcons.signal; // Señal media-alta
      } else if (rssi! >= -90) {
        rssiColor = Colors.orange;
        rssiIcon = FontAwesomeIcons.signal; // Señal media-baja
      } else {
        rssiColor = Colors.red;
        rssiIcon = FontAwesomeIcons.signal; // Señal baja
      }
    }

    return Row(
      children: [
        Icon(rssiIcon, color: rssiColor, size: 16),
        const SizedBox(width: 4),
        Text('RSSI: $rssiText', style: TextStyle(color: rssiColor)),
      ],
    );
  }
}

void _showDeviceDetails(BuildContext context, BluetoothDevice device) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Device Details'),
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
