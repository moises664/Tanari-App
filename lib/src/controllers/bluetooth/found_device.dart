import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Clase para encapsular un dispositivo Bluetooth encontrado durante el escaneo,
/// incluyendo su RSSI y su estado de conexión.
class FoundDevice {
  final BluetoothDevice device;
  final int? rssi;
  final bool isConnected;

  FoundDevice(this.device, this.rssi, {this.isConnected = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoundDevice &&
          runtimeType == other.runtimeType &&
          device.remoteId == other.device.remoteId;

  @override
  int get hashCode => device.remoteId.hashCode;

  // Método para crear una copia con un nuevo RSSI o estado de conexión
  FoundDevice copyWith({int? rssi, bool? isConnected}) {
    return FoundDevice(device, rssi ?? this.rssi,
        isConnected: isConnected ?? this.isConnected);
  }
}
