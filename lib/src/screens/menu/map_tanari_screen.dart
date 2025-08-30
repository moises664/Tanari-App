import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Asumo que tienes una clase AppColors para consistencia en el tema
import 'package:tanari_app/src/core/app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _SimpleMapScreenState();
}

class _SimpleMapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;

  /// Método llamado cuando el mapa de Mapbox está listo
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // 1. Crea el gestor de anotaciones de puntos.
    // Esto es necesario para dibujar marcadores en el mapa.
    _pointAnnotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();

    // 2. Agrega un listener para detectar toques largos (Long Press) en el mapa.
    _mapboxMap!.gestures.addOnLongTapListener((point) {
      // Llama a la función para agregar el marcador en las coordenadas del toque.
      _addMarker(point);
    });
  }

  /// Función que crea y añade un marcador al mapa.
  void _addMarker(Point point) {
    if (_pointAnnotationManager == null) return;

    // Configura las opciones del marcador (Posición, color, tamaño, etc.)
    final options = PointAnnotationOptions(
        // La geometría es la ubicación (lat, lng) del punto
        geometry: point,
        iconImage: "marker-15", // Ícono predeterminado de Mapbox (un marcador)
        iconColor:
            AppColors.primary.value, // Usamos el color primario de tu app
        iconSize: 2.0,
        // Opcional: añade un texto de etiqueta (se obtiene el número de marcadores existentes del gestor)
        //textField: 'Marcador #${(_pointAnnotationManager?.annotations?.length ?? 0) + 1}',
        textOffset: [0.0, -2.0],
        textSize: 12.0,
        textColor: AppColors.primary.value);

    // Crea el marcador usando el gestor
    _pointAnnotationManager!.create(options);

    // Muestra una confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("¡Marcador añadido con éxito!"),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  // Opcional: Función para limpiar todos los marcadores
  void _clearMarkers() {
    _pointAnnotationManager?.deleteAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Todos los marcadores eliminados."),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Interactivo de Marcadores'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.backgroundWhite,
        actions: [
          // Botón para limpiar los marcadores
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearMarkers,
            tooltip: 'Limpiar Marcadores',
          ),
        ],
      ),
      body: MapWidget(
        // Ya que el accessToken está configurado globalmente en main.dart,
        // no es estrictamente necesario pasarlo aquí de nuevo,
        // pero se mantiene la estructura por si se desea cambiar.
        // mapboxOptions: MapboxOptions(accessToken: "YOUR_MAPBOX_ACCESS_TOKEN"), // No es necesario si está en main.dart
        onMapCreated: _onMapCreated,
        styleUri: MapboxStyles.MAPBOX_STREETS, // Estilo de mapa base
        cameraOptions: CameraOptions(
          // Centrar en Barquisimeto
          center: Point(coordinates: Position(-69.31, 10.06)),
          zoom: 12.0,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null, // Sin acción directa, solo es una guía
        label: const Text('Mantén presionado para añadir un marcador'),
        icon: const Icon(Icons.touch_app),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

extension on GesturesSettingsInterface {
  void addOnLongTapListener(Null Function(dynamic point) param0) {}
}
