import 'dart:async'; // Para usar Timer y StreamSubscription
import 'dart:io'; // Para Platform.isAndroid
import 'package:device_info_plus/device_info_plus.dart'; // Para obtener información del dispositivo
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Librería principal de Bluetooth
import 'package:get/get.dart'; // Para el manejo de estados y la inyección de dependencias
import 'package:permission_handler/permission_handler.dart'; // Para la gestión de permisos
import 'package:logger/logger.dart'; // Para un logging más robusto
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:flutter/material.dart'; // Para SnackBar y otros widgets
import 'package:tanari_app/src/controllers/bluetooth/found_device.dart';

// Importa tu servicio de permisos
import 'package:tanari_app/src/controllers/services/permissions_service.dart'; // Asegúrate que la ruta sea correcta

/// Controlador principal para la gestión de Bluetooth Low Energy (BLE).
/// Centraliza la lógica de escaneo, conexión, desconexión, envío/recepción de datos
/// y manejo de estados para los dispositivos Tanari UGV y Tanari DP.
class BleController extends GetxController {
  //----------------------------------------------------------------------------
  // UUIDs DE SERVICIOS Y CARACTERÍSTICAS
  // Estos UUIDs deben coincidir con los configurados en tus dispositivos ESP32.
  //----------------------------------------------------------------------------
  // UUID del servicio BLE para ambos dispositivos Tanari.
  static const serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  // UUID de la característica para enviar comandos y recibir data (si aaplica) del UGV.
  static const characteristicUuidUGV = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  // UUID de la característica para notificaciones (recepción de datos) del Tanari DP.
  static const characteristicUuidPortableNotify =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  // Nombres de los dispositivos BLE (¡estos deben coincidir exactamente con los nombres anunciados por los ESP32!)
  static const String deviceNameUGV = "TANARI UGV";
  static const String deviceNameDP = "TANARI DP";

  //----------------------------------------------------------------------------
  // COMANDOS PARA EL UGV
  // Estos comandos son strings que se envían al Tanari UGV para controlar su comportamiento.
  //----------------------------------------------------------------------------
  static const String moveForward = 'F'; // Mover hacia adelante
  static const String moveBack = 'B'; // Mover hacia atrás
  static const String moveRight = 'R'; // Mover a la derecha
  static const String moveLeft = 'L'; // Mover a la izquierda
  static const String stop = 'S'; // Detener
  static const String interruption =
      'P'; // Comando para interrupción manual del movimiento
  static const String endAutoMode =
      'T'; // Comando para finalizar el modo automático
  static const String startRecording = 'G'; // Iniciar grabación
  static const String stopRecording = 'N'; // Detener grabación
  static const String startAutoMode = 'A'; // Iniciar modo automático
  static const String toggleLedOn = 'H'; // Comando para encender el LED
  static const String toggleLedOff = 'L'; // Comando para apagar el LED

  //----------------------------------------------------------------------------
  // ESTADOS REACTIVOS (OBSERVABLES)
  // Utilizan `Rx` de GetX para ser automáticamente reactivos a los cambios.
  //----------------------------------------------------------------------------
  final foundDevices = <FoundDevice>[]
      .obs; // Lista de dispositivos encontrados durante el escaneo.
  final connectedDevices = <String, BluetoothDevice>{}
      .obs; // Mapa de dispositivos actualmente conectados (ID -> Dispositivo).
  final connectedCharacteristics = <String, BluetoothCharacteristic>{}
      .obs; // Mapa de características conectadas (ID -> Característica).
  final isScanning = false.obs; // Indica si el escaneo BLE está activo.

  // Estado del LED del UGV (puede ser global o por dispositivo, aquí se usa para el UGV principal).
  final ledStateUGV = false
      .obs; // true si el LED del UGV está encendido, false si está apagado.

  final portableData = <String, String>{}
      .obs; // Datos recibidos del Tanari DP (CO2, CH4, Temp, Hum).
  final rssiValues = <String, int?>{}
      .obs; // Último valor RSSI para cada dispositivo conectado (ID -> RSSI).
  final isRecording = false.obs; // Indica si el UGV está grabando un recorrido.
  final isAutomaticMode =
      false.obs; // Indica si el UGV está en modo automático.

  // Estados de conexión específicos para UGV y DP para una gestión más fácil en la UI.
  final isUgvConnected = false.obs;
  final isPortableConnected = false.obs;

  final RxnString receivedData = RxnString(
      null); // RxString para los datos recibidos del UGV, puede ser nulo

  //----------------------------------------------------------------------------
  // SUBSCRIPCIONES Y TIMERS
  // Para gestionar los flujos de datos y operaciones asíncronas.
  //----------------------------------------------------------------------------
  StreamSubscription<List<ScanResult>>?
      _scanSubscription; // Suscripción a los resultados del escaneo.
  final _connectionSubscriptions = <String,
      StreamSubscription<
          BluetoothConnectionState>>{}; // Suscripciones por dispositivo al estado de conexión.
  final _valueSubscriptions = <String,
      StreamSubscription<
          List<
              int>>>{}; // Suscripciones por característica para la recepción de valores.
  final _rssiTimers = <String,
      Timer>{}; // Temporizadores por dispositivo para la lectura periódica de RSSI.
  final Logger _logger = Logger(); // Instancia para logging detallado.

  //----------------------------------------------------------------------------
  // VARIABLES PARA DISPOSITIVOS ESPECÍFICOS (UGV Y PORTÁTIL)
  // Almacenan los IDs y características de los dispositivos clave una vez conectados.
  //----------------------------------------------------------------------------
  String? ugvDeviceId; // ID del Tanari UGV si está conectado.
  BluetoothCharacteristic?
      ugvCharacteristic; // Característica principal del Tanari UGV.
  String? portableDeviceId; // ID del Tanari DP si está conectado.
  BluetoothCharacteristic?
      portableCharacteristic; // Característica de notificación del Tanari DP.

  //----------------------------------------------------------------------------
  // MÉTODOS PÚBLICOS
  // Acciones que la UI puede invocar.
  //----------------------------------------------------------------------------

  /// Verifica si un dispositivo específico está conectado.
  bool isDeviceConnected(String deviceId) =>
      connectedDevices.containsKey(deviceId) &&
      (connectedDevices[deviceId]?.isConnected ?? false);

  @override
  void onInit() {
    super.onInit();
    _checkPermissions(); // Verifica los permisos al iniciar el controlador.
    // Escucha los cambios en el estado del adaptador Bluetooth del dispositivo.
    FlutterBluePlus.adapterState.listen((state) {
      _logger.i("Estado del adaptador Bluetooth: $state");
      if (state != BluetoothAdapterState.on && Get.isSnackbarOpen) {
        // Si el Bluetooth se apaga y hay un snackbar abierto, lo cierra.
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

  /// Verifica y solicita los permisos necesarios para BLE, especialmente para Android 11 e inferiores.
  Future<void> _checkPermissions() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Para Android 11 (SDK 30) y versiones anteriores, se necesita permiso de ubicación.
      if (Platform.isAndroid && androidInfo.version.sdkInt <= 30) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          Get.snackbar("Error de Permiso",
              "Se requiere permiso de ubicación para escanear dispositivos BLE.");
        }
      }

      // Utiliza un servicio de permisos personalizado para solicitar permisos BLE.
      await PermissionsService.requestBlePermissions();
    } catch (e) {
      _logger.e("Error al verificar/solicitar permisos: ${e.toString()}");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Permiso",
          "No se pudieron obtener los permisos de Bluetooth: ${e.toString()}");
    }
  }

  /// Inicia el escaneo de dispositivos BLE.
  /// Primero verifica el estado del Bluetooth y, si es necesario, intenta activarlo.
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
        FlutterBluePlus.turnOn(); // Intenta activar el Bluetooth.

        // Espera a que el Bluetooth se active, con un timeout.
        state = await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException("El Bluetooth no se activó a tiempo.");
        });
        if (Get.isSnackbarOpen) {
          Get.back(); // Cierra el snackbar de "Activando Bluetooth".
        }
      }

      isScanning.value = true;
      // foundDevices.clear(); // Se mantiene comentado para persistir la lista.
      _logger.i("Iniciando escaneo BLE...");

      // Escucha los resultados del escaneo.
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          // Solo procesar dispositivos Tanari
          if (r.device.platformName == deviceNameUGV ||
              r.device.platformName == deviceNameDP) {
            // Determina si el dispositivo ya está conectado
            final bool currentlyConnected =
                connectedDevices.containsKey(r.device.remoteId.str);
            final newFoundDevice =
                FoundDevice(r.device, r.rssi, isConnected: currentlyConnected);

            final existingIndex = foundDevices.indexWhere(
                (fd) => fd.device.remoteId == newFoundDevice.device.remoteId);

            if (existingIndex != -1) {
              // Si ya existe, actualiza el objeto FoundDevice (ej. RSSI y estado de conexión)
              final existingFoundDevice = foundDevices[existingIndex];
              foundDevices[existingIndex] = existingFoundDevice.copyWith(
                rssi: newFoundDevice.rssi,
                // Mantén el estado de conexión que ya tenías si era true,
                // o actualízalo si el nuevo FoundDevice indica conexión (ej. si acabas de conectarlo)
                isConnected: existingFoundDevice.isConnected ||
                    newFoundDevice.isConnected,
              );
            } else {
              // Si no existe, añádelo
              foundDevices.add(newFoundDevice);
            }
          }
        }
        foundDevices.refresh(); // Asegura que la UI se actualice
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

      // Inicia el escaneo BLE, filtrando por el UUID del servicio para mayor eficiencia.
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

  /// Detiene el escaneo de dispositivos BLE.
  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanning.value = false;
    _logger.i("Escaneo BLE detenido.");
  }

  /// Intenta conectar a un dispositivo Bluetooth.
  /// Si el dispositivo ya está conectado o en proceso de conexión, lo ignora.
  /// Si estaba previamente conectado y se intentó reconectar, primero se desconecta.
  Future<void> connectToDevice(FoundDevice foundDevice) async {
    final deviceId = foundDevice.device.remoteId.str;
    final deviceName = foundDevice.device.platformName;

    // Si ya está conectado, desconecta primero para asegurar una reconexión limpia.
    if (foundDevice.device.isConnected) {
      _logger.i(
          "Dispositivo $deviceName ya conectado. Desconectando para reconectar.");
      await foundDevice.device.disconnect();
      _cleanupDeviceConnection(
          deviceId); // Limpiar recursos antes de intentar reconectar
      await Future.delayed(const Duration(milliseconds: 500)); // Pequeña pausa
    }

    try {
      _logger.i("Conectando a $deviceName ($deviceId)...");
      await foundDevice.device.connect(
          timeout:
              const Duration(seconds: 15)); // Intenta conectar con un timeout.
      connectedDevices[deviceId] =
          foundDevice.device; // Añade el dispositivo al mapa de conectados.
      _monitorConnectionState(
          foundDevice.device); // Inicia el monitoreo del estado de conexión.
      await _discoverServices(
          foundDevice.device); // Descubre los servicios y características.
      _startRssiUpdates(
          foundDevice.device); // Inicia la lectura periódica de RSSI.

      // Actualizar estados de conexión específicos para la UI.
      if (deviceName == deviceNameUGV) {
        ugvDeviceId = deviceId; // Asigna el ID del UGV.
        isUgvConnected.value = true;
      } else if (deviceName == deviceNameDP) {
        portableDeviceId = deviceId; // Asigna el ID del DP.
        isPortableConnected.value = true;
      }

      // Asegurarse de que el dispositivo conectado esté en foundDevices y con su estado correcto
      final index = foundDevices
          .indexWhere((d) => d.device.remoteId == foundDevice.device.remoteId);
      if (index != -1) {
        // Si ya existe, actualiza el RSSI y el estado de conexión en foundDevices
        foundDevices[index] = foundDevices[index].copyWith(
            rssi: await foundDevice.device.readRssi(), isConnected: true);
      } else {
        // Si no existe, añádelo
        foundDevices.add(FoundDevice(
            foundDevice.device, await foundDevice.device.readRssi(),
            isConnected: true));
      }
      foundDevices.refresh(); // Forzar actualización de UI

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
      _cleanupDeviceConnection(
          deviceId); // Limpia los recursos si la conexión falla.
    }
  }

  /// Desconecta un dispositivo Bluetooth específico por su ID.
  Future<void> disconnectDevice(String deviceId) async {
    if (connectedDevices.containsKey(deviceId)) {
      final device = connectedDevices[deviceId]!;
      final deviceName = device.platformName;
      try {
        _logger.i("Desconectando de $deviceName ($deviceId)...");
        await device.disconnect(); // Desconecta el dispositivo.
        // La limpieza de recursos se maneja en _monitorConnectionState al detectar el estado "disconnected".
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
        _cleanupDeviceConnection(
            deviceId); // Limpiar recursos incluso si hay un error en la desconexión.
      }
    } else {
      _logger
          .i("Intento de desconectar un dispositivo no conectado: $deviceId");
    }
  }

  /// Envía datos (como una cadena de texto) a una característica BLE específica del dispositivo.
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
      List<int> bytes =
          data.codeUnits; // Convierte la cadena a una lista de bytes.
      await characteristic.write(bytes,
          withoutResponse: false); // Envía los datos.

      if (kDebugMode) {
        print('Dato enviado a $deviceId: $data');
      }
      _logger.i('Dato enviado a $deviceId: $data');

      // Solo actualiza el estado del LED y modo si el comando es para el UGV.
      if (deviceId == ugvDeviceId) {
        if (data == toggleLedOn || data == toggleLedOff) {
          ledStateUGV.value = data == toggleLedOn;
        }
      }
    } catch (e) {
      _logger.e("Error al enviar datos a $deviceId: $e");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Envío",
          "No se pudieron enviar datos a ${connectedDevices[deviceId]?.platformName ?? deviceId}: ${e.toString()}");
    }
  }

  /// Alterna el estado del LED del UGV.
  void toggleLedUGV(String deviceId) {
    if (ugvCharacteristic != null && deviceId == ugvDeviceId) {
      sendData(deviceId, ledStateUGV.value ? toggleLedOff : toggleLedOn);
    } else {
      Get.snackbar(
          "Advertencia", "UGV no conectado o característica no disponible.");
    }
  }

  /// Alterna el estado de grabación del recorrido del UGV.
  void toggleRecording(String deviceId) {
    if (ugvCharacteristic != null && deviceId == ugvDeviceId) {
      isRecording.value = !isRecording.value; // Cambia el estado de grabación.
      sendData(
          deviceId,
          isRecording.value
              ? startRecording
              : stopRecording); // Envía el comando correspondiente.
      _logger.i("Estado de grabación cambiado a: ${isRecording.value}");
    } else {
      Get.snackbar(
          "Advertencia", "UGV no conectado o característica no disponible.");
    }
  }

  /// Inicia el modo automático del UGV.
  void startAutomaticMode(String deviceId) {
    if (ugvCharacteristic != null && deviceId == ugvDeviceId) {
      sendData(deviceId, startAutoMode); // Envía el comando de modo automático.
      isAutomaticMode.value = true; // Activa el estado del modo automático.
      _logger.i(
          "Comando de modo automático enviado a $deviceId. Modo automático activado.");
      isRecording.value =
          false; // Desactiva la grabación al entrar en modo automático.
    } else {
      Get.snackbar(
          "Advertencia", "UGV no conectado o característica no disponible.");
    }
  }

  //----------------------------------------------------------------------------
  // MÉTODOS PRIVADOS DE GESTIÓN INTERNA
  // No deben ser llamados directamente desde la UI.
  //----------------------------------------------------------------------------

  /// Descubre los servicios y características de un dispositivo conectado.
  /// Almacena las características clave (UGV y DP) para su uso posterior.
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

          // Identificar característica del Tanari UGV (para comandos)
          if (charUuid == characteristicUuidUGV) {
            ugvCharacteristic = char;
            connectedCharacteristics[deviceId] =
                char; // Almacena la característica conectada por su ID.
            ugvDeviceId = deviceId; // Asigna el ID del dispositivo UGV.
            _setupNotifications(
                deviceId, char); // Configurar notificaciones para UGV
            _logger.i(
                'Característica UGV encontrada: ${char.uuid} para $deviceName');
          }
          // Identificar característica de notificación del Tanari DP (para recibir datos).
          else if (charUuid == characteristicUuidPortableNotify) {
            portableCharacteristic = char;
            connectedCharacteristics[deviceId] =
                char; // Almacena la característica conectada por su ID.
            portableDeviceId = deviceId; // Asigna el ID del dispositivo DP.
            _setupNotifications(
                deviceId, char); // Configura las notificaciones para el DP.
            _logger.i(
                'Característica de notificación portátil encontrada: ${char.uuid} para $deviceName');
          }
        }
      }
    }
    // Advertencias si las características esperadas no se encuentran.
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

  /// Configura la escucha de notificaciones (indicates/notify) para una característica dada.
  void _setupNotifications(
      String deviceId, BluetoothCharacteristic characteristic) {
    _valueSubscriptions[deviceId]
        ?.cancel(); // Cancela cualquier suscripción anterior para este dispositivo.
    _valueSubscriptions[deviceId] =
        characteristic.onValueReceived.listen((value) {
      final dataString =
          String.fromCharCodes(value); // Convierte los bytes a una cadena.
      if (characteristic.uuid.toString().toLowerCase() ==
          characteristicUuidPortableNotify) {
        // Si es la característica del DP, parsea y almacena los datos.
        _parseAndStorePortableData(dataString);
        _logger.i('Datos del Tanari DP ($deviceId): $dataString');
      }
      // Procesar datos del UGV
      else if (characteristic.uuid.toString().toLowerCase() ==
          characteristicUuidUGV) {
        _logger.d('Datos del Tanari UGV ($deviceId): $dataString');
        receivedData.value =
            dataString; // Actualiza el RxString con los datos del UGV
        // Después de procesar el dato, se establece a null para permitir que el listener se dispare de nuevo
        // cuando el mismo valor ('T') sea recibido en el futuro.
        Future.delayed(const Duration(milliseconds: 50)).then((_) {
          receivedData.value = null;
        });
      }
    }, onError: (error) {
      _logger.e(
          "Error en la recepción de datos de ${characteristic.uuid} para $deviceId: $error");
      if (Get.isSnackbarOpen) Get.back();
      Get.snackbar("Error de Datos",
          "Error en la recepción de datos de ${connectedDevices[deviceId]?.platformName ?? deviceId}: ${error.toString()}");
    });
    characteristic.setNotifyValue(
        true); // Habilita las notificaciones en la característica.
    _logger.i(
        "Notificaciones activadas para ${characteristic.uuid} en $deviceId.");
  }

  // En tu BleController, dentro de _parseAndStorePortableData
  void _parseAndStorePortableData(String data) {
    try {
      final List<String> parts = data.split(';');
      // Si el formato es "CO2;CH4;Temp;Hum" o "CO2;CH4;Temp;Hum;Pres"
      if (parts.length >= 4) {
        // Cambiado a >=4 para ser flexible con o sin presión
        portableData['co2'] = parts[0];
        portableData['ch4'] = parts[1];
        portableData['temperature'] = parts[2];
        portableData['humidity'] = parts[3];
        // Solo intenta parsear pressure si la longitud es 5 o más
        portableData['pressure'] = (parts.length >= 5) ? parts[4] : '--';
        portableData.refresh();
      } else {
        _logger.w('Formato de datos del Tanari DP incorrecto: $data');
      }
    } catch (e) {
      _logger.e('Error al parsear datos del Tanari DP: $e - Datos: $data');
    }
  }

  /// Inicia un temporizador para leer el RSSI del dispositivo conectado cada 5 segundos.
  void _startRssiUpdates(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    _rssiTimers[deviceId]
        ?.cancel(); // Cancela cualquier temporizador RSSI existente para este dispositivo.
    _rssiTimers[deviceId] =
        Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        // Solo intenta leer RSSI si el dispositivo sigue conectado.
        if (connectedDevices[deviceId] == device && device.isConnected) {
          final rssiValue = await device.readRssi();
          rssiValues[deviceId] =
              rssiValue; // Actualiza el valor RSSI en el mapa.
          // Actualiza el RSSI y el estado de conexión en la lista foundDevices para que la UI se refresque.
          final index = foundDevices.indexWhere((d) => d.device == device);
          if (index != -1) {
            foundDevices[index] = foundDevices[index]
                .copyWith(rssi: rssiValue, isConnected: true);
            foundDevices.refresh();
          }
          _logger.d('RSSI para ${device.platformName}: $rssiValue');
        } else {
          // Si el dispositivo ya no está conectado, cancela el temporizador.
          _logger.w(
              'Dispositivo $deviceId no está conectado, cancelando actualizaciones de RSSI.');
          _rssiTimers[deviceId]?.cancel();
        }
      } catch (e) {
        _logger.e('Error al leer RSSI para $deviceId: ${e.toString()}');
        _rssiTimers[deviceId]
            ?.cancel(); // Cancela el temporizador en caso de error.
      }
    });
  }

  /// Monitorea el estado de conexión de un dispositivo específico.
  /// Si el dispositivo se desconecta, llama a `_cleanupDeviceConnection`.
  void _monitorConnectionState(BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    final deviceName = device.platformName;
    _connectionSubscriptions[deviceId]
        ?.cancel(); // Cancela suscripciones anteriores.
    _connectionSubscriptions[deviceId] = device.connectionState.listen((state) {
      _logger.i("Estado de conexión de $deviceName ($deviceId): $state");
      if (state == BluetoothConnectionState.disconnected) {
        _cleanupDeviceConnection(
            deviceId); // Limpia recursos al detectar la desconexión.
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
      _cleanupDeviceConnection(
          deviceId); // Limpia recursos en caso de error en el monitoreo.
    });
  }

  /// Limpia todos los recursos (timers, suscripciones, estados) asociados a un dispositivo.
  void _cleanupDeviceConnection(String deviceId) {
    _logger.i('Limpiando recursos para el dispositivo: $deviceId');

    _rssiTimers[deviceId]?.cancel(); // Cancela el timer RSSI.
    _rssiTimers.remove(deviceId);
    _valueSubscriptions[deviceId]
        ?.cancel(); // Cancela la suscripción a valores.
    _valueSubscriptions.remove(deviceId);
    _connectionSubscriptions[deviceId]
        ?.cancel(); // Cancela la suscripción de conexión.
    _connectionSubscriptions.remove(deviceId);

    // Elimina el dispositivo de los mapas observados.
    connectedDevices.remove(deviceId);
    connectedCharacteristics.remove(deviceId);
    rssiValues.remove(deviceId);

    // Si el dispositivo limpiado era el UGV o Portable, resetea sus IDs y características específicas.
    if (ugvDeviceId == deviceId) {
      ugvDeviceId = null;
      ugvCharacteristic = null;
      ledStateUGV.value = false;
      isRecording.value = false;
      isAutomaticMode.value = false;
      isUgvConnected.value = false; // Actualiza el estado de conexión del UGV.
      receivedData.value = null; // Limpiar datos recibidos del UGV
    }
    if (portableDeviceId == deviceId) {
      isPortableConnected.value = false;
      portableDeviceId = null;
      portableCharacteristic = null;
      portableData.clear(); // Limpia los datos del DP.
    }
    // Asegurarse de que el FoundDevice correspondiente en la lista principal se actualice
    // para reflejar que ya no está conectado. No lo removemos de foundDevices
    // para que siga apareciendo en la lista, permitiendo la reconexión.
    final index =
        foundDevices.indexWhere((fd) => fd.device.remoteId.str == deviceId);
    if (index != -1) {
      // Actualiza el estado de conexión del FoundDevice a false y resetea RSSI
      foundDevices[index] =
          foundDevices[index].copyWith(isConnected: false, rssi: null);
      foundDevices.refresh(); // Forzar la actualización de la UI
    }

    _logger.i('Recursos limpiados para $deviceId.');
  }

  @override
  void onClose() {
    _logger.i('Cerrando BleController y liberando recursos...');
    stopScan(); // Detiene cualquier escaneo activo.

    // Cancela todos los timers y suscripciones restantes.
    for (var timer in _rssiTimers.values) {
      timer.cancel();
    }
    for (var sub in _valueSubscriptions.values) {
      sub.cancel();
    }
    for (var sub in _connectionSubscriptions.values) {
      sub.cancel();
    }

    // Desconecta activamente todos los dispositivos que aún estén conectados.
    // Usar toList() para evitar modificar la colección mientras se itera.
    for (final deviceId in connectedDevices.keys.toList()) {
      // No llamamos a disconnectDevice aquí porque ya estamos en el proceso de cerrar el controlador
      // y disconnectDevice a su vez llama a _cleanupDeviceConnection y puede causar un bucle o errores.
      // Simplemente desconectamos directamente.
      connectedDevices[deviceId]?.disconnect();
    }

    // Limpia todas las listas y mapas observados.
    foundDevices.clear();
    connectedDevices.clear();
    connectedCharacteristics.clear();
    rssiValues.clear();
    portableData.clear();

    // Resetea todas las variables específicas del controlador.
    ugvDeviceId = null;
    ugvCharacteristic = null;
    portableDeviceId = null;
    portableCharacteristic = null;
    ledStateUGV.value = false;
    isRecording.value = false;
    isAutomaticMode.value = false;
    isUgvConnected.value = false;
    isPortableConnected.value = false;

    super
        .onClose(); // Llama a onClose del padre para la limpieza final de GetX.
    _logger.i('BleController cerrado.');
  }
}
