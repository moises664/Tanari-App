import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';

/// Controlador para la pantalla de historial de rutas UGV.
/// Se encarga de cargar y gestionar la lista de sesiones de operación del usuario
/// que corresponden a rutas grabadas.
class UgvRoutesController extends GetxController {
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final Logger _logger = Logger();

  /// Lista reactiva de sesiones de operación del usuario que son rutas grabadas.
  final RxList<OperationSession> recordedRoutes = <OperationSession>[].obs;

  @override
  void onInit() {
    super.onInit();
    _fetchRecordedRoutes(); // Carga las rutas al inicializar el controlador.
  }

  /// Carga las rutas grabadas del usuario desde el servicio.
  Future<void> _fetchRecordedRoutes() async {
    try {
      _logger.i('Fetching recorded UGV routes...');
      final fetchedSessions =
          await _operationDataService.getOperationSessions(mode: 'recorded');
      recordedRoutes.assignAll(fetchedSessions);
      _logger.i('Fetched ${recordedRoutes.length} recorded UGV routes.');
    } catch (e, stackTrace) {
      _logger.e('Error fetching recorded UGV routes: $e',
          error: e, stackTrace: stackTrace);
      Get.snackbar('Error', 'No se pudieron cargar las rutas guardadas.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
    }
  }

  /// Refresca la lista de rutas.
  Future<void> refreshRoutes() async {
    await _fetchRecordedRoutes();
  }

  /// Elimina una sesión de ruta de la base de datos.
  Future<void> deleteRoute(String sessionId) async {
    final bool success =
        await _operationDataService.deleteOperationSession(sessionId);
    if (success) {
      _logger.i('Route with session ID $sessionId deleted from database.');
      Get.snackbar('Ruta Eliminada', 'La ruta ha sido borrada exitosamente.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.accent,
          colorText: AppColors.backgroundWhite);
    } else {
      _logger.e('Failed to delete route with session ID $sessionId.');
      Get.snackbar('Error', 'No se pudo borrar la ruta de la base de datos.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
    }
    await refreshRoutes(); // Refresca la lista después de borrar
  }
}

/// Pantalla que muestra el historial de rutas grabadas del UGV.
class UgvRoutesScreen extends StatelessWidget {
  const UgvRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UgvRoutesController controller = Get.put(UgvRoutesController());
    final BleController bleController = Get.find<BleController>();
    final theme = Theme.of(context);

    return Scaffold(
      //backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Rutas Grabadas del UGV',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.backgroundBlack,
        foregroundColor: AppColors.primary,
        iconTheme: IconThemeData(color: AppColors.primary),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => controller.refreshRoutes(),
            tooltip: 'Refrescar Rutas',
          ),
        ],
      ),
      body: Obx(
        () {
          if (controller.recordedRoutes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 80, color: AppColors.neutral),
                  const SizedBox(height: 20),
                  Text(
                    'No hay rutas grabadas disponibles.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          //Panel del historial de rutas grabadas
          return RefreshIndicator(
            onRefresh: controller.refreshRoutes,
            color: AppColors.accent,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: controller.recordedRoutes.length,
              itemBuilder: (context, index) {
                final session = controller.recordedRoutes[index];
                return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    color: AppColors.backgroundWhite,
                    shadowColor: AppColors.primary.withAlpha(51),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                      onTap: () {
                        Get.back(result: session);
                      },
                      title: Text(
                        session.operationName ?? 'Ruta Sin Nombre',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          if (session.description != null &&
                              session.description!.isNotEmpty)
                            Text(
                              session.description!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const Divider(
                              height: 25,
                              thickness: 1,
                              color: AppColors.neutralLight),
                          _buildSessionDetailRow(
                            context,
                            Icons.label,
                            'Indicador:',
                            session.indicator ?? 'N/A',
                            AppColors.accent,
                          ),
                          _buildSessionDetailRow(
                            context,
                            Icons.calendar_today,
                            'Fecha:',
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(session.startTime.toLocal()),
                            AppColors.info,
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_forever,
                            color: AppColors.error, size: 30),
                        tooltip: 'Borrar Ruta Permanentemente',
                        onPressed: () async {
                          final confirm = await Get.dialog<bool>(
                            AlertDialog(
                              title: const Text('Confirmar Borrado'),
                              content: Text(
                                '¿Está seguro de que desea eliminar la ruta "${session.operationName}" (${session.indicator})? Esta acción no se puede deshacer.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(result: false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Get.back(result: true),
                                  child: const Text('Eliminar',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final routeNumber =
                                session.indicator?.substring(1) ?? '';
                            if (routeNumber.isNotEmpty &&
                                bleController.isUgvConnected.value &&
                                bleController.ugvDeviceId != null) {
                              bleController.sendData(
                                bleController.ugvDeviceId!,
                                '${BleController.deleteRoutePrefix}$routeNumber',
                              );
                            }
                            await controller.deleteRoute(session.id);
                          }
                        },
                      ),
                    ));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionDetailRow(BuildContext context, IconData icon,
      String label, String value, Color iconColor) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
