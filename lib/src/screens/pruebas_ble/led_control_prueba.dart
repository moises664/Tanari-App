// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';

// class LedControlScreen extends StatefulWidget {
//   const LedControlScreen({super.key});

//   @override
//   State<LedControlScreen> createState() => _LedControlScreenState();
// }

// class _LedControlScreenState extends State<LedControlScreen> {
//   // UUIDs del servicio y característica BLE
//   static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
//   static const String characteristicUuid =
//       "beb5483e-36e1-4688-b7f5-ea07361b26a8";

//   // Estado de dispositivos, conexión, y LED
//   List<BluetoothDevice> _foundDevices = [];
//   BluetoothDevice? _connectedDevice;
//   BluetoothCharacteristic? _ledCharacteristic;
//   bool _isScanning = false;
//   bool _ledState = false;
//   int? _rssi;
//   StreamSubscription<List<int>>? _valueSubscription;
//   StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
//   StreamSubscription<List<ScanResult>>? _scanSubscription;
//   Timer? _rssiTimer;

//   @override
//   void initState() {
//     super.initState();
//     _checkPermissions(); // Solicita permisos al iniciar
//   }

//   Future<void> _checkPermissions() async {
//     await [
//       Permission.bluetooth,
//       Permission.bluetoothConnect,
//       Permission.bluetoothScan,
//       Permission.locationWhenInUse
//     ].request();
//   }

//   //  Escaneo de Dispositivo
//   void _startScan() async {
//     if (!await FlutterBluePlus.isSupported || _isScanning) return;

//     _scanSubscription?.cancel(); // <- Cancela suscripción previa

//     setState(() {
//       _isScanning = true;
//       _foundDevices.clear();
//     });

//     // Cancela cualquier suscripción previa
//     _scanSubscription?.cancel();

//     // Almacena la nueva suscripción
//     _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
//       if (!mounted) return;
//       setState(() {
//         _isScanning = true;
//         _foundDevices.clear();
//       });
//     });

//     FlutterBluePlus.startScan(
//       timeout: const Duration(seconds: 10),
//       withServices: [Guid(serviceUuid)],
//     );

//     FlutterBluePlus.scanResults.listen((results) {
//       if (!mounted) return;
//       setState(() {
//         _foundDevices = results
//             .where((r) => r.device.platformName.isNotEmpty)
//             .map((r) => r.device)
//             .toList();
//       });
//     });

//     await Future.delayed(const Duration(seconds: 10));
//     FlutterBluePlus.stopScan();
//     if (mounted) setState(() => _isScanning = false);
//   }

//   // Busca la conexion con el Dispositivo
//   Future<void> _connectToDevice(BluetoothDevice device) async {
//     try {
//       await device.connect(autoConnect: false);

//       final services = await device.discoverServices();
//       final service = services.firstWhere(
//         (s) => s.serviceUuid == Guid(serviceUuid),
//         orElse: () => throw Exception('Servicio no encontrado'),
//       );

//       _ledCharacteristic = service.characteristics.firstWhere(
//         (c) => c.characteristicUuid == Guid(characteristicUuid),
//         orElse: () => throw Exception('Característica no encontrada'),
//       );

//       _setupNotifications(); // Configura notificaciones para recibir actualizacios del objeto
//       _startRssiUpdates(device);
//       _monitorConnectionState(device);

//       if (mounted) {
//         setState(() {
//           _connectedDevice = device;
//           _ledState = false;
//         });
//       }

//       // Leer estado inicial
//       final initialValue = await _ledCharacteristic!.read();
//       if (initialValue.isNotEmpty && mounted) {
//         // <- Añade mounted
//         setState(() => _ledState = initialValue[0] == 1);
//       }
//     } catch (e) {
//       _showError('Error de conexión: ${e.toString()}');
//       //await device.disconnect();
//       _cleanupConnection();
//     }
//   }

//   void _setupNotifications() {
//     _valueSubscription = _ledCharacteristic!.onValueReceived.listen((value) {
//       if (!mounted || value.isEmpty) return; // Combina condicion
//       if (value.isNotEmpty && mounted) {
//         setState(() => _ledState = value[0] == 1);
//       }
//     });
//     _ledCharacteristic!.setNotifyValue(true);
//   }

//   void _startRssiUpdates(BluetoothDevice device) {
//     _rssiTimer?.cancel();
//     _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
//       if (!mounted) return; // <-- Añade esta línea
//       try {
//         final rssi = await device.readRssi();
//         if (mounted) setState(() => _rssi = rssi);
//       } catch (e) {
//         debugPrint('Error RSSI: $e');
//       }
//     });
//   }

//   void _monitorConnectionState(BluetoothDevice device) {
//     _connectionSubscription = device.connectionState.listen((state) {
//       if (state == BluetoothConnectionState.disconnected && mounted) {
//         _cleanupConnection();
//         _showError('Desconectado');
//       }
//     });
//   }

//   // Control del LED
//   Future<void> _toggleLed() async {
//     if (_ledCharacteristic == null) return;

//     try {
//       final newState = !_ledState;
//       await _ledCharacteristic!.write([newState ? 1 : 0],
//           withoutResponse: false,
//           timeout: const Duration(seconds: 2).inMilliseconds);

//       // Actualizar estado local solo después de confirmación
//       if (mounted) {
//         setState(() => _ledState = newState);
//       }
//     } catch (e) {
//       _showError('Error de comunicación: ${e.toString()}');
//       _cleanupConnection();
//     }
//   }

//   Future<void> _disconnectDevice() async {
//     await _connectedDevice?.disconnect();
//     _cleanupConnection();
//   }

//   void _cleanupConnection() {
//     _rssiTimer?.cancel();
//     _valueSubscription?.cancel();
//     _connectionSubscription?.cancel();

//     if (mounted) {
//       setState(() {
//         _connectedDevice = null;
//         _ledState = false;
//         _rssi = null;
//       });
//     }
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(message),
//       backgroundColor: Colors.red,
//       duration: const Duration(seconds: 3),
//     ));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: const Text('Control LED ESP32-S3'),
//           actions: [
//             IconButton(
//               icon: Icon(_isScanning ? Icons.stop : Icons.search),
//               onPressed: _isScanning ? null : _startScan,
//             )
//           ],
//         ),
//         body: _buildDeviceList(),
//         floatingActionButton: _buildLedControl());
//   }

//   Widget _buildDeviceList() {
//     return ListView(
//       padding: const EdgeInsets.all(20),
//       children: [
//         if (_connectedDevice != null) ...[
//           _ConnectionPanel(
//             device: _connectedDevice!,
//             rssi: _rssi,
//             onDisconnect: _disconnectDevice,
//           ),
//           const SizedBox(height: 20),
//         ],
//         ..._foundDevices.map((device) => _DeviceTile(
//               device: device,
//               onConnect: () => _connectToDevice(device),
//             )),
//       ],
//     );
//   }

//   Widget _buildLedControl() {
//     return FloatingActionButton.large(
//       onPressed: _connectedDevice != null ? _toggleLed : null,
//       backgroundColor: _ledState ? Colors.green : Colors.red,
//       tooltip: 'Control LED',
//       child: Icon(
//         _ledState ? Icons.power : Icons.power_off,
//         size: 36,
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _scanSubscription?.cancel(); // <- Cancela la suscripción
//     _valueSubscription?.cancel(); // Añade esto
//     _connectionSubscription?.cancel(); // Añade esto
//     _rssiTimer?.cancel(); // Añade esto
//     _cleanupConnection();
//     FlutterBluePlus.stopScan(); //  Limpia recursos al cerrar
//     super.dispose();
//   }
// }

// //  Muestra dispositivos encontrados con botón de conexión.
// class _DeviceTile extends StatelessWidget {
//   final BluetoothDevice device;
//   final VoidCallback onConnect;

//   const _DeviceTile({required this.device, required this.onConnect});

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       leading: const Icon(Icons.bluetooth),
//       title: Text(device.platformName),
//       subtitle: Text(device.remoteId.str),
//       trailing: IconButton(
//         icon: const Icon(Icons.link),
//         onPressed: onConnect,
//       ),
//     );
//   }
// }

// // Panel con información de conexión (RSSI, ID).
// class _ConnectionPanel extends StatelessWidget {
//   final BluetoothDevice device;
//   final int? rssi;
//   final VoidCallback onDisconnect;

//   const _ConnectionPanel({
//     required this.device,
//     required this.rssi,
//     required this.onDisconnect,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.all(8),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Text(
//               device.platformName,
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//             const SizedBox(height: 12),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 _InfoChip(
//                   icon: Icons.signal_cellular_alt,
//                   label: '${rssi?.toString() ?? '--'} dBm',
//                 ),
//                 _InfoChip(
//                   icon: Icons.bluetooth,
//                   label: device.remoteId.str.substring(15),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             OutlinedButton.icon(
//               icon: const Icon(Icons.bluetooth_disabled),
//               label: const Text('DESCONECTAR'),
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: Colors.red,
//                 side: const BorderSide(color: Colors.red),
//               ),
//               onPressed: onDisconnect,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// //Muestra datos como chips estilizados.
// class _InfoChip extends StatelessWidget {
//   final IconData icon;
//   final String label;

//   const _InfoChip({required this.icon, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Chip(
//       avatar: Icon(icon, size: 20),
//       label: Text(label),
//       backgroundColor: Colors.grey[200],
//     );
//   }
// }
