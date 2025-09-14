import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/menu/gps_location_panel_screen.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';
import 'package:logger/logger.dart';

// Helper para convertir Color de Flutter a un entero para Mapbox
int _colorToInt(Color color) {
  return color.value;
}

/// Controlador para la lógica de la pantalla del mapa.
class MapTanariController extends GetxController {
  final String sessionId;
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final BleController _bleController = Get.find<BleController>();
  final Logger _logger = Logger();

  // --- Estado del Mapa y Anotaciones ---
  MapboxMap? mapboxMap;
  CircleAnnotationManager? _sessionPointsManager;
  PointAnnotationManager? _currentLocationManager;
  PointAnnotation? _currentLocationAnnotation;
  StreamSubscription? _gpsSubscription;

  // --- Estado Reactivo (Rx) ---
  final RxBool isLoading = true.obs;
  final RxList<Point> points = <Point>[].obs;
  // Agregar estas variables al controlador
  final RxDouble currentLat = 0.0.obs;
  final RxDouble currentLon = 0.0.obs;
  final RxBool isGpsConnected = false.obs;

  // --- Configuración Inicial ---
  // Coordenadas de Barquisimeto, Venezuela, como punto de partida.
  final CameraOptions initialCameraOptions = CameraOptions(
    center: Point(
        coordinates:
            Position(-69.3575, 10.0667)), // Coordenadas de Barquisimeto
    zoom: 10.0,
  );

  MapTanariController({required this.sessionId});

  @override
  void onInit() {
    super.onInit();
    _loadSessionData();
    _subscribeToGpsUpdates();
  }

  @override
  void onClose() {
    _gpsSubscription?.cancel();
    super.onClose();
  }

  /// Callback que se ejecuta cuando el widget del mapa ha sido creado.
  Future<void> onMapCreated(MapboxMap map) async {
    mapboxMap = map;
    _logger.i('Mapa creado y listo.');

    // Inicializa los gestores de anotaciones.
    _sessionPointsManager =
        await mapboxMap!.annotations.createCircleAnnotationManager();
    _currentLocationManager =
        await mapboxMap!.annotations.createPointAnnotationManager();

    if (points.isNotEmpty) {
      _drawHistoricalRoute();
    }
  }

  /// Carga los datos de GPS de la sesión desde el servicio.
  Future<void> _loadSessionData() async {
    try {
      isLoading.value = true;
      final gpsReadings =
          await _operationDataService.getSensorReadingsForSession(sessionId);

      final loadedPoints = gpsReadings
          .where((reading) =>
              reading['latitude'] != null && reading['longitude'] != null)
          .map((reading) => Point(
                coordinates: Position(
                  reading['longitude'] as double,
                  reading['latitude'] as double,
                ),
              ))
          .toList();

      points.value = loadedPoints;
      _logger.i('Se cargaron ${points.length} puntos GPS históricos.');

      if (mapboxMap != null) {
        _drawHistoricalRoute();
      }
    } catch (e) {
      _logger.e('Error al cargar datos de la sesión: $e');
      Get.snackbar(
        'Error',
        'No se pudieron cargar los datos de la ruta.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Dibuja los puntos históricos en el mapa usando anotaciones.
  void _drawHistoricalRoute() {
    if (mapboxMap == null || _sessionPointsManager == null || points.isEmpty) {
      return;
    }

    final options = points.map((point) {
      return CircleAnnotationOptions(
        geometry: point,
        circleColor: _colorToInt(AppColors.accent),
        circleRadius: 5.0,
        circleOpacity: 0.8,
        circleStrokeColor: _colorToInt(Colors.white),
        circleStrokeWidth: 2.0,
      );
    }).toList();

    _sessionPointsManager!.createMulti(options);
    _logger.i('Ruta histórica dibujada en el mapa.');
    _focusOnHistoricalRoute();
  }

  /// Ajusta la cámara para que toda la ruta histórica sea visible.
  Future<void> _focusOnHistoricalRoute() async {
    if (mapboxMap == null || points.isEmpty) return;

    try {
      // Extrae todas las coordenadas (Position)
      final coordinates = points.map((point) => point.coordinates).toList();

      // Si solo hay un punto, centrar en ese punto con zoom apropiado
      if (points.length == 1) {
        await mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: points.first.coordinates),
            zoom: 15.0, // Zoom más cercano para un solo punto
          ),
          MapAnimationOptions(duration: 2000, startDelay: 0),
        );
      } else {
        // Para múltiples puntos, calcular el bounding box
        double minLon = coordinates.first.lng.toDouble();
        double maxLon = coordinates.first.lng.toDouble();
        double minLat = coordinates.first.lat.toDouble();
        double maxLat = coordinates.first.lat.toDouble();

        for (final coord in coordinates) {
          if (coord.lng < minLon) minLon = coord.lng.toDouble();
          if (coord.lng > maxLon) maxLon = coord.lng.toDouble();
          if (coord.lat < minLat) minLat = coord.lat.toDouble();
          if (coord.lat > maxLat) maxLat = coord.lat.toDouble();
        }

        // Crear bounding box y ajustar cámara
        final bounds = CoordinateBounds(
          southwest: Point(coordinates: Position(minLon, minLat)),
          northeast: Point(coordinates: Position(maxLon, maxLat)),
          infiniteBounds: false,
        );

        final cameraOptions = await mapboxMap!.cameraForCoordinateBounds(
          bounds,
          MbxEdgeInsets(top: 100, left: 40, bottom: 100, right: 40),
          0.0, // bearing
          0.0, // pitch,
          null, // maxZoom
          null, // minZoom
        );

        await mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 2000, startDelay: 0),
        );
      }
      _logger.i('Cámara enfocada en la ruta histórica.');
    } catch (e) {
      _logger.e('Error al enfocar la ruta histórica: $e');
    }
  }

  /// Se suscribe a las actualizaciones de datos del dispositivo portátil (GPS).
  void _subscribeToGpsUpdates() {
    _gpsSubscription = _bleController.portableData.stream.listen((data) {
      final lat = _bleController.latitude.value;
      final lon = _bleController.longitude.value;

      // Actualizar valores actuales
      currentLat.value = lat;
      currentLon.value = lon;
      isGpsConnected.value = (lat != 0.0 && lon != 0.0);

      if (lat != 0.0 && lon != 0.0) {
        final newLocation = Point(coordinates: Position(lon, lat));
        _updateCurrentLocationOnMap(newLocation);

        // También agregar a puntos históricos para visualización inmediata
        if (!points.any((point) =>
            point.coordinates.lat == lat && point.coordinates.lng == lon)) {
          points.add(newLocation);
          _drawHistoricalRoute();
        }
      }
    });
  }

  /// Actualiza la anotación de la ubicación actual en el mapa.
  void _updateCurrentLocationOnMap(Point newLocation) async {
    if (mapboxMap == null || _currentLocationManager == null) return;

    final options = PointAnnotationOptions(
      geometry: newLocation,
      iconSize: 2.5,
      iconColor: _colorToInt(Colors.blue),
      // Agregar una imagen de marcador más visible
      iconImage: "marker-15",
    );

    if (_currentLocationAnnotation == null) {
      _currentLocationAnnotation =
          await _currentLocationManager!.create(options);
    } else {
      _currentLocationAnnotation!.geometry = newLocation;
      _currentLocationManager!.update(_currentLocationAnnotation!);
    }
  }
}

class MapTanariScreen extends StatelessWidget {
  final String sessionId;
  const MapTanariScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final MapTanariController controller =
        Get.put(MapTanariController(sessionId: sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Monitoreo'),
        // En el AppBar de MapTanariScreen, agrega este action:
        actions: [
          Obx(() => IconButton(
                icon: Icon(Icons.gps_fixed,
                    color: controller.isGpsConnected.value
                        ? AppColors.primary
                        : AppColors.neutral),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => GpsLocationPanelScreen(),
                  );
                },
              )),
        ],
        backgroundColor: AppColors.backgroundBlack,
        foregroundColor: AppColors.primary,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.points.isEmpty && !controller.isLoading.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!Get.isSnackbarOpen) {
              Get.snackbar(
                'Sin Datos Históricos',
                'No se encontraron puntos GPS para esta sesión.',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          });
        }

        return MapWidget(
          onMapCreated: controller.onMapCreated,
          styleUri: MapboxStyles.SATELLITE_STREETS,
          cameraOptions: controller.initialCameraOptions,
        );
      }),
    );
  }
}
