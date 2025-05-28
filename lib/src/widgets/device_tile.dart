import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Asegúrate de tener este paquete en pubspec.yaml

// Colores constantes para la UI
const Color _connectedColor = Colors.green;
const Color _disconnectedColor = Colors.grey;
const Color _actionButtonColor = Colors.blueAccent;

/// Extensión para capitalizar la primera letra de una cadena.
/// Útil para formatear nombres de tipos de dispositivos.
extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// Un widget que representa un dispositivo Bluetooth en una lista.
/// Muestra el nombre del dispositivo, su RSSI, estado de conexión y botones de acción.
class DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback? onConnect; // Callback para conectar, puede ser nulo.
  final VoidCallback?
      onDisconnect; // Callback para desconectar, puede ser nulo.
  final VoidCallback?
      onToggleLed; // Callback para controlar el LED, puede ser nulo.
  final bool isConnected; // Indica si el dispositivo está conectado.
  final int? rssi; // Valor de la señal RSSI del dispositivo.
  final bool
      isLedOn; // Estado del LED del dispositivo (true: encendido, false: apagado).

  const DeviceTile({
    super.key,
    required this.device,
    this.onConnect,
    this.onDisconnect,
    this.onToggleLed,
    required this.isConnected,
    required this.rssi,
    this.isLedOn = false, // Valor por defecto si no se especifica.
  });

  @override
  Widget build(BuildContext context) {
    // Obtiene el nombre del dispositivo, usando 'Nombre Desconocido' si está vacío.
    final deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : 'Nombre Desconocido';

    return ListTile(
      leading: Icon(
        Icons.bluetooth,
        color: isConnected ? _connectedColor : _disconnectedColor,
      ),
      title: Text(
        deviceName,
        style: TextStyle(
          fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
          color: isConnected ? Colors.black87 : Colors.black54,
        ),
      ),
      subtitle: _RssiInfo(rssi: rssi), // Muestra la información del RSSI.
      trailing: Row(
        mainAxisSize:
            MainAxisSize.min, // Ajusta el tamaño de la fila al contenido.
        children: [
          // Botón para CONECTAR: visible solo si no está conectado y la callback `onConnect` existe.
          if (!isConnected && onConnect != null)
            IconButton(
              icon: const Icon(Icons.link, color: _actionButtonColor),
              onPressed: onConnect,
              tooltip: 'Conectar',
            ),
          // Botón para DESCONECTAR: visible solo si está conectado y la callback `onDisconnect` existe.
          if (isConnected && onDisconnect != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
              onPressed: onDisconnect,
              tooltip: 'Desconectar',
            ),
          // Botón para TOGGLE LED: visible solo si está conectado y la callback `onToggleLed` existe.
          // El icono y el color cambian según el estado `isLedOn`.
          if (isConnected && onToggleLed != null)
            IconButton(
              icon: Icon(
                isLedOn
                    ? Icons.lightbulb
                    : Icons
                        .lightbulb_outline, // lightbulb para encendido, lightbulb_outline para apagado
                color: isLedOn ? Colors.amber : Colors.grey,
              ),
              onPressed: onToggleLed,
              tooltip: isLedOn ? 'Apagar LED' : 'Encender LED',
            ),
          // Botón de INFO: siempre visible para mostrar detalles del dispositivo.
          IconButton(
            icon: const Icon(Icons.info, color: Colors.blueGrey),
            onPressed: () => _showDeviceDetails(context, device),
            tooltip: 'Detalles del dispositivo',
          ),
        ],
      ),
    );
  }
}

/// Widget interno para mostrar la información del RSSI.
/// Incluye un icono y un texto, con colores que indican la fuerza de la señal.
class _RssiInfo extends StatelessWidget {
  final int? rssi;

  const _RssiInfo({this.rssi});

  @override
  Widget build(BuildContext context) {
    String rssiText = rssi != null ? '$rssi dBm' : 'N/A';
    Color rssiColor = Colors.grey;
    IconData rssiIcon =
        FontAwesomeIcons.signal; // Icono por defecto de Font Awesome

    // Lógica para determinar el color y el icono del RSSI según su valor.
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

/// Función auxiliar para mostrar un diálogo con los detalles del dispositivo.
void _showDeviceDetails(BuildContext context, BluetoothDevice device) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Detalles del Dispositivo'),
      content: Text(
        'ID: ${device.remoteId.str}\nNombre: ${device.platformName}', // Tipo eliminado porque no existe la propiedad 'type'.
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
