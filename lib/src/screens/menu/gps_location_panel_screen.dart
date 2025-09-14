import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:clipboard/clipboard.dart';
import 'package:tanari_app/src/controllers/gps/gps_panel_controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';

class GpsLocationPanelScreen extends StatelessWidget {
  GpsLocationPanelScreen({super.key});

  final GpsPanelController controller = Get.put(GpsPanelController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación GPS'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.backgroundWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshGpsData,
            tooltip: 'Actualizar ubicación',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estado de conexión
              _buildConnectionStatus(controller.isGpsConnected.value),
              const SizedBox(height: 20),

              // Datos de ubicación
              if (controller.isGpsConnected.value) ...[
                _buildInfoRow(
                    'Latitud:', controller.currentLat.value.toStringAsFixed(6)),
                _buildInfoRow('Longitud:',
                    controller.currentLon.value.toStringAsFixed(6)),
                const SizedBox(height: 20),

                // Botones de acción
                _buildActionButtons(controller.currentLat.value,
                    controller.currentLon.value, context),
              ] else ...[
                const Center(
                  child: Text(
                    'El Tanari DP no encuentra conexión GPS.\nPor favor, asegúrese de que el dispositivo tenga una vista clara del cielo y vuelva a intentarlo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildConnectionStatus(bool isConnected) {
    return Row(
      children: [
        Icon(
          isConnected ? Icons.gps_fixed : Icons.gps_off,
          color: isConnected ? Colors.green : Colors.red,
          size: 24,
        ),
        const SizedBox(width: 10),
        Text(
          isConnected ? 'GPS con conexión' : 'GPS sin conexión',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isConnected ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      double latitude, double longitude, BuildContext context) {
    return FutureBuilder<List<AvailableMap>>(
      future: MapLauncher.installedMaps,
      builder: (context, snapshot) {
        final availableMaps = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Botón para copiar coordenadas
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 20),
              label: const Text('Copiar Coordenadas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                FlutterClipboard.copy('$latitude, $longitude').then((value) {
                  Get.snackbar(
                    'Copiado',
                    'Coordenadas copiadas al portapapeles',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                });
              },
            ),
            const SizedBox(height: 10),

            // Botones para aplicaciones de mapas disponibles
            if (availableMaps.isNotEmpty) ...[
              const Text(
                'Abrir en:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
            ],

            ...availableMaps.map((map) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: OutlinedButton.icon(
                    icon: SvgPicture.asset(
                      map.icon,
                      width: 24,
                      height: 24,
                    ),
                    label: Text(map.mapName),
                    onPressed: () => _openMap(map, latitude, longitude),
                  ),
                )),
          ],
        );
      },
    );
  }

  void _openMap(AvailableMap map, double latitude, double longitude) async {
    try {
      await map.showMarker(
        coords: Coords(latitude, longitude),
        title: 'Ubicación Tanari',
        description: 'Ubicación actual del dispositivo',
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudo abrir ${map.mapName}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }
}
