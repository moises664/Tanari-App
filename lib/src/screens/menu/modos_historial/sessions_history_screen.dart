import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:tanari_app/src/controllers/services/operation_data_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/screens/menu/modos_historial/session_details_screen.dart';

/// Controlador para la pantalla de historial de sesiones.
/// Se encarga de cargar y gestionar la lista de sesiones de operación del usuario.
class SessionsHistoryController extends GetxController {
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();

  /// Lista reactiva de sesiones de operación del usuario.
  final RxList<OperationSession> sessions = <OperationSession>[].obs;

  @override
  void onInit() {
    super.onInit();
    _fetchSessions(); // Carga las sesiones al inicializar el controlador.
  }

  /// Carga las sesiones de operación del usuario desde el servicio.
  Future<void> _fetchSessions() async {
    final fetchedSessions = await _operationDataService.userOperationSessions;
    sessions.assignAll(
        fetchedSessions); // Asigna la lista recuperada a la variable reactiva.
  }

  /// Refresca la lista de sesiones. Útil para un `pull-to-refresh`.
  Future<void> refreshSessions() async {
    await _fetchSessions();
  }
}

/// Pantalla que muestra el historial de sesiones de monitoreo del usuario.
///
/// Permite al usuario ver un listado de todas sus sesiones, incluyendo su
/// nombre, descripción, fecha de inicio y fin, y número de ruta.
/// Al seleccionar una sesión, navega a la pantalla de detalles de esa sesión.
class SessionsHistoryScreen extends StatelessWidget {
  const SessionsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Poner el controlador en la instancia para que GetX lo gestione.
    final SessionsHistoryController controller =
        Get.put(SessionsHistoryController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors
          .backgroundLight, // Un gris muy claro para el fondo principal
      appBar: AppBar(
        title: Text(
          'Historial de Monitoreo',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.backgroundWhite, // Blanco para el AppBar
        iconTheme: IconThemeData(
            color: AppColors.textPrimary), // Color del icono de retroceso
        elevation: 2, // Sombra sutil debajo del AppBar
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => controller.refreshSessions(),
            tooltip: 'Refrescar Sesiones',
          ),
        ],
      ),
      body: Obx(
        () {
          if (controller.sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history,
                      size: 80, color: AppColors.neutral), // Icono más grande
                  const SizedBox(height: 20),
                  Text(
                    'No hay sesiones de monitoreo registradas.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      controller.refreshSessions();
                    },
                    icon: Icon(Icons.add_circle_outline,
                        color: AppColors.backgroundWhite),
                    label: Text(
                      'Iniciar Nuevo Monitoreo',
                      style: TextStyle(
                          color: AppColors.backgroundWhite,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.accentColor, // Verde vibrante para el botón
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 5,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refreshSessions,
            color: AppColors.primary, // Color del indicador de carga
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: controller.sessions.length,
              itemBuilder: (context, index) {
                final session = controller.sessions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10.0),
                  elevation: 5, // Más sombra para destacar
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(18), // Bordes más redondeados
                  ),
                  color: AppColors
                      .backgroundWhite, // Fondo blanco para las tarjetas
                  shadowColor: AppColors.primary
                      .withOpacity(0.2), // Sombra sutil con el color primario
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Get.to(() => SessionDetailsScreen(sessionId: session.id));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.operationName ?? 'Sesión Sin Nombre',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors
                                  .primaryDark, // Nombre de la sesión en verde oscuro
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (session.description != null &&
                              session.description!.isNotEmpty)
                            Text(
                              session.description!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors
                                    .textSecondary, // Gris medio para la descripción
                              ),
                            ),
                          const Divider(
                              height: 25,
                              thickness: 1,
                              color: AppColors
                                  .neutralLight), // Divisor más visible
                          _buildSessionDetailRow(
                            context,
                            Icons.calendar_today,
                            'Inicio:',
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(session.startTime),
                            AppColors
                                .info, // Color azul claro para el icono de fecha
                          ),
                          _buildSessionDetailRow(
                            context,
                            Icons.access_time,
                            'Fin:',
                            session.endTime != null
                                ? DateFormat('dd/MM/yyyy HH:mm')
                                    .format(session.endTime!)
                                : 'Activa',
                            AppColors
                                .accent, // Color azul para el icono de tiempo
                          ),
                          _buildSessionDetailRow(
                            context,
                            Icons.settings,
                            'Modo:',
                            session.mode.capitalizeFirst ?? 'Desconocido',
                            AppColors
                                .secondary1, // Color azul claro para el icono de modo
                          ),
                          if (session.routeNumber != null)
                            _buildSessionDetailRow(
                              context,
                              Icons.alt_route,
                              'Ruta:',
                              session.routeNumber.toString(),
                              AppColors
                                  .primary, // Color verde para el icono de ruta
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Helper para construir una fila de detalle de sesión con iconos y texto.
  Widget _buildSessionDetailRow(BuildContext context, IconData icon,
      String label, String value, Color iconColor) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor), // Icono con color
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
