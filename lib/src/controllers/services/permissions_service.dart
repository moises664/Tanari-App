import 'package:get/get.dart'; // Para Get.snackbar y GetX
import 'package:permission_handler/permission_handler.dart'; // Para la gestión de permisos
import 'package:logger/logger.dart'; // Para logging
import 'package:flutter/material.dart'; // Para SnackBar

/// Servicio para gestionar los permisos de Bluetooth Low Energy (BLE) y ubicación.
/// Se encarga de solicitar y verificar los permisos necesarios para el funcionamiento de BLE.
class PermissionsService {
  static final Logger _logger = Logger(); // Instancia del logger

  /// Solicita todos los permisos de Bluetooth y Ubicación necesarios.
  /// Retorna true si todos los permisos requeridos son otorgados, false en caso contrario.
  static Future<bool> requestBlePermissions() async {
    // Lista de permisos a solicitar.
    final List<Permission> permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission
          .bluetoothAdvertise, // Importante si el dispositivo Flutter actúa como periférico
      Permission
          .locationWhenInUse, // Necesario en muchas versiones de Android para el escaneo BLE
    ];

    bool allGranted = true;

    for (final perm in permissions) {
      PermissionStatus status = await perm.status;

      if (!status.isGranted) {
        _logger.i('Solicitando permiso: ${perm.toString()}');
        status = await perm.request(); // Solicitar el permiso
      }

      if (!status.isGranted) {
        allGranted = false;
        _logger.w('Permiso ${perm.toString()} no otorgado.');
        _showPermissionDeniedSnackbar(
            perm); // Mostrar un mensaje específico si el permiso es denegado
      }
    }

    if (allGranted) {
      _logger.i('Todos los permisos BLE y de ubicación otorgados.');
    } else {
      _logger.w('No todos los permisos BLE y de ubicación fueron otorgados.');
    }

    return allGranted;
  }

  /// Muestra un SnackBar informativo si un permiso específico es denegado.
  static void _showPermissionDeniedSnackbar(Permission permission) {
    String message;
    switch (permission.toString()) {
      case 'Permission.bluetoothScan':
        message =
            'Para escanear dispositivos Bluetooth, se requiere el permiso de escaneo de Bluetooth.';
        break;
      case 'Permission.bluetoothConnect':
        message =
            'Para conectar con dispositivos Bluetooth, se requiere el permiso de conexión de Bluetooth.';
        break;
      case 'Permission.bluetoothAdvertise':
        message =
            'Para que el dispositivo anuncie servicios BLE, se requiere el permiso de publicidad de Bluetooth.';
        break;
      case 'Permission.locationWhenInUse':
        message =
            'El permiso de ubicación es necesario para escanear dispositivos Bluetooth en Android.';
        break;
      default:
        message =
            'Un permiso necesario fue denegado: ${permission.toString()}.';
    }
    Get.snackbar(
      "Permiso Denegado",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      mainButton: TextButton(
        onPressed: () {
          openAppSettings(); // Abre la configuración de la aplicación para que el usuario pueda otorgar el permiso manualmente
        },
        child: const Text('Abrir Configuración',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
