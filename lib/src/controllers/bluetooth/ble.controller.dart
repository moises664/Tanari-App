import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tanari_app/src/controllers/services/permissions_service.dart';

class FoundDevice {
  final BluetoothDevice device;
  final int? rssi;

  FoundDevice(this.device, this.rssi);

  // Para comparar dispositivos por ID (evita duplicados en la lista)
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
  // UUIDs del servicio y característica
  static const serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Estados reactivos
  final foundDevices =
      <FoundDevice>[].obs; // Lista observable de dispositivos encontrados.
  final connectedDevice =
      Rxn<FoundDevice>(); // Dispositivo conectado actual (puede ser nulo).
  final isScanning = false.obs; // Estado del escaneo BLE.
  final ledState = false.obs; // Estado del LED (encendido/apagado).
  final rssi = Rxn<int>(); // Intensidad de la señal Bluetooth.

  // Subscripciones
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  Timer? _rssiTimer;
  Timer? _updateTimer;
  bool get isConnected => connectedDevice.value?.device.isConnected ?? false;

  // Inicialización y Permisos
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
      Get.snackbar("Error", "Error en permisos: ${e.toString()}");
    }
  }

  // Escaneo de Dispositivos
  Future<void> startScan() async {
    if (isScanning.value) {
      print("Escaneo ya en curso, retornando.");
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
      print("Iniciando escaneo BLE..."); // Añadido log
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        print(
            "Se recibieron ${results.length} resultados de escaneo."); // Añadido log
        final newDevices =
            results.map((r) => FoundDevice(r.device, r.rssi)).toSet().toList();
        // *** MODIFICACIÓN IMPORTANTE: ***
        // Asegurarse de que la lista observable se actualice correctamente.
        // `assignAll` notifica a los listeners (la UI) sobre el cambio.
        foundDevices.assignAll(newDevices);
        print(
            "Lista de dispositivos encontrados actualizada: ${foundDevices.value.length}"); // Añadido log
        foundDevices.forEach((device) {
          print(
              "Dispositivo encontrado: ${device.device.platformName} (${device.device.remoteId})");
        });
      }, onError: (e) {
        print("Error durante el escaneo: $e"); // Añadido manejo de error
        isScanning.value = false;
      }, onDone: () {
        print("Escaneo BLE completado."); // Añadido log de finalización
        isScanning.value = false;
      });
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(serviceUuid)], // Filtrar por el UUID de tu servicio
      );
      // No establecer isScanning a false aquí, se maneja en onDone y onError del listener
    } on TimeoutException {
      Get.snackbar("Error", "El Bluetooth no se activó a tiempo");
      isScanning.value = false;
    } catch (e) {
      Get.snackbar("Error", e.toString());
      isScanning.value = false;
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _updateTimer?.cancel();
    isScanning.value = false;
    print("Escaneo BLE detenido."); // Añadido log
  }

  //  Conexión a Dispositivo
  Future<void> connectToDevice(FoundDevice foundDevice) async {
    BluetoothDevice? device; // Declarar aquí
    try {
      device = foundDevice.device; // Extrae el BluetoothDevice
      await device.connect(
        timeout: const Duration(seconds: 5), //
      ); // Conecta al dispositivo.

      final services = await device.discoverServices(); // Descubre servicios.
      final service = services.firstWhere(
        (s) => s.uuid == Guid(serviceUuid),
        orElse: () => throw Exception('Servicio no encontrado'),
      );

      // Busca el servicio específico por UUID.
      final characteristic = service.characteristics.firstWhere(
        (c) => c.uuid == Guid(characteristicUuid),
        orElse: () => throw Exception('Característica no encontrada'),
      );

      _setupNotifications(characteristic);
      _startRssiUpdates(device);
      _monitorConnectionState(device);

      // Encuentra la característica para controlar el LED.
      connectedDevice.value = FoundDevice(device, await device.readRssi());
      ledState.value = (await characteristic.read())[0] == 1;
    } catch (e) {
      Get.snackbar("Error", e.toString(), backgroundColor: Colors.red);
      if (device != null) {
        await device.disconnect();
      }
    }
  }

  // Notificaciones: Escucha cambios en la característica BLE y actualiza ledState.
  void _setupNotifications(BluetoothCharacteristic characteristic) {
    _valueSubscription?.cancel();
    _valueSubscription = characteristic.onValueReceived.listen((value) {
      if (value.isNotEmpty) ledState.value = value[0] == 1;
    });
    characteristic.setNotifyValue(true);
  }

  // RSSI: Mide intensidad de señal cada 2 segundos para monitorear calidad de conexión.
  void _startRssiUpdates(BluetoothDevice device) {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        if (connectedDevice.value?.device == device && device.isConnected) {
          // Actualiza el RSSI en la lista foundDevices
          final index = foundDevices.indexWhere((d) => d.device == device);
          if (index != -1) {
            final updatedDevice = FoundDevice(device, await device.readRssi());
            // Actualiza la lista foundDevices solo si el dispositivo todavía está en la lista
            if (index < foundDevices.length) {
              foundDevices[index] = updatedDevice;
            }
            // Actualiza el RSSI del dispositivo conectado si es el mismo
            if (connectedDevice.value?.device == device) {
              connectedDevice.value = updatedDevice;
              rssi.value = updatedDevice.rssi;
            }
          }
        }
      } catch (e) {
        debugPrint('Error RSSI: $e');
      }
    });
  }

  //  Control del Led
  //  Control del Led
  Future<void> toggleLed() async {
    if (!isConnected) {
      Get.snackbar("Info", "Por favor, conéctate a un dispositivo primero.",
          backgroundColor: Colors.orange);
      return; // Sale de la función si no hay dispositivo conectado
    }

    final connected = connectedDevice.value; // Obtén el valor actual una vez
    // ignore: unnecessary_null_comparison
    if (connected == null || connected.device == null) {
      Get.snackbar("Error", "Dispositivo no conectado (error interno)",
          backgroundColor: Colors.red);
      return; // Sale de la función si no hay dispositivo conectado
    }

    if (!connected.device.isConnected) {
      Get.snackbar("Error", "Dispositivo desconectado",
          backgroundColor: Colors.red);
      return; // Sale si el dispositivo no está conectado
    }

    try {
      final device = connected.device; // Ahora 'device' no será null aquí
      final services = await device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == Guid(serviceUuid));
      final characteristic = service.characteristics.firstWhere(
        (c) => c.uuid == Guid(characteristicUuid),
      );

      final newValue = !ledState.value;
      await characteristic.write([newValue ? 1 : 0]);
      ledState.value = newValue;
    } catch (e) {
      Get.snackbar("Error", e.toString(), backgroundColor: Colors.red);
      cleanupConnection();
    }
  }

  // Gestión de Conexión: Detecta desconexiones automaticamente
  void _monitorConnectionState(BluetoothDevice device) {
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        cleanupConnection();
        Get.snackbar("Info", "Dispositivo desconectado");
      }
    });
  }

  // Limpia recursos y restablece variables.
  void cleanupConnection() {
    _rssiTimer?.cancel();
    _valueSubscription?.cancel();
    _connectionSubscription?.cancel();
    if (connectedDevice.value?.device != null) {
      connectedDevice.value?.device.disconnect();
    }
    connectedDevice.value = null;
    ledState.value = false;
    rssi.value = null;
  }

  // Ciclo de Vida: Cancela todas las operaciones activas al destruir el controlador para evitar memory leaks.
  @override
  void onClose() {
    stopScan();
    cleanupConnection();
    super.onClose();
  }
}
