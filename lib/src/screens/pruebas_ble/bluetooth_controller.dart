// import 'dart:math';

// import 'package:flutter/material.dart';
// //import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// class AddMedicalRecordScreen extends StatefulWidget {
//   const AddMedicalRecordScreen({super.key});

//   @override
//   State<AddMedicalRecordScreen> createState() => _AddMedicalRecordScreenState();
// }

// class _AddMedicalRecordScreenState extends State<AddMedicalRecordScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _nombreMascotaController =
//       TextEditingController();
//   final TextEditingController _nombreDuenoController = TextEditingController();
//   final TextEditingController _clinicalSignsController =
//       TextEditingController();
//   final TextEditingController _presumptiveDiagnosisController =
//       TextEditingController();
//   final TextEditingController _speciesController = TextEditingController();
//   final TextEditingController _sexController =
//       TextEditingController(); // Nuevo controlador para el sexo
//   final TextEditingController _ageController = TextEditingController();
//   final TextEditingController _weightController = TextEditingController();
//   final TextEditingController _bluetoothDataController =
//       TextEditingController();
//   //final SupabaseClient supabase = Supabase.instance.client;

//   // Variables para Bluetooth
//   List<ScanResult> scanResults = [];
//   BluetoothDevice? connectedDevice;
//   bool isScanning = false;
//   String bluetoothData = '';

//   @override
//   void initState() {
//     super.initState();
//     _checkBluetoothPermissions();
//   }

//   Future<void> _checkBluetoothPermissions() async {
//     var statusBluetooth = await Permission.bluetooth.status;
//     var statusLocation = await Permission.location.status;

//     if (!statusBluetooth.isGranted || !statusLocation.isGranted) {
//       await Permission.bluetooth.request();
//       await Permission.location.request();
//     }
//   }

//   Future<void> _checkBluetoothEnabled() async {
//     if (!await FlutterBluePlus.isSupported) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: const Text(
//             'Bluetooth no es compatible con este dispositivo',
//             style: TextStyle(color: Colors.white),
//           ),
//           backgroundColor: Color.fromARGB(255, 117, 34, 34),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           elevation: 6,
//           duration: const Duration(seconds: 3),
//         ));
//       }
//       return;
//     }

//     final adapterState = await FlutterBluePlus.adapterState.first;
//     if (adapterState != BluetoothAdapterState.on) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: const Text(
//             'Por favor, habilita el Bluetooth',
//             style: TextStyle(color: Colors.white),
//           ),
//           backgroundColor: Color.fromARGB(255, 117, 34, 34),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           elevation: 6,
//           duration: const Duration(seconds: 3),
//         ));
//       }
//       return;
//     }
//   }

//   void _startBluetoothScan() async {
//     await _checkBluetoothEnabled();

//     setState(() {
//       isScanning = true;
//       scanResults.clear();
//     });

//     // Configuración correcta para el escaneo
//     FlutterBluePlus.startScan(
//       timeout: const Duration(seconds: 15),
//       withServices: [], // Lista de UUIDs de servicios a filtrar (vacía para todos)
//       androidUsesFineLocation: true, // Necesario para Android 10+
//     );

//     FlutterBluePlus.scanResults.listen((results) {
//       if (mounted) {
//         setState(() {
//           scanResults = results;
//           // Debug: Imprime los nombres encontrados
//           for (var r in results) {
//             log('Dispositivo: ${r.device.platformName} MAC: ${r.device.remoteId}'
//                 as num);
//           }
//         });
//       }
//     });

//     Future.delayed(const Duration(seconds: 15), () {
//       FlutterBluePlus.stopScan();
//       if (mounted) {
//         setState(() => isScanning = false);
//       }
//     });
//   }

//   Future<void> _connectToDevice(BluetoothDevice device) async {
//     await device.connect();
//     if (mounted) {
//       setState(() => connectedDevice = device);
//     }

//     List<BluetoothService> services = await device.discoverServices();
//     for (BluetoothService service in services) {
//       for (BluetoothCharacteristic characteristic in service.characteristics) {
//         if (characteristic.properties.read) {
//           List<int> value = await characteristic.read();
//           if (mounted) {
//             log('Datos crudos recibidos: ${String.fromCharCodes(value)}'
//                 as num);
//             setState(() {
//               bluetoothData = cleanString(String.fromCharCodes(value));
//             });
//             _processBluetoothData(bluetoothData);
//           }
//         }
//       }
//     }
//   }

//   String cleanString(String input) {
//     return input.replaceAll(RegExp(r'[^0-9.mg/dL]'), '');
//   }

//   void _processBluetoothData(String data) {
//     List<String> parts = data.split(',');
//     if (parts.length == 7) {
//       _nombreMascotaController.text = parts[0];
//       _nombreDuenoController.text = parts[1];
//       _clinicalSignsController.text = parts[2];
//       _presumptiveDiagnosisController.text = parts[3];
//       _speciesController.text = parts[4];
//       _ageController.text = parts[5];
//       _weightController.text = parts[6];
//       _bluetoothDataController.clear();
//     }
//   }

//   Future<void> _guardarHistorial() async {
//     if (_formKey.currentState!.validate()) {
//       try {
//         //final user = supabase.auth.currentUser;
//         // if (user == null) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: const Text('No hay un usuario autenticado'),
//               backgroundColor: Color.fromARGB(255, 117, 34, 34),
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               elevation: 6,
//             ),
//           );
//           // }
//           return;
//         }

//         // await supabase.from('medical_records').insert({
//         //   'pet_name': _nombreMascotaController.text,
//         //   'owner_name': _nombreDuenoController.text,
//         //   'clinical_signs': _clinicalSignsController.text,
//         //   'presumptive_diagnosis': _presumptiveDiagnosisController.text,
//         //   'species': _speciesController.text,
//         //   'sex': _sexController.text,
//         //   'age': int.tryParse(_ageController.text) ?? 0,
//         //   'weight': double.tryParse(_weightController.text) ?? 0.0,
//         //   'bluetooth_data': cleanedBluetoothData,
//         //   'created_at': DateTime.now().toIso8601String(),
//         //   //'user_id': user.id,
//         // });

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: const Text(
//                 'Historial guardado correctamente',
//                 style: TextStyle(color: Colors.white),
//               ),
//               backgroundColor: Color.fromARGB(255, 117, 34, 34),
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               elevation: 6,
//               duration: const Duration(seconds: 3),
//             ),
//           );

//           _nombreMascotaController.clear();
//           _nombreDuenoController.clear();
//           _clinicalSignsController.clear();
//           _presumptiveDiagnosisController.clear();
//           _speciesController.clear();
//           _sexController.clear();
//           _ageController.clear();
//           _weightController.clear();
//           _bluetoothDataController.clear();
//           setState(() => bluetoothData = '');
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Error: ${e.toString()}'),
//               backgroundColor: Color.fromARGB(255, 117, 34, 34),
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               elevation: 6,
//             ),
//           );
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color.fromARGB(255, 250, 220, 220),
//       appBar: AppBar(
//         title: const Text('Agregar Historial Médico',
//             style: TextStyle(color: Colors.white)),
//         backgroundColor: Color.fromARGB(255, 117, 34, 34),
//         iconTheme:
//             IconThemeData(color: const Color.fromARGB(255, 250, 220, 220)),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               Card(
//                 color: const Color.fromARGB(255, 250, 220, 220),
//                 elevation: 2.0,
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: Column(
//                     children: [
//                       const Text('Conexión Bluetooth',
//                           style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               color: Color.fromARGB(255, 117, 34, 34))),
//                       const SizedBox(height: 10),
//                       ElevatedButton(
//                         onPressed: isScanning ? null : _startBluetoothScan,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Color.fromARGB(255, 117, 34, 34),
//                           foregroundColor:
//                               const Color.fromARGB(255, 255, 255, 255),
//                         ),
//                         child: Text(isScanning
//                             ? 'Escaneando...'
//                             : 'Buscar Dispositivos Bluetooth'),
//                       ),
//                       const SizedBox(height: 10),
//                       if (scanResults.isNotEmpty)
//                         SizedBox(
//                           height: 150,
//                           child: ListView.builder(
//                             itemCount: scanResults.length,
//                             itemBuilder: (context, index) {
//                               final device = scanResults[index].device;
//                               return ListTile(
//                                 title: Text(
//                                   device.platformName.isNotEmpty
//                                       ? device.platformName
//                                       : 'Dispositivo sin nombre', // Fallback si no hay nombre
//                                   style: TextStyle(
//                                       color: Color.fromARGB(255, 117, 34, 34)),
//                                 ),
//                                 subtitle: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(device.remoteId.toString()),
//                                     if (device.platformName.isNotEmpty)
//                                       Text('Nombre: ${device.platformName}'),
//                                   ],
//                                 ),
//                                 trailing:
//                                     connectedDevice?.remoteId == device.remoteId
//                                         ? const Icon(Icons.check,
//                                             color: Colors.green)
//                                         : null,
//                                 onTap: () => _connectToDevice(device),
//                               );
//                             },
//                           ),
//                         ),
//                       if (bluetoothData.isNotEmpty)
//                         Text('Datos recibidos: $bluetoothData',
//                             style: TextStyle(color: Colors.green[700])),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _nombreDuenoController,
//                 decoration: InputDecoration(
//                     labelText: 'Nombre del Dueño',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.person,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//               ),
//               const SizedBox(height: 30),
//               TextFormField(
//                 controller: _nombreMascotaController,
//                 decoration: InputDecoration(
//                     labelText: 'Nombre de la Mascota',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.pets,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _clinicalSignsController,
//                 decoration: InputDecoration(
//                     labelText: 'Signos Clínicos',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.medical_services,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _speciesController,
//                 decoration: InputDecoration(
//                     labelText: 'Raza',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.pets,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _sexController,
//                 decoration: InputDecoration(
//                     labelText: 'Sexo',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.people,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _ageController,
//                 decoration: InputDecoration(
//                     labelText: 'Edad (años)',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.calendar_today,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                 keyboardType: TextInputType.number,
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _weightController,
//                 decoration: InputDecoration(
//                     labelText: 'Peso (kg)',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.monitor_weight,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                 keyboardType: TextInputType.number,
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _presumptiveDiagnosisController,
//                 decoration: InputDecoration(
//                     labelText: 'Diagnóstico Presuntivo',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.assignment,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _bluetoothDataController,
//                 decoration: InputDecoration(
//                     labelText: 'Datos de Bluetooth (Manual)',
//                     labelStyle:
//                         TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//                     prefixIcon: Icon(Icons.bluetooth,
//                         color: Color.fromARGB(255, 117, 34, 34))),
//                 style: TextStyle(color: Color.fromARGB(255, 117, 34, 34)),
//               ),
//               const SizedBox(height: 30),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Color.fromARGB(255, 117, 34, 34),
//                   foregroundColor: const Color.fromARGB(255, 255, 255, 255),
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
//                 ),
//                 onPressed: _guardarHistorial,
//                 child: const Text('Guardar Historial',
//                     style: TextStyle(fontSize: 16)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     FlutterBluePlus.stopScan();
//     _nombreMascotaController.dispose();
//     _nombreDuenoController.dispose();
//     _clinicalSignsController.dispose();
//     _presumptiveDiagnosisController.dispose();
//     _speciesController.dispose();
//     _sexController.dispose();
//     _ageController.dispose();
//     _weightController.dispose();
//     _bluetoothDataController.dispose();
//     super.dispose();
//   }
// }
