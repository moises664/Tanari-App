import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static Future<bool> requestBlePermissions() async {
    final status =
        await [
          Permission.bluetooth,
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.locationWhenInUse,
        ].request();

    return status.values.every((s) => s.isGranted);
  }
}
