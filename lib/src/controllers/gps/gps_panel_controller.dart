import 'dart:async';

import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';

class GpsPanelController extends GetxController {
  final BleController _bleController = Get.find<BleController>();

  final RxDouble currentLat = 0.0.obs;
  final RxDouble currentLon = 0.0.obs;
  final RxBool isGpsConnected = false.obs;
  final RxBool isLoading = true.obs;

  StreamSubscription? _gpsSubscription;

  @override
  void onInit() {
    super.onInit();
    _subscribeToGpsUpdates();
  }

  @override
  void onClose() {
    _gpsSubscription?.cancel();
    super.onClose();
  }

  void _subscribeToGpsUpdates() {
    isLoading.value = true;

    _gpsSubscription = _bleController.portableData.stream.listen((data) {
      final lat = _bleController.latitude.value;
      final lon = _bleController.longitude.value;

      currentLat.value = lat;
      currentLon.value = lon;
      isGpsConnected.value = (lat != 0.0 && lon != 0.0);
      isLoading.value = false;
    }, onError: (error) {
      isLoading.value = false;
      isGpsConnected.value = false;
    });
  }

  void refreshGpsData() {
    final lat = _bleController.latitude.value;
    final lon = _bleController.longitude.value;

    currentLat.value = lat;
    currentLon.value = lon;
    isGpsConnected.value = (lat != 0.0 && lon != 0.0);
  }
}
