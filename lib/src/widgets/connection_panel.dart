import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const Color _connectedColor = Colors.green;
const Color _disconnectedColor = Colors.red;
const Color _identifierColor = Colors.blue;

class ConnectionPanel extends StatelessWidget {
  final BluetoothDevice? device;
  final int? rssi;
  final VoidCallback onDisconnect;
  final bool isConnected;

  const ConnectionPanel({
    super.key,
    required this.device,
    required this.rssi,
    required this.onDisconnect,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final deviceName = device?.platformName ?? 'Nombre Desconocido';
    final deviceId = device?.remoteId.str;
    final truncatedDeviceId = deviceId != null && deviceId.length > 5
        ? deviceId.substring(deviceId.length - 5)
        : deviceId ?? '--';

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              deviceName,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: isConnected ? _connectedColor : _disconnectedColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoChip(
                  icon: Icons.signal_cellular_alt,
                  label: '${rssi?.toString() ?? '--'} dBm',
                  color: isConnected ? _connectedColor : null,
                ),
                _InfoChip(
                  icon: Icons.bluetooth,
                  label: truncatedDeviceId,
                  color: isConnected ? _identifierColor : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('DESCONECTAR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _disconnectedColor,
                side: const BorderSide(color: _disconnectedColor),
              ),
              onPressed: onDisconnect,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 20, color: color),
      label: Text(label, style: TextStyle(color: color)),
      backgroundColor: Colors.grey[200],
    );
  }
}
