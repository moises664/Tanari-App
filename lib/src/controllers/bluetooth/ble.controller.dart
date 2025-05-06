import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tanari_app/src/controllers/services/permissions_service.dart';
import 'package:logger/logger.dart';

class FoundDevice {
  final BluetoothDevice device;
  final int? rssi;

  FoundDevice(this.device, this.rssi);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoundDevice &&
          runtimeType == other.runtimeType &&
          device.remoteId == other.device.remoteId;

  @override
  int get hashCode => device.remoteId.hashCode;

  @override
  String toString() {
    return 'FoundDevice{device: ${device.platformName}, id: ${device.remoteId}, rssi: $rssi}';
  }
}

class BleController extends GetxController {
  // UUIDs del servicio y características
  static const serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const characteristicUuidUGV = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const characteristicUuidPortableNotify =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  // Estados reactivos (observables)
  final foundDevices = <FoundDevice>[].obs;
  final connectedDevices = <String, BluetoothDevice>{}.obs;
  final connectedCharacteristics = <String, BluetoothCharacteristic>{}.obs;
  final isScanning = false
      .obs; // Usar RxBool para manejar el estado de escaneo de forma reactiva
  final ledStateUGV = false.obs;
  final portableData = <String, dynamic>{}.obs;
  final rssiValues = <String, int?>{}.obs;

  // Subscripciones y timers
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final _connectionSubscriptions =
      <String, StreamSubscription<BluetoothConnectionState>>{};
  final _valueSubscriptions = <String, StreamSubscription<List<int>>>{};
  final _rssiTimers = <String, Timer>{};
  final Logger _logger = Logger();

  // Dispositivos específicos
  String? ugvDeviceId;
  BluetoothCharacteristic? ugvCharacteristic;
  String? portableDeviceId;
  BluetoothCharacteristic? portableCharacteristic;

  // Verifica si un dispositivo está conectado
  bool isDeviceConnected(String deviceId) =>
      connectedDevices.containsKey(deviceId) &&
      // ignore: unrelated_type_equality_checks
      (connectedDevices[deviceId]?.connectionState ==
          BluetoothConnectionState.connected);

  @override
  void onInit() {
    super.onInit();
    _checkPermissions();
  }

  // Verifica y solicita los permisos necesarios.
  Future<void> _checkPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        _logger.i(
            "Android SDK Version: ${androidInfo.version.sdkInt}"); // Agregado logging
        if (androidInfo.version.sdkInt <= 30) {
          // Para Android <= 11, se necesita locationWhenInUse
          final locationStatus = await Permission.locationWhenInUse.request();
          if (locationStatus != PermissionStatus.granted) {
            _logger.e(
                "Permiso de ubicación denegado para Android ${androidInfo.version.sdkInt}");
            Get.snackbar("Error",
                "Se requiere permiso de ubicación para usar Bluetooth.");
            return;
          }
        } else {
          // Para Android 12 y superior, se necesitan permisos de Bluetooth específicos
          final bluetoothScanStatus = await Permission.bluetoothScan.request();
          final bluetoothConnectStatus =
              await Permission.bluetoothConnect.request();

          if (bluetoothScanStatus != PermissionStatus.granted ||
              bluetoothConnectStatus != PermissionStatus.granted) {
            _logger.e(
                "Permisos de Bluetooth Scan/Connect denegados para Android ${androidInfo.version.sdkInt}");
            Get.snackbar("Error",
                "Se requieren permisos de Bluetooth para escanear y conectar.");
            return;
          }
        }
      } else if (Platform.isIOS) {
        // En iOS, solo se necesita el permiso de Bluetooth
        final bluetoothStatus = await Permission.bluetooth.request();
        if (bluetoothStatus != PermissionStatus.granted) {
          _logger.e("Permiso de Bluetooth denegado para iOS");
          Get.snackbar("Error", "Se requiere permiso de Bluetooth.");
          return;
        }
      }
      // Verifica permisos de Bluetooth usando el servicio de permisos
      final blePermissionsGranted =
          await PermissionsService.requestBlePermissions();
      if (!blePermissionsGranted) {
        _logger.e("Permisos de Bluetooth denegados");
        Get.snackbar("Error", "Permisos de Bluetooth denegados.");
        return;
      }
    } catch (e) {
      _logger.e("Error en _checkPermissions: ${e.toString()}");
      Get.snackbar("Error", "Error en permisos: ${e.toString()}");
    }
  }

  // Inicia el escaneo de dispositivos BLE
  Future<void> startScan() async {
    if (isScanning.value) {
      _logger.i("Escaneo ya en curso.");
      return;
    }
    try {
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        _logger.i("Bluetooth is off, turning it on...");
        try {
          await FlutterBluePlus.turnOn(
              timeout: const Duration(seconds: 10).inMilliseconds);
          state = await FlutterBluePlus.adapterState
              .firstWhere((s) => s == BluetoothAdapterState.on);
          _logger.i("Bluetooth is now on.");
        } on TimeoutException {
          Get.snackbar("Error", "Bluetooth no se activó a tiempo.");
          isScanning.value = false;
          return;
        } catch (e) {
          _logger.e("Error al encender Bluetooth: $e");
          Get.snackbar("Error", "Error al encender Bluetooth: $e");
          isScanning.value = false;
          return;
        }
      }

      isScanning.value = true;
      _logger.i("Iniciando escaneo BLE...");

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final newDevices =
            results.map((r) => FoundDevice(r.device, r.rssi)).toSet().toList();
        //Log the devices found
        for (var newDevice in newDevices) {
          _logger.i(
              "Dispositivo encontrado: ${newDevice.device.platformName} (${newDevice.device.remoteId}), RSSI: ${newDevice.rssi}");
        }
        foundDevices.assignAll(newDevices);
      }, onError: (e) {
        _logger.e("Error durante el escaneo: $e");
        Get.snackbar("Error", "Error durante el escaneo: $e");
        isScanning.value = false;
      }, onDone: () {
        isScanning.value = false;
        _logger.i("Escaneo finalizado.");
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [Guid(serviceUuid)],
      );
    } catch (e) {
      _logger.e("Error en startScan: ${e.toString()}");
      Get.snackbar("Error", e.toString());
      isScanning.value = false;
    }
  }

  // Detiene el escaneo de dispositivos BLE
  void stopScan() {
    if (!isScanning.value) return;
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _rssiTimers.forEach((key, timer) => timer.cancel());
    isScanning.value = false;
    _logger.i("Escaneo detenido.");
  }

  // Conecta a un dispositivo BLE
  Future<void> connectToDevice(FoundDevice foundDevice) async {
    final deviceId = foundDevice.device.remoteId.str;
    if (connectedDevices.containsKey(deviceId)) {
      Get.snackbar("Info", "Dispositivo ya conectado.");
      return;
    }
    try {
      final device = foundDevice.device;
      await device.connect(timeout: const Duration(seconds: 15));
      connectedDevices[deviceId] = device;
      _monitorConnectionState(device);
      await _discoverServices(device);
      _startRssiUpdates(device);
    } catch (e) {
      _logger.e(
          "Error al conectar: $e. Dispositivo: ${foundDevice.device.platformName} (${foundDevice.device.remoteId})");
      Get.snackbar("Error", "Error al conectar: $e");
      _cleanupDeviceConnection(deviceId);
    }
  }

  // Descubre los servicios y características de un dispositivo
  Future<void> _discoverServices(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    try {
      final services = await device.discoverServices();
      if (services.isEmpty) {
        _logger.w(
            "No se encontraron servicios para el dispositivo: ${device.platformName} (${device.remoteId})");
        Get.snackbar(
            "Advertencia", "No se encontraron servicios para el dispositivo.");
        disconnectDevice(deviceId);
        return;
      }
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          for (BluetoothCharacteristic char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            if (charUuid == characteristicUuidUGV) {
              ugvCharacteristic = char;
              connectedCharacteristics[deviceId] = char;
              _setupNotifications(deviceId, char);
              _logger.i('Característica UGV encontrada: ${char.uuid}');
            } else if (charUuid == characteristicUuidPortableNotify) {
              portableCharacteristic = char;
              connectedCharacteristics[deviceId] = char;
              _setupNotifications(deviceId, char);
              _logger.i('Característica Portátil encontrada: ${char.uuid}');
            }
          }
        }
      }
      if (ugvCharacteristic == null && portableCharacteristic == null) {
        _logger.w(
            "No se encontraron las características requeridas para el dispositivo: ${device.platformName} (${device.remoteId})");
        Get.snackbar(
            "Advertencia", "No se encontraron las características requeridas.");
        disconnectDevice(deviceId);
      }
    } catch (e) {
      _logger.e("Error al descubrir servicios: $e");
      Get.snackbar("Error", "Error al descubrir servicios: $e");
      disconnectDevice(deviceId);
    }
  }

  // Configura las notificaciones para una característica
  void _setupNotifications(
      String deviceId, BluetoothCharacteristic characteristic) {
    _valueSubscriptions[deviceId]?.cancel();
    try {
      characteristic.setNotifyValue(true);
      _valueSubscriptions[deviceId] =
          characteristic.onValueReceived.listen((value) {
        final charUuid = characteristic.uuid.toString().toLowerCase();
        if (charUuid == characteristicUuidPortableNotify) {
          final dataString = String.fromCharCodes(value);
          portableData.value = {'raw': dataString};
          _logger.i('Datos del Portátil ($deviceId): $dataString');
        } else if (charUuid == characteristicUuidUGV) {
          ledStateUGV.value = value.isNotEmpty && value[0] == 1;
          _logger.i('Estado del UGV ($deviceId): ${value[0]}');
        }
      }, onError: (error) {
        _logger.e("Error en _setupNotifications: $error");
        Get.snackbar("Error", "Error en la recepción de datos: $error");
      });
    } catch (e) {
      _logger.e("Error al configurar notificaciones: $e");
      Get.snackbar("Error", "Error al configurar notificaciones: $e");
      disconnectDevice(deviceId);
    }
  }

  // Envía datos a un dispositivo BLE
  Future<void> sendData(String deviceId, String data) async {
    if (!isDeviceConnected(deviceId)) {
      Get.snackbar("Error", "Dispositivo no conectado");
      return;
    }
    final characteristic = connectedCharacteristics[deviceId];
    if (characteristic == null) {
      Get.snackbar("Error", "Característica no encontrada");
      return;
    }
    try {
      await characteristic.write(data.codeUnits, withoutResponse: true);
      _logger.i('Dato enviado a $deviceId: $data');
      if (characteristic.uuid.toString().toLowerCase() ==
          characteristicUuidUGV) {
        ledStateUGV.value = data == 'H';
      }
    } catch (e) {
      _logger.e("Error al enviar datos: $e");
      Get.snackbar("Error", "Error al enviar datos: $e");
      _cleanupDeviceConnection(deviceId);
    }
  }

  // Inicia la lectura periódica del RSSI de un dispositivo
  void _startRssiUpdates(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    _rssiTimers[deviceId] =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        if (isDeviceConnected(deviceId)) {
          final rssiValue = await device.readRssi();
          rssiValues[deviceId] = rssiValue;
          final index = foundDevices.indexWhere((d) => d.device == device);
          if (index != -1) {
            foundDevices[index] = FoundDevice(device, rssiValue);
          }
          _logger.i('RSSI de ${device.platformName}: $rssiValue');
        }
      } catch (e) {
        _logger.e('Error RSSI: $e');
      }
    });
  }

  // Monitorea el estado de la conexión de un dispositivo
  void _monitorConnectionState(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    _connectionSubscriptions[deviceId] = device.connectionState.listen((state) {
      _logger.i('Estado de conexión de ${device.platformName}: $state');
      if (state == BluetoothConnectionState.disconnected) {
        _cleanupDeviceConnection(deviceId);
        Get.snackbar("Info", "${device.platformName} desconectado");
      }
    }, onError: (error) {
      _logger.e("Error en _monitorConnectionState: $error");
      Get.snackbar("Error", "Error en la conexión del dispositivo: $error");
      _cleanupDeviceConnection(deviceId);
    });
  }

  // Limpia el estado de la conexión de un dispositivo
  void _cleanupDeviceConnection(String deviceId) {
    _logger.i('Limpiando conexión para el dispositivo: $deviceId');
    _rssiTimers[deviceId]?.cancel();
    _valueSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions[deviceId]?.cancel();
    connectedDevices.remove(deviceId);
    connectedCharacteristics.remove(deviceId);
    rssiValues.remove(deviceId);
    if (connectedDevices.isEmpty) {
      ledStateUGV.value = false;
    }
  }

  // Desconecta un dispositivo BLE
  void disconnectDevice(String deviceId) async {
    if (connectedDevices.containsKey(deviceId)) {
      try {
        await connectedDevices[deviceId]?.disconnect();
        _cleanupDeviceConnection(deviceId);
        final deviceName =
            connectedDevices[deviceId]?.platformName ?? "Dispositivo";
        Get.snackbar("Info", "$deviceName desconectado");
      } catch (e) {
        _logger.e("Error al desconectar el dispositivo: $e");
        Get.snackbar("Error", "Error al desconectar el dispositivo: $e");
        _cleanupDeviceConnection(deviceId);
      }
    }
  }

  @override
  void onClose() {
    _logger.i('Cerrando BleController...');
    stopScan();
    _rssiTimers.forEach((key, timer) => timer.cancel());
    _valueSubscriptions.forEach((key, sub) => sub.cancel());
    _connectionSubscriptions.forEach((key, sub) => sub.cancel());
    connectedDevices.forEach((key, device) => device.disconnect());
    connectedDevices.clear();
    super.onClose();
  }
}
