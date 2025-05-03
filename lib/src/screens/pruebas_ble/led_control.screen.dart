// import 'dart:async';
// import 'dart:io';
// import 'package:android_intent_plus/android_intent.dart';
// import 'package:flutter/material.dart';
// import 'package:tanary_app/main.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:tanary_app/src/controllers/bluetooth/ble_controller.dart';
// import 'package:tanary_app/src/widgets/connection_panel.dart';
// import 'package:tanary_app/src/widgets/device_title.dart';
// import 'package:workmanager/workmanager.dart';

// class LedControlScreen extends StatefulWidget {
//   const LedControlScreen({super.key});

//   @override
//   State<LedControlScreen> createState() => _LedControlScreenState();
// }

// class _LedControlScreenState extends State<LedControlScreen> {
//   // Cambiamos la inicialización del controller
//   final BleController _bleController = BleController();
//   bool _isConnecting = false;

//   @override
//   void initState() {
//     super.initState();
//     _initialize();
//     _initializeWorkManager();
//     _setupConnectionListener(); // Inicializa la suscripción
//   }

//   Future<void> _initialize() async {
//     await _bleController.checkPermissions();
//     if (_bleController.connectedDevice.value == null) {
//       await _bleController.startScan();
//     }
//   }

//   void _initializeWorkManager() {
//     Workmanager().initialize(
//       callbackDispatcher, // Referencia a la función definida en main.dart
//       isInDebugMode: false,
//     );
//   }

//   // En _LedControlScreenState
//   void _setupConnectionListener() {
//     _bleController.connectedDevice.addListener(_updateState);
//   }

//   void _updateState() {
//     if (mounted) setState(() {});
//   }

//   @override
//   void dispose() {
//     _bleController.connectedDevice.removeListener(_updateState); // Añade esto
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: const Text('Control LED'),
//           actions: [
//             ValueListenableBuilder<bool>(
//               valueListenable: _bleController.isScanning,
//               builder: (context, isScanning, _) {
//                 return IconButton(
//                   icon: _buildScanButtonIcon(),
//                   onPressed: _handleScanButtonPress,
//                 );
//               },
//             ),
//           ],
//           backgroundColor: Colors.lightGreenAccent,
//         ),
//         body: ValueListenableBuilder<BluetoothDevice?>(
//           valueListenable: _bleController.connectedDevice,
//           builder: (context, connectedDevice, _) {
//             return Column(
//               children: [
//                 if (connectedDevice != null)
//                   ConnectionPanel(
//                     device: connectedDevice,
//                     rssi: _bleController.rssiValue.value,
//                     onDisconnect: _disconnectDevice,
//                   ),
//                 Expanded(child: _buildDeviceList()),
//               ],
//             );
//           },
//         ),
//         floatingActionButton: _buildFloatingButton());
//   }

//   // Modificamos el botón flotante
//   Widget _buildFloatingButton() {
//     return ValueListenableBuilder<bool>(
//       valueListenable: _bleController.ledState,
//       builder: (context, ledOn, _) {
//         return FloatingActionButton(
//           onPressed: _bleController.connectedDevice.value != null
//               ? () => _bleController.toggleLed(!ledOn)
//               : null, // Botón visible pero desactivado
//           backgroundColor: ledOn ? Colors.green : Colors.red,
//           child: Icon(ledOn ? Icons.power : Icons.power_off),
//         );
//       },
//     );
//   }

//   Widget _buildDeviceList() {
//     return ValueListenableBuilder<List<BluetoothDevice>>(
//       valueListenable: _bleController.foundDevices,
//       builder: (context, devices, _) {
//         return ListView.builder(
//           itemCount: devices.length,
//           itemBuilder: (context, index) => DeviceTile(
//             device: devices[index],
//             isConnecting: _isConnecting,
//             onConnect: () => _connectDevice(devices[index]),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildScanButtonIcon() {
//     final bool isDisabled = _bleController.isScanning.value || _isConnecting;
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         Icon(
//           _bleController.isScanning.value ? Icons.stop : Icons.search,
//           color: isDisabled
//               ? Colors.grey
//               : _bleController.isScanning.value
//                   ? Colors.red
//                   : Colors.blue,
//         ),
//         if (_bleController.isScanning.value)
//           Positioned(
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.all(2),
//               decoration: BoxDecoration(
//                 color: Colors.red,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: const Text(
//                 'ESCANEANDO',
//                 style: TextStyle(fontSize: 8, color: Colors.white),
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   void _handleScanButtonPress() async {
//     try {
//       if (_bleController.isScanning.value) {
//         await _bleController.stopScan();
//       } else {
//         await _bleController.startScan();
//       }
//       if (mounted) setState(() {});
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(e.toString().replaceAll("Exception: ", "")),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _connectDevice(BluetoothDevice device) async {
//     if (_isConnecting) return;

//     setState(() => _isConnecting = true);
//     try {
//       await _bleController.connectToDevice(device);
//       if (mounted) setState(() {});
//     } on Exception catch (e) {
//       // Captura específicamente Exception
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(e.toString()),
//             backgroundColor: Colors.red,
//             action: SnackBarAction(
//               label: "Abrir ajustes",
//               onPressed: () => openBluetoothSettings(), // Método adicional
//             ),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isConnecting = false);
//     }
//   }

// // Añade este método para abrir ajustes de Bluetooth
//   void openBluetoothSettings() {
//     if (Platform.isAndroid) {
//       // Usar android_intent
//       const intent =
//           AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS');
//       intent.launch();
//     } else {
//       // Usar url_launcher para iOS (ajustes generales)
//       launchUrl(Uri.parse('app-settings:'));
//     }
//   }

//   Future<void> _disconnectDevice() async {
//     await _bleController.disconnectDevice();
//     if (mounted) setState(() {});
//   }
// }
