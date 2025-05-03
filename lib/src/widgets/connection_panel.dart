import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              device?.platformName ?? 'Nombre Desconocido',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isConnected ? Colors.green : Colors.red,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoChip(
                  icon: Icons.signal_cellular_alt,
                  label: '${rssi?.toString() ?? '--'} dBm',
                  color: isConnected ? Colors.green : null,
                ),
                _InfoChip(
                  icon: Icons.bluetooth,
                  label: device?.remoteId.str != null &&
                          device!.remoteId.str.length > 5
                      ? device!.remoteId.str
                          .substring(device!.remoteId.str.length - 5)
                      : device?.remoteId.str ?? '--',
                  color: isConnected ? Colors.blue : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('DESCONECTAR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
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
