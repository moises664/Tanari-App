import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/controllers/services/permissions_service.dart'; // Importa el paquete logger

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
}

class BleController extends GetxController {
  // UUIDs
  static const serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const characteristicUuidUGV = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const characteristicUuidPortableNotify =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  // Comandos para el UGV
  static const String moveForward = 'F';
  static const String moveBack = 'B';
  static const String moveRight = 'R';
  static const String moveLeft = 'L';
  static const String stop = 'S';
  static const String startRecording = 'G';
  static const String stopRecording = 'N';
  static const String startAutoMode = 'A';

  // Estados reactivos
  final foundDevices = <FoundDevice>[].obs;
  final connectedDevices =
      <String, BluetoothDevice>{}.obs; // <deviceId, device>
  final connectedCharacteristics =
      <String, BluetoothCharacteristic>{}.obs; // <deviceId, characteristic>
  final isScanning = false.obs;
  final ledStateUGV =
      false.obs; // Estado del LED del UGV - Mover al mapa si es necesario
  final portableData =
      <String, dynamic>{}.obs; // Datos recibidos del dispositivo portátil
  final rssiValues = <String, int?>{}.obs; // <deviceId, rssi>
  final isRecording =
      false.obs; // Nuevo estado para indicar si se está grabando el recorrido

  // Subscripciones
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final _connectionSubscriptions =
      <String, StreamSubscription<BluetoothConnectionState>>{};
  final _valueSubscriptions = <String, StreamSubscription<List<int>>>{};
  final _rssiTimers = <String, Timer>{};
  final Logger _logger = Logger(); // Inicializa el logger

  // Variables para el UGV
  String? ugvDeviceId; // Almacena el ID del dispositivo UGV
  BluetoothCharacteristic?
      ugvCharacteristic; // Almacena la característica del UGV

  // Variables para el Portatil
  String? portableDeviceId;
  BluetoothCharacteristic? portableCharacteristic;

  bool isDeviceConnected(String deviceId) =>
      connectedDevices.containsKey(deviceId) &&
      (connectedDevices[deviceId]?.isConnected ?? false);

  @override
  void onInit() {
    super.onInit();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (Platform.isAndroid && androidInfo.version.sdkInt <= 30) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          Get.snackbar("Error", "Se requiere permiso de ubicación");
        }
      }

      // Solicita los permisos de BLE
      await PermissionsService.requestBlePermissions();
    } catch (e) {
      _logger.e("Error en permisos: ${e.toString()}"); // Usa el logger
      Get.snackbar("Error", "Error en permisos: ${e.toString()}");
    }
  }

  // Escaneo de Dispositivos
  Future<void> startScan() async {
    if (isScanning.value) {
      _logger.i("Escaneo ya en curso, retornando."); // Usa el logger
      return;
    }
    try {
      // Verificar estado inicial
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        FlutterBluePlus.turnOn(); // Abre configuración Bluetooth en Android

        // Espera máximo 15 segundos a que se active
        state = await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 15));
      }

      // Iniciar escaneo
      isScanning.value = true;
      _logger.i("Iniciando escaneo BLE..."); // Usa el logger
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _logger.i(
            "Se recibieron ${results.length} resultados de escaneo."); // Usa el logger
        final newDevices =
            results.map((r) => FoundDevice(r.device, r.rssi)).toSet().toList();
        // *** MODIFICACIÓN IMPORTANTE: ***
        // Asegurarse de que la lista observable se actualice correctamente.
        // `assignAll` notifica a los listeners (la UI) sobre el cambio.
        foundDevices.assignAll(newDevices);
        _logger.i(
            "Lista de dispositivos encontrados actualizada: ${foundDevices.value.length}"); // Usa el logger
        for (var device in foundDevices) {
          _logger.i(
              "Dispositivo encontrado: ${device.device.platformName} (${device.device.remoteId})"); // Usa el logger
        }
      }, onError: (e) {
        _logger.e("Error durante el escaneo: $e"); // Usa el logger
        isScanning.value = false;
        if (Get.isSnackbarOpen) {
          //check if a snackbar is already open
          Get.back();
        }
        Get.snackbar("Error", "Error durante el escaneo: $e");
      }, onDone: () {
        _logger.i("Escaneo BLE completado."); // Usa el logger
        isScanning.value = false;
      });
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(serviceUuid)], // Filtrar por el UUID de tu servicio
      );
      // No establecer isScanning a false aquí, se maneja en onDone y onError del listener
    } on TimeoutException {
      if (Get.isSnackbarOpen) {
        //check if a snackbar is already open
        Get.back();
      }
      Get.snackbar("Error", "El Bluetooth no se activó a tiempo");
      isScanning.value = false;
    } catch (e) {
      _logger.e("Error en startScan: ${e.toString()}"); // Usa el logger
      if (Get.isSnackbarOpen) {
        //check if a snackbar is already open
        Get.back();
      }
      Get.snackbar("Error", e.toString());
      isScanning.value = false;
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    for (final timer in _rssiTimers.values) {
      // Cancela los timers
      timer.cancel();
    }
    isScanning.value = false;
    _logger.i("Escaneo BLE detenido."); // Usa el logger
  }

  //  Conexión a Dispositivo
  Future<void> connectToDevice(FoundDevice foundDevice) async {
    final deviceId = foundDevice.device.remoteId.str;
    if (connectedDevices.containsKey(deviceId)) {
      Get.snackbar("Info", "Dispositivo ya conectado.");
      return;
    }

    BluetoothDevice? device;
    try {
      device = foundDevice.device;
      await device.connect(timeout: const Duration(seconds: 10));
      connectedDevices[deviceId] = device;
      _monitorConnectionState(device); //Monitorea el estado de la conexion
      await _discoverServices(
          device); //Descubre los servicios y caracteristicas
      _startRssiUpdates(device);
    } catch (e) {
      _logger.e("Error al conectar a ${device?.platformName ?? deviceId}: $e");
      if (Get.isSnackbarOpen) {
        //check if a snackbar is already open
        Get.back();
      }
      Get.snackbar("Error",
          "Error al conectar a ${device?.platformName ?? deviceId}: $e");
      _cleanupDeviceConnection(deviceId);
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid) {
        for (BluetoothCharacteristic char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == characteristicUuidUGV) {
            ugvCharacteristic =
                char; // Guarda la característica UGV en la variable de clase
            connectedCharacteristics[deviceId] = char;
            _setupNotifications(deviceId, char);
            _logger.i(
                'Característica UGV encontrada para ${device.platformName ?? deviceId}: ${char.uuid}');
          } else if (char.uuid.toString().toLowerCase() ==
              characteristicUuidPortableNotify) {
            portableCharacteristic = char;
            connectedCharacteristics[deviceId] = char;
            _setupNotifications(deviceId, char);
            _logger.i(
                'Característica de notificación portátil encontrada para ${device.platformName ?? deviceId}: ${char.uuid}');
          }
        }
      }
    }
  }

  void _setupNotifications(
      String deviceId, BluetoothCharacteristic characteristic) {
    _valueSubscriptions[deviceId]?.cancel();
    _valueSubscriptions[deviceId] =
        characteristic.onValueReceived.listen((value) {
      // Verificar si el dispositivo conectado corresponde a la característica.
      if (connectedDevices[deviceId] == characteristic.device) {
        // Corrected line
        if (characteristic.uuid.toString().toLowerCase() ==
            characteristicUuidPortableNotify) {
          // Procesar datos del dispositivo portátil (GEI)
          final dataString = String.fromCharCodes(value);
          // Aquí puedes parsear la cadena y actualizar portableData
          portableData.value = {'raw': dataString}; // Ejemplo básico
          _logger.i('Datos del portátil ($deviceId): $dataString');
        } else if (characteristic.uuid.toString().toLowerCase() ==
            characteristicUuidUGV) {
          // Puedes recibir feedback del UGV si lo implementas
          ledStateUGV.value = value.isNotEmpty && value[0] == 1;
          _logger.i('Datos del UGV ($deviceId): $value');
        }
      }
    }, onError: (error) {
      _logger.e("Error en _setupNotifications: $error");
      if (Get.isSnackbarOpen) {
        //check if a snackbar is already open
        Get.back();
      }
      Get.snackbar("Error", "Error en la recepción de datos: $error");
      _cleanupDeviceConnection(deviceId);
    });
    characteristic.setNotifyValue(true);
  }

  Future<void> sendData(String deviceId, String data) async {
    if (connectedDevices.containsKey(deviceId) &&
        (connectedDevices[deviceId]!.isConnected)) {
      // Corrected line
      final characteristic = connectedCharacteristics[deviceId];
      if (characteristic != null) {
        try {
          await characteristic.write(data.codeUnits, withoutResponse: true);
          _logger.i('Dato enviado a $deviceId: $data');
          // Actualiza el estado del LED solo si la característica es la del UGV
          if (characteristic.uuid.toString().toLowerCase() ==
                  characteristicUuidUGV &&
              (data == 'H' || data == 'L')) {
            ledStateUGV.value = data == 'H';
          }
        } catch (e) {
          _logger.e("Error al enviar datos a $deviceId: $e");
          if (Get.isSnackbarOpen) {
            //check if a snackbar is already open
            Get.back();
          }
          Get.snackbar("Error al enviar datos a $deviceId", e.toString());
          _cleanupDeviceConnection(deviceId);
        }
      } else {
        Get.snackbar(
            "Advertencia", "No se encontró la característica para $deviceId.");
      }
    } else {
      Get.snackbar("Advertencia", "Dispositivo $deviceId no conectado.");
    }
  }

  Future<void> toggleLedUGV(String deviceId) async {
    sendData(deviceId, ledStateUGV.value ? "L" : "H");
  }

  void _startRssiUpdates(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    _rssiTimers[deviceId]?.cancel();
    _rssiTimers[deviceId] =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        if (connectedDevices[deviceId] == device && device.isConnected) {
          // Corrected line
          final rssiValue = await device.readRssi();
          rssiValues[deviceId] = rssiValue;
          final index = foundDevices.indexWhere((d) => d.device == device);
          if (index != -1) {
            foundDevices[index] = FoundDevice(device, rssiValue);
          }
        }
      } catch (e) {
        _logger.e('Error RSSI ($deviceId): $e');
      }
    });
  }

  void _monitorConnectionState(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions[deviceId] = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _cleanupDeviceConnection(deviceId);
        if (Get.isSnackbarOpen) {
          //check if a snackbar is already open
          Get.back();
        }
        Get.snackbar(
            "Info", "${device.platformName ?? deviceId} desconectado.");
      }
    }, onError: (error) {
      _logger.e("Error en _monitorConnectionState: $error");
      if (Get.isSnackbarOpen) {
        //check if a snackbar is already open
        Get.back();
      }
      Get.snackbar("Error", "Error en la conexión del dispositivo: $error");
      _cleanupDeviceConnection(deviceId);
    });
  }

  void _cleanupDeviceConnection(String deviceId) {
    _logger.i('Limpiando conexión para el dispositivo: $deviceId');
    _rssiTimers[deviceId]?.cancel();
    _valueSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions[deviceId]?.cancel();
    connectedDevices.remove(deviceId);
    connectedCharacteristics.remove(deviceId);
    rssiValues.remove(deviceId);
    if (connectedDevices.keys.isNotEmpty &&
        deviceId == connectedDevices.keys.first) {
      // Corrected Line
      // Si era el UGV (asumiendo que se conecta primero)
      ledStateUGV.value = false;
    }
  }

  void disconnectDevice(String deviceId) async {
    if (connectedDevices.containsKey(deviceId)) {
      try {
        await connectedDevices[deviceId]?.disconnect();
        _cleanupDeviceConnection(deviceId);
        final deviceName =
            connectedDevices[deviceId]?.platformName ?? "Dispositivo";
        if (Get.isSnackbarOpen) {
          //check if a snackbar is already open
          Get.back();
        }
        Get.snackbar("Info", "$deviceName desconectado");
      } catch (e) {
        _logger.e("Error al desconectar el dispositivo: $e");
        if (Get.isSnackbarOpen) {
          //check if a snackbar is already open
          Get.back();
        }
        Get.snackbar("Error", "Error al desconectar el dispositivo: $e");
        _cleanupDeviceConnection(deviceId);
      }
    }
  }

  // Nuevos métodos para el control del UGV
  void startMovement(String deviceId, String command) {
    if (connectedDevices.containsKey(deviceId) &&
        (connectedDevices[deviceId]?.isConnected ?? false)) {
      sendData(deviceId, command);
    } else {
      _logger.e("Dispositivo $deviceId no conectado.");
      Get.snackbar("Error", "Dispositivo $deviceId no conectado.");
    }
  }

  void stopMovement(String deviceId) {
    if (connectedDevices.containsKey(deviceId) &&
        (connectedDevices[deviceId]?.isConnected ?? false)) {
      sendData(deviceId, stop);
    } else {
      _logger.e("Dispositivo $deviceId no conectado.");
      Get.snackbar("Error", "Dispositivo $deviceId no conectado.");
    }
  }

  void toggleRecording(String deviceId) {
    if (connectedDevices.containsKey(deviceId) &&
        (connectedDevices[deviceId]?.isConnected ?? false)) {
      isRecording.value = !isRecording.value;
      sendData(deviceId, isRecording.value ? startRecording : stopRecording);
    } else {
      _logger.e("Dispositivo $deviceId no conectado.");
      Get.snackbar("Error", "Dispositivo $deviceId no conectado.");
    }
  }

  void startAutomaticMode(String deviceId) {
    if (connectedDevices.containsKey(deviceId) &&
        (connectedDevices[deviceId]?.isConnected ?? false)) {
      sendData(deviceId, startAutoMode);
    } else {
      _logger.e("Dispositivo $deviceId no conectado.");
      Get.snackbar("Error", "Dispositivo $deviceId no conectado.");
    }
  }

  @override
  void onClose() {
    _logger.i('Cerrando BleController...');
    stopScan();
    for (final timer in _rssiTimers.values) {
      timer.cancel();
    }
    for (final sub in _valueSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    for (final deviceId in connectedDevices.keys) {
      connectedDevices[deviceId]?.disconnect();
    }
    connectedDevices.clear();
    connectedCharacteristics.clear();
    rssiValues.clear();
    super.onClose();
  }
}
