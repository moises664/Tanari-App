import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/bluetooth/found_device.dart';
import 'package:tanari_app/src/services/api/admin_services.dart';
import 'package:tanari_app/src/services/api/permissions_service.dart';

/// Controlador principal para la gestión de Bluetooth Low Energy (BLE)
///
/// Centraliza la lógica de escaneo, conexión, desconexión, envío/recepción de datos
/// y manejo de estados para los dispositivos Tanari UGV y Tanari DP.
///
/// ## Funcionalidades principales:
/// - Escaneo y descubrimiento de dispositivos BLE
/// - Conexión y desconexión de dispositivos Tanari
/// - Envío de comandos al UGV
/// - Recepción y procesamiento de datos de sensores
/// - Gestión de estados de conexión y dispositivos
/// - Manejo de permisos Bluetooth
class BleController extends GetxController {
  // ===========================================================================
  // CONSTANTES Y CONFIGURACIÓN
  // ===========================================================================

  /// UUIDs de servicios y características BLE
  static const serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const characteristicUuidUGV = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const characteristicUuidPortableNotify =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  /// Nombres de dispositivos
  static const String deviceNameUGV = "TANARI UGV";
  static const String deviceNameDP = "TANARI DP";

  /// Comandos para control del UGV
  static const String moveForward = 'F';
  static const String moveBack = 'B';
  static const String moveRight = 'R';
  static const String moveLeft = 'L';
  static const String stop = 'S';
  static const String interruption = 'P';
  static const String endAutoMode = 'T';
  static const String startRecording = 'G';
  static const String stopRecording = 'N';
  static const String startAutoMode = 'A';
  static const String recordPoint = 'W';
  static const String endRecording = 'E';
  static const String extractData = 'X';
  static const String cancelAuto = 'N';
  static const String deleteRoutePrefix = 'DEL:';
  static const String returnToOrigin = 'Q';
  static const String stopAndStay = 'P';

  /// Señales recibidas del UGV
  static const String obstacleDetected = 'V';
  static const String arrivedAtPointSignal = 'I';

  // ===========================================================================
  // ESTADOS REACTIVOS (OBSERVABLES)
  // ===========================================================================

  // Estados de evasión de obstáculos y seguimiento de ruta
  final evasionModeActive = false.obs;
  final activeRouteNumber = 0.obs;
  final activePointNumber = 0.obs;
  final RxnInt arrivedAtPoint = RxnInt(null);
  final obstacleAlert = false.obs;

  // Datos GPS
  final latitude = 0.0.obs;
  final longitude = 0.0.obs;
  final gpsHasFix = false.obs;

  // Gestión de dispositivos
  final foundDevices = <FoundDevice>[].obs;
  final connectedDevices = <String, BluetoothDevice>{}.obs;
  final connectedCharacteristics = <String, BluetoothCharacteristic>{}.obs;
  final isScanning = false.obs;

  // Estados del UGV
  final isRecording = false.obs;
  final isAutomaticMode = false.obs;

  // Estados de conexión
  final isUgvConnected = false.obs;
  final isPortableConnected = false.obs;

  // Datos del dispositivo portátil
  final portableData = <String, String>{}.obs;
  final rssiValues = <String, int?>{}.obs;
  final RxnString receivedData = RxnString(null);

  // Configuración del UGV
  final currentSpeed = 100.obs;
  final currentWaitTime = 1000.obs;
  final batteryLevel = 100.obs;
  final memoryStatus = false.obs;

  // Estados de acople físico
  final isPhysicallyCoupled = false.obs;

  // Estados para extracción de base de datos
  final isExtractingData = false.obs;
  final ugvDatabaseData = <String>[].obs;
  final Rxn<String> extractionStatus = Rxn<String>(null);

  // Indicador de ruta
  final RxnString newRouteIndicator = RxnString(null);

  // Nivel de batería del dispositivo portátil
  final portableBatteryLevel = 0.obs;

  // ===========================================================================
  // SUBSCRIPCIONES Y TIMERS
  // ===========================================================================

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final _connectionSubscriptions =
      <String, StreamSubscription<BluetoothConnectionState>>{};
  final _valueSubscriptions = <String, StreamSubscription<List<int>>>{};
  final _rssiTimers = <String, Timer>{};
  final Logger _logger = Logger();

  // ===========================================================================
  // VARIABLES DE DISPOSITIVOS
  // ===========================================================================

  String? ugvDeviceId;
  BluetoothCharacteristic? ugvCharacteristic;
  String? portableDeviceId;
  BluetoothCharacteristic? portableCharacteristic;

  // Dependencias
  final AdminService _adminService = Get.find<AdminService>();
  final List<String> _allowedDeviceUuids = [];

  // ===========================================================================
  // MÉTODOS PÚBLICOS
  // ===========================================================================

  /// Verifica si un dispositivo específico está conectado
  bool isDeviceConnected(String deviceId) =>
      connectedDevices.containsKey(deviceId) &&
      (connectedDevices[deviceId]?.isConnected ?? false);

  @override
  void onInit() {
    super.onInit();
    _checkPermissions();
    FlutterBluePlus.adapterState.listen((state) {
      _logger.i("Estado del adaptador Bluetooth: $state");
      if (state != BluetoothAdapterState.on && Get.isSnackbarOpen) {
        Get.back();
        Get.snackbar(
          "Bluetooth Desactivado",
          "Por favor, active el Bluetooth de su dispositivo.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    });
  }

  /// Verifica y solicita los permisos necesarios para BLE
  Future<void> _checkPermissions() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (Platform.isAndroid && androidInfo.version.sdkInt <= 30) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          Get.snackbar("Error de Permiso",
              "Se requiere permiso de ubicación para escanear dispositivos BLE.");
        }
      }

      await PermissionsService.requestBlePermissions();
    } catch (e) {
      _logger.e("Error al verificar/solicitar permisos: ${e.toString()}");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Permiso",
          "No se pudieron obtener los permisos de Bluetooth: ${e.toString()}");
    }
  }

  // ===========================================================================
  // LÓGICA DE ESCANEO
  // ===========================================================================

  /// Inicia el escaneo de dispositivos BLE
  Future<void> startScan() async {
    if (isScanning.value) {
      _logger.i("Escaneo ya en curso, retornando.");
      return;
    }

    try {
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        Get.snackbar(
          "Bluetooth Apagado",
          "Activando Bluetooth, por favor espere...",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueAccent,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        FlutterBluePlus.turnOn();

        state = await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException("El Bluetooth no se activó a tiempo.");
        });

        if (Get.isSnackbarOpen) {
          Get.back();
        }
      }

      isScanning.value = true;
      _logger.i("Iniciando escaneo BLE...");

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          if (r.device.platformName == deviceNameUGV ||
              r.device.platformName == deviceNameDP) {
            final bool currentlyConnected =
                connectedDevices.containsKey(r.device.remoteId.str);
            final newFoundDevice =
                FoundDevice(r.device, r.rssi, isConnected: currentlyConnected);

            final existingIndex = foundDevices.indexWhere(
                (fd) => fd.device.remoteId == newFoundDevice.device.remoteId);

            if (existingIndex != -1) {
              final existingFoundDevice = foundDevices[existingIndex];
              foundDevices[existingIndex] = existingFoundDevice.copyWith(
                rssi: newFoundDevice.rssi,
                isConnected: existingFoundDevice.isConnected ||
                    newFoundDevice.isConnected,
              );
            } else {
              foundDevices.add(newFoundDevice);
            }
          }
        }
        foundDevices.refresh();
        _logger.d("Dispositivos encontrados: ${foundDevices.length}");
      }, onError: (e) {
        _logger.e("Error durante el escaneo: $e");
        isScanning.value = false;
        if (Get.isSnackbarOpen) Get.back();
        Get.snackbar("Error de Escaneo", "Error durante el escaneo: $e");
      }, onDone: () {
        _logger.i("Escaneo BLE completado.");
        isScanning.value = false;
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(serviceUuid)],
      );
    } on TimeoutException catch (e) {
      _logger.e("Timeout en startScan: ${e.message}");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Conexión",
          e.message ?? "El Bluetooth no se activó a tiempo.");
      isScanning.value = false;
    } catch (e) {
      _logger.e("Error en startScan: ${e.toString()}");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar(
          "Error", "Ocurrió un error inesperado al escanear: ${e.toString()}");
      isScanning.value = false;
    }
  }

  /// Detiene el escaneo de dispositivos BLE
  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanning.value = false;
    _logger.i("Escaneo BLE detenido.");
  }

  /// Carga la lista de UUIDs de dispositivos permitidos
  Future<void> _loadAllowedDevices() async {
    _allowedDeviceUuids.clear();
    final uuids = await _adminService.fetchDeviceUuids();
    _allowedDeviceUuids.addAll(uuids);
    _logger.i(
        "Cargados ${_allowedDeviceUuids.length} UUIDs de dispositivos permitidos para el escaneo.");
  }

  // ===========================================================================
  // GESTIÓN DE CONEXIONES
  // ===========================================================================

  /// Conecta a un dispositivo Bluetooth
  Future<void> connectToDevice(FoundDevice foundDevice) async {
    final deviceId = foundDevice.device.remoteId.str;
    final deviceName = foundDevice.device.platformName;

    if (foundDevice.device.isConnected) {
      _logger.i(
          "Dispositivo $deviceName ya conectado. Desconectando para reconectar.");
      await foundDevice.device.disconnect();
      _cleanupDeviceConnection(deviceId);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      _logger.i("Conectando a $deviceName ($deviceId)...");
      await foundDevice.device.connect(timeout: const Duration(seconds: 15));
      connectedDevices[deviceId] = foundDevice.device;
      _monitorConnectionState(foundDevice.device);
      await _discoverServices(foundDevice.device);
      _startRssiUpdates(foundDevice.device);

      if (deviceName == deviceNameUGV) {
        ugvDeviceId = deviceId;
        isUgvConnected.value = true;
      } else if (deviceName == deviceNameDP) {
        portableDeviceId = deviceId;
        isPortableConnected.value = true;
      }

      final index = foundDevices
          .indexWhere((d) => d.device.remoteId == foundDevice.device.remoteId);
      if (index != -1) {
        foundDevices[index] = foundDevices[index].copyWith(
            rssi: await foundDevice.device.readRssi(), isConnected: true);
      } else {
        foundDevices.add(FoundDevice(
            foundDevice.device, await foundDevice.device.readRssi(),
            isConnected: true));
      }
      foundDevices.refresh();

      Get.snackbar(
        "Conexión Exitosa",
        "Conectado a $deviceName",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      _logger.i("Conexión exitosa con $deviceName");
    } catch (e) {
      _logger.e("Error al conectar a $deviceName ($deviceId): $e");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Conexión",
          "No se pudo conectar a $deviceName: ${e.toString()}");
      _cleanupDeviceConnection(deviceId);
    }
  }

  /// Desconecta un dispositivo Bluetooth
  Future<void> disconnectDevice(String deviceId) async {
    if (connectedDevices.containsKey(deviceId)) {
      final device = connectedDevices[deviceId]!;
      final deviceName = device.platformName;
      try {
        _logger.i("Desconectando de $deviceName ($deviceId)...");
        await device.disconnect();
        if (Get.isSnackbarOpen) Get.back();
        Get.snackbar(
          "Desconectado",
          "$deviceName ha sido desconectado.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        _logger.i("$deviceName desconectado con éxito.");
      } catch (e) {
        _logger.e("Error al desconectar el dispositivo $deviceId: $e");
        if (Get.isSnackbarOpen) Get.back();
        Get.snackbar("Error al Desconectar",
            "No se pudo desconectar el dispositivo: ${e.toString()}");
        _cleanupDeviceConnection(deviceId);
      }
    } else {
      _logger
          .i("Intento de desconectar un dispositivo no conectado: $deviceId");
    }
  }

  // ===========================================================================
  // ENVÍO DE COMANDOS
  // ===========================================================================

  /// Envía datos a una característica BLE
  Future<void> sendData(String deviceId, String data) async {
    if (!isDeviceConnected(deviceId)) {
      _logger.e("Error al enviar datos: Dispositivo $deviceId no conectado.");
      Get.snackbar("Error", "Dispositivo no conectado para enviar datos.");
      return;
    }

    final characteristic = connectedCharacteristics[deviceId];
    if (characteristic == null) {
      _logger.e(
          "Error al enviar datos: Característica no encontrada para $deviceId.");
      Get.snackbar("Advertencia",
          "No se encontró la característica para enviar datos a $deviceId.");
      return;
    }

    try {
      List<int> bytes = data.codeUnits;
      await characteristic.write(bytes, withoutResponse: false);

      if (kDebugMode) {
        print('Dato enviado a $deviceId: $data');
      }
      _logger.i('Dato enviado a $deviceId: $data');
    } catch (e) {
      _logger.e("Error al enviar datos a $deviceId: $e");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Envío",
          "No se pudieron enviar datos a ${connectedDevices[deviceId]?.platformName ?? deviceId}: ${e.toString()}");
    }
  }

  /// Envía comando para activar/desactivar modo de evasión
  void sendEvadeMode(bool enabled) {
    if (ugvDeviceId != null) {
      sendData(ugvDeviceId!, 'SET_EVADE:${enabled ? 1 : 0}');
    }
  }

  /// Envía comando para regresar al origen
  void sendReturnToOrigin() {
    if (ugvDeviceId != null) {
      sendData(ugvDeviceId!, returnToOrigin);
    }
  }

  /// Envía comando para detenerse y permanecer en posición
  void sendStopAndStay() {
    if (ugvDeviceId != null) {
      sendData(ugvDeviceId!, stopAndStay);
    }
  }

  /// Alterna el estado de grabación del recorrido
  void toggleRecording(String deviceId) {
    if (ugvCharacteristic != null && deviceId == ugvDeviceId) {
      isRecording.value = !isRecording.value;
      sendData(deviceId, isRecording.value ? startRecording : stopRecording);
      _logger.i("Estado de grabación cambiado a: ${isRecording.value}");
    } else {
      Get.snackbar(
          "Advertencia", "UGV no conectado o característica no disponible.");
    }
  }

  /// Inicia el modo automático
  void startAutomaticMode(String deviceId) {
    if (ugvCharacteristic != null && deviceId == ugvDeviceId) {
      sendData(deviceId, startAutoMode);
      isAutomaticMode.value = true;
      _logger.i(
          "Comando de modo automático enviado a $deviceId. Modo automático activado.");
      isRecording.value = false;
    } else {
      Get.snackbar(
          "Advertencia", "UGV no conectado o característica no disponible.");
    }
  }

  // ===========================================================================
  // MÉTODOS PRIVADOS DE GESTIÓN INTERNA
  // ===========================================================================

  /// Descubre servicios y características de un dispositivo
  Future<void> _discoverServices(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    final deviceName = device.platformName;
    List<BluetoothService> services = await device.discoverServices();
    _logger.i("Servicios descubiertos para $deviceName: ${services.length}");

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid) {
        _logger.i(
            "Servicio principal (${service.uuid}) encontrado en $deviceName.");
        for (BluetoothCharacteristic char in service.characteristics) {
          final charUuid = char.uuid.toString().toLowerCase();

          if (charUuid == characteristicUuidUGV) {
            ugvCharacteristic = char;
            connectedCharacteristics[deviceId] = char;
            ugvDeviceId = deviceId;
            _setupNotifications(deviceId, char);
            _logger.i(
                'Característica UGV encontrada: ${char.uuid} para $deviceName');
          } else if (charUuid == characteristicUuidPortableNotify) {
            portableCharacteristic = char;
            connectedCharacteristics[deviceId] = char;
            portableDeviceId = deviceId;
            _setupNotifications(deviceId, char);
            _logger.i(
                'Característica de notificación portátil encontrada: ${char.uuid} para $deviceName');
          }
        }
      }
    }

    if (deviceName == deviceNameUGV && ugvCharacteristic == null) {
      _logger
          .w("No se encontró la característica UGV esperada para $deviceName.");
      Get.snackbar("Advertencia",
          "No se encontró la característica UGV para $deviceName.");
    } else if (deviceName == deviceNameDP && portableCharacteristic == null) {
      _logger
          .w("No se encontró la característica DP esperada para $deviceName.");
      Get.snackbar("Advertencia",
          "No se encontró la característica DP para $deviceName.");
    }
  }

  /// Configura notificaciones para una característica
  void _setupNotifications(
      String deviceId, BluetoothCharacteristic characteristic) {
    _valueSubscriptions[deviceId]?.cancel();
    _valueSubscriptions[deviceId] =
        characteristic.onValueReceived.listen((value) {
      final dataString = String.fromCharCodes(value).trim();

      if (characteristic.uuid.toString().toLowerCase() ==
          characteristicUuidPortableNotify) {
        _parseAndStorePortableData(dataString);
        _logger.i('Datos del Tanari DP ($deviceId): $dataString');
      } else if (characteristic.uuid.toString().toLowerCase() ==
          characteristicUuidUGV) {
        _logger.d('Datos del Tanari UGV ($deviceId): $dataString');
        _processUgvData(dataString);
      }
    }, onError: (error) {
      _logger.e(
          "Error en la recepción de datos de ${characteristic.uuid} para $deviceId: $error");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Datos",
          "Error en la recepción de datos de ${connectedDevices[deviceId]?.platformName ?? deviceId}: ${error.toString()}");
    });

    characteristic.setNotifyValue(true);
    _logger.i(
        "Notificaciones activadas para ${characteristic.uuid} en $deviceId.");
  }

  /// Procesa datos recibidos del UGV
  void _processUgvData(String dataString) {
    if (isExtractingData.value) {
      _processExtractionData(dataString);
      return;
    }

    if (dataString.startsWith('A') &&
        int.tryParse(dataString.substring(1)) != null) {
      _logger.i("Nuevo indicador de ruta recibido del UGV: $dataString");
      newRouteIndicator.value = dataString;
      Future.delayed(const Duration(milliseconds: 100)).then((_) {
        if (newRouteIndicator.value == dataString) {
          newRouteIndicator.value = null;
        }
      });
      return;
    }

    if (dataString.length == 1) {
      switch (dataString) {
        case obstacleDetected:
          obstacleAlert.value = true;
          break;
        case arrivedAtPointSignal:
          arrivedAtPoint.value = activePointNumber.value;
          Future.delayed(const Duration(seconds: 2))
              .then((_) => arrivedAtPoint.value = null);
          break;
        case endAutoMode:
          receivedData.value = dataString;
          break;
      }
      return;
    }

    if (dataString.contains(',')) {
      _processStatusData(dataString);
    } else {
      receivedData.value = dataString;
      Future.delayed(const Duration(milliseconds: 50)).then((_) {
        if (receivedData.value == dataString) {
          receivedData.value = null;
        }
      });
    }
  }

  /// Procesa datos de extracción
  void _processExtractionData(String dataString) {
    if (dataString == 'O') {
      isExtractingData.value = false;
      extractionStatus.value = 'completed';
    } else if (dataString == 'K') {
      isExtractingData.value = false;
      extractionStatus.value = 'empty';
    } else if (dataString.contains(';')) {
      ugvDatabaseData.add(dataString);
    } else {
      _logger.d(
          "Ignorando cadena durante extracción (formato no es de datos): $dataString");
    }
  }

  /// Procesa datos de estado
  void _processStatusData(String dataString) {
    final parts = dataString.split(',');
    for (String rawPart in parts) {
      final part = rawPart.trim();

      if (part.startsWith('VS:')) {
        final speedValue = double.tryParse(part.substring(3));
        if (speedValue != null) currentSpeed.value = speedValue.round();
      } else if (part.startsWith('TE:')) {
        final waitTimeValue = int.tryParse(part.substring(3));
        if (waitTimeValue != null) currentWaitTime.value = waitTimeValue;
      } else if (part.startsWith('B:')) {
        final battery = int.tryParse(part.substring(2));
        if (battery != null) batteryLevel.value = battery;
      } else if (part.startsWith('M:')) {
        memoryStatus.value = part.substring(2) == '1';
      } else if (part.startsWith('A:')) {
        isPhysicallyCoupled.value = part.substring(2) == '1';
      } else if (part.startsWith('E:')) {
        evasionModeActive.value = part.substring(2) == '1';
      } else if (part.startsWith('R:')) {
        activeRouteNumber.value = int.tryParse(part.substring(2)) ?? 0;
      } else if (part.startsWith('P:')) {
        final newPoint = int.tryParse(part.substring(2)) ?? 0;
        if (newPoint != activePointNumber.value) {
          activePointNumber.value = newPoint;
          arrivedAtPoint.value = null;
        }
      }
    }

    currentSpeed.refresh();
    currentWaitTime.refresh();
    batteryLevel.refresh();
    memoryStatus.refresh();
  }

  /// Parsea y almacena datos del dispositivo portátil
  void _parseAndStorePortableData(String data) {
    try {
      final List<String> parts = data.split(';');
      if (parts.length >= 9) {
        portableData['co2'] = parts[0];
        portableData['ch4'] = parts[1];
        portableData['temperature'] = parts[2];
        portableData['humidity'] = parts[3];

        final battery = int.tryParse(parts[4]);
        if (battery != null) portableBatteryLevel.value = battery;

        final lat = double.tryParse(parts[5]);
        final lon = double.tryParse(parts[6]);
        final fix = int.tryParse(parts[8]);

        if (lat != null) latitude.value = lat;
        if (lon != null) longitude.value = lon;
        if (fix != null) gpsHasFix.value = (fix == 1);

        if (parts.length >= 5) {
          final battery = int.tryParse(parts[4]);
          if (battery != null) {
            portableBatteryLevel.value = battery;
          } else {
            _logger.w('Valor de batería no válido recibido: ${parts[4]}');
          }
        }
        portableData.refresh();
      } else {
        _logger.w('Formato de datos del Tanari DP incorrecto: $data');
      }
    } catch (e) {
      _logger.e('Error al parsear datos del Tanari DP: $e - Datos: $data');
    }
  }

  /// Inicia actualizaciones periódicas de RSSI
  void _startRssiUpdates(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    _rssiTimers[deviceId]?.cancel();
    _rssiTimers[deviceId] =
        Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        if (connectedDevices[deviceId] == device && device.isConnected) {
          final rssiValue = await device.readRssi();
          rssiValues[deviceId] = rssiValue;

          final index = foundDevices.indexWhere((d) => d.device == device);
          if (index != -1) {
            foundDevices[index] = foundDevices[index]
                .copyWith(rssi: rssiValue, isConnected: true);
            foundDevices.refresh();
          }
          _logger.d('RSSI para ${device.platformName}: $rssiValue');
        } else {
          _logger.w(
              'Dispositivo $deviceId no está conectado, cancelando actualizaciones de RSSI.');
          _rssiTimers[deviceId]?.cancel();
        }
      } catch (e) {
        _logger.e('Error al leer RSSI para $deviceId: ${e.toString()}');
        _rssiTimers[deviceId]?.cancel();
      }
    });
  }

  /// Monitorea el estado de conexión de un dispositivo
  void _monitorConnectionState(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    final deviceName = device.platformName;
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions[deviceId] = device.connectionState.listen((state) {
      _logger.i("Estado de conexión de $deviceName ($deviceId): $state");
      if (state == BluetoothConnectionState.disconnected) {
        _cleanupDeviceConnection(deviceId);
        if (Get.isSnackbarOpen) Get.back();
        Get.snackbar(
          "Desconectado",
          "$deviceName se ha desconectado.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }, onError: (error) {
      _logger.e("Error en el monitoreo de conexión para $deviceId: $error");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Conexión",
          "Problema con la conexión de $deviceName: ${error.toString()}");
      _cleanupDeviceConnection(deviceId);
    });
  }

  /// Limpia recursos asociados a un dispositivo
  void _cleanupDeviceConnection(String deviceId) {
    _logger.i('Limpiando recursos para el dispositivo: $deviceId');

    _rssiTimers[deviceId]?.cancel();
    _rssiTimers.remove(deviceId);
    _valueSubscriptions[deviceId]?.cancel();
    _valueSubscriptions.remove(deviceId);
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);

    connectedDevices.remove(deviceId);
    connectedCharacteristics.remove(deviceId);
    rssiValues.remove(deviceId);

    if (ugvDeviceId == deviceId) {
      ugvDeviceId = null;
      ugvCharacteristic = null;
      isRecording.value = false;
      isAutomaticMode.value = false;
      isUgvConnected.value = false;
      receivedData.value = null;
      isPhysicallyCoupled.value = false;
      isExtractingData.value = false;
      evasionModeActive.value = false;
      activeRouteNumber.value = 0;
      activePointNumber.value = 0;
      ugvDatabaseData.clear();
      extractionStatus.value = null;
    }

    if (portableDeviceId == deviceId) {
      isPortableConnected.value = false;
      portableDeviceId = null;
      portableCharacteristic = null;
      portableData.clear();
      latitude.value = 0.0;
      longitude.value = 0.0;
      gpsHasFix.value = false;
    }

    final index =
        foundDevices.indexWhere((fd) => fd.device.remoteId.str == deviceId);
    if (index != -1) {
      foundDevices[index] =
          foundDevices[index].copyWith(isConnected: false, rssi: null);
      foundDevices.refresh();
    }

    _logger.i('Recursos limpiados para $deviceId.');
  }

  @override
  void onClose() {
    _logger.i('Cerrando BleController y liberando recursos...');
    stopScan();

    for (var timer in _rssiTimers.values) {
      timer.cancel();
    }
    for (var sub in _valueSubscriptions.values) {
      sub.cancel();
    }
    for (var sub in _connectionSubscriptions.values) {
      sub.cancel();
    }

    for (final deviceId in connectedDevices.keys.toList()) {
      connectedDevices[deviceId]?.disconnect();
    }

    foundDevices.clear();
    connectedDevices.clear();
    connectedCharacteristics.clear();
    rssiValues.clear();
    portableData.clear();

    ugvDeviceId = null;
    ugvCharacteristic = null;
    portableDeviceId = null;
    portableCharacteristic = null;
    isRecording.value = false;
    isAutomaticMode.value = false;
    isUgvConnected.value = false;
    isPortableConnected.value = false;

    super.onClose();
    _logger.i('BleController cerrado.');
  }
}
