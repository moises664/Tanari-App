// Codigo de la Pantalla del Modo UGV (Actualizado y Documentado)

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Asegúrate de que esta ruta sea correcta para tus colores
import 'package:logger/logger.dart';
import 'package:collection/collection.dart'; // Importar para firstWhereOrNull
import 'package:tanari_app/src/controllers/services/operation_data_service.dart'; // Servicio para sesiones de operación
import 'package:tanari_app/src/controllers/services/ugv_service.dart'; // Servicio para telemetría UGV
import 'package:intl/intl.dart'; // Para formatear fechas

// =============================================================================
// Controladores y Modelos Auxiliares
// =============================================================================

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
  /// Muestra un SnackBar si ocurre un error durante la carga.
  Future<void> _fetchRecordedRoutes() async {
    try {
      _logger.i('Fetching recorded UGV routes...');
      final fetchedSessions =
          await _operationDataService.getOperationSessions(mode: 'recorded');
      recordedRoutes.assignAll(
          fetchedSessions); // Asigna la lista recuperada a la variable reactiva.
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

  /// Refresca la lista de rutas. Útil para un `pull-to-refresh`.
  Future<void> refreshRoutes() async {
    await _fetchRecordedRoutes();
  }
}

/// Pantalla que muestra el historial de rutas grabadas del UGV.
/// Permite al usuario seleccionar una ruta para cargarla y ejecutarla.
class UgvRoutesScreen extends StatelessWidget {
  const UgvRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UgvRoutesController controller = Get.put(UgvRoutesController());
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Rutas Grabadas del UGV',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.backgroundWhite,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
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
                  Icon(Icons.route,
                      size: 80, color: AppColors.neutral), // Icono más grande
                  const SizedBox(height: 20),
                  Text(
                    'No hay rutas grabadas disponibles.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      controller.refreshRoutes();
                    },
                    icon: Icon(Icons.refresh, color: AppColors.backgroundWhite),
                    label: Text(
                      'Refrescar',
                      style: TextStyle(
                          color: AppColors.backgroundWhite,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
            onRefresh: controller.refreshRoutes,
            color: AppColors.primary,
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
                  shadowColor: AppColors.primary.withOpacity(0.2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      // Regresa a la pantalla anterior con la sesión seleccionada como resultado
                      Get.back(result: session);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.operationName ?? 'Ruta Sin Nombre',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                            Icons.calendar_today,
                            'Fecha:',
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(session.startTime.toLocal()),
                            AppColors.info,
                          ),
                          if (session.routeNumber != null)
                            _buildSessionDetailRow(
                              context,
                              Icons.alt_route,
                              'Número de Ruta:',
                              session.routeNumber.toString(),
                              AppColors.primary,
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
  /// Helper para construir una fila de detalle de sesión con iconos y texto.
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

// =============================================================================
// Pantalla Principal: ModoUgv
// =============================================================================

/// Pantalla principal para el control manual y automático del UGV.
/// Permite al usuario interactuar con el vehículo a través de comandos BLE,
/// registrar rutas, cargar rutas preexistentes y ejecutarlas. También muestra
/// una simulación visual de la trayectoria del UGV en un mapa.
class ModoUgv extends StatefulWidget {
  const ModoUgv({super.key});

  @override
  State<ModoUgv> createState() => _ModoUgvState();
}

/// Estado que gestiona la lógica de control y visualización del UGV.
class _ModoUgvState extends State<ModoUgv> {
  //----------------------------------------------------------------------------
  // VARIABLES DE ESTADO Y CONTROL
  //----------------------------------------------------------------------------

  final BleController bleController = Get.find<BleController>();
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>(); // Inyección de OperationDataService
  final UgvService _ugvService =
      Get.find<UgvService>(); // Inyección de UgvService
  final Logger _logger = Logger(); // Instancia del logger

  // Puntos del recorrido para dibujar en el mapa (simulado).
  List<Offset> recorridoPoints = [const Offset(0, 0)];
  // Posición actual del UGV en el mapa (simulada).
  Offset currentPosition = const Offset(0, 0);
  // Tamaño del paso para el movimiento simulado en el mapa.
  double stepSize = 20.0;

  // ID del dispositivo UGV conectado (puede ser nulo si no hay conexión).
  String? ugvDeviceId;
  // Último comando de movimiento direccional enviado para evitar duplicados.
  String? _lastSentDirectionalCommand;

  // Estado reactivo para el botón de grabación.
  final RxBool _isRecording =
      false.obs; // Indica si se está grabando un recorrido (ruta).
  // Variable reactiva para la sesión de operación actualmente activa.
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);

  // Bandera para controlar la visibilidad del SnackBar de advertencia de conexión.
  bool _connectionSnackbarShown = false;

  // Variable de estado: Controla si estamos esperando la 'T' final para reactivar los controles manuales.
  final RxBool _awaitingFinalTForManualControlsReactivation = false.obs;

  // Variables de estado para la gestión de rutas
  final RxList<String> _loadedRouteCommands =
      <String>[].obs; // Comandos de una ruta cargada del servidor.
  final RxBool _isExecutingLoadedRoute =
      false.obs; // Indica si se está ejecutando una ruta cargada.

  //----------------------------------------------------------------------------
  // MÉTODOS DEL CICLO DE VIDA DEL WIDGET
  //----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initUgvDeviceId(); // Inicializa y configura listeners para ugvDeviceId
    _bindRecordingState();
    _lastSentDirectionalCommand = BleController.stop;

    /// Escucha los cambios en el estado de conexión del UGV para activar/desactivar controles.
    /// Si el UGV se conecta, los Obx se encargarán de habilitar los botones.
    /// Si el UGV se desconecta, finaliza cualquier sesión activa y resetea los modos.
    ever(bleController.isUgvConnected, (isConnected) {
      if (isConnected) {
        _logger.i("UGV Connected. Activating relevant controls.");
      } else {
        _logger.i("UGV Disconnected. Deactivating all UGV-dependent controls.");
        // Si el UGV se desconecta, se debería finalizar cualquier sesión activa
        if (_currentActiveSession.value != null) {
          _endUgvSession(
              showSnackbar:
                  true); // Mostrar snackbar al desconectar y finalizar sesión
        }
        // Asegurar que los estados de modo automático y grabación estén desactivados
        bleController.isAutomaticMode.value = false;
        _isRecording.value = false;
        _isExecutingLoadedRoute.value = false;
        _loadedRouteCommands.clear();
        _awaitingFinalTForManualControlsReactivation.value = false; // Resetear
      }
    });

    /// Escucha el mapa de dispositivos conectados. Si el UGV se reconecta,
    /// muestra un SnackBar de conexión restaurada. Si se desconecta, resetea la bandera.
    ever(bleController.connectedDevices, (devices) {
      if (ugvDeviceId != null &&
          bleController.isDeviceConnected(ugvDeviceId!)) {
        if (_connectionSnackbarShown) {
          _connectionSnackbarShown = false; // Resetear la bandera
          Get.snackbar(
              "Conexión Restaurada", "El UGV está nuevamente conectado.",
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.accentColor, // Color de éxito
              colorText: AppColors.backgroundWhite,
              duration: const Duration(seconds: 2));
        }
      } else {
        _connectionSnackbarShown = false; // Permitir que se muestre de nuevo
        _awaitingFinalTForManualControlsReactivation.value = false;
        // La lógica de desconexión y finalización de sesión ya se maneja en el listener de isUgvConnected
      }
    });

    /// Escucha los datos recibidos del UGV. Específicamente, reacciona al comando 'T' (endAutoMode).
    /// El comando 'T' indica que el ciclo de modo automático en el ESP32 ha finalizado.
    ever(bleController.receivedData, (String? data) async {
      if (data == BleController.endAutoMode) {
        _logger.i("Received 'T' from ESP32. Automatic mode cycle ended.");

        if (_isExecutingLoadedRoute.value) {
          // Caso 1: Ejecución de una ruta cargada. Esto completa la ruta.
          _logger.i("Loaded route execution finished.");
          _isExecutingLoadedRoute.value = false;
          _loadedRouteCommands.clear();
          await _updateSessionMode(
              'executed'); // Asegurar await para la actualización de BD
          Get.snackbar(
              'Ruta Completada', 'La ejecución de la ruta ha finalizado.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.success,
              colorText: AppColors.backgroundWhite);
        } else if (_awaitingFinalTForManualControlsReactivation.value) {
          // Caso 2: El usuario ha desactivado manualmente el modo automático y ahora se recibe 'T'.
          // Esto significa que el UGV ha completado su secuencia automática actual debido a la intervención del usuario.
          _logger.i(
              "User manually disabled auto mode, final 'T' received. No re-send 'A'.");
          _awaitingFinalTForManualControlsReactivation.value =
              false; // Reiniciar la bandera
          bleController.isAutomaticMode.value =
              false; // Asegurar que el estado de la app refleje la parada manual
          Get.snackbar('Modo Automático Finalizado',
              'El ciclo automático ha terminado definitivamente.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.info,
              colorText: AppColors.backgroundBlack);
        } else if (bleController.isAutomaticMode.value) {
          // Caso 3: Modo automático interno iniciado por la app, y el usuario NO lo ha desactivado manualmente.
          // Esto implica el deseo de un bucle continuo del comportamiento automático interno del UGV.
          _logger.i(
              "App-initiated auto mode active and 'T' received. Re-sending 'A' to continue loop.");
          _sendBleCommand(BleController.startAutoMode,
              isInternal: true, requiresSessionForLogging: false);
          Get.snackbar(
              'Ciclo Automático', 'Reiniciando el ciclo automático del UGV.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.info,
              colorText: AppColors.backgroundBlack,
              duration: const Duration(seconds: 2));
          // bleController.isAutomaticMode.value se mantiene true
        } else {
          // Caso 4: 'T' recibido inesperadamente o cuando ningún modo automático estaba activo o pendiente de desactivación por el usuario.
          _logger.w(
              "Received 'T' from ESP32 unexpectedly. No active auto mode or pending deactivation.");
        }
      }
    });
  }

  /// Vincula el estado `isRecording` del `BleController` con el `RxBool` local.
  void _bindRecordingState() {
    ever(bleController.isRecording, (recording) {
      _isRecording.value = recording;
    });
  }

  /// Inicializa `ugvDeviceId` y configura listeners para mantenerlo actualizado.
  /// Busca el ID del dispositivo UGV en las características conectadas.
  void _initUgvDeviceId() {
    // Primera verificación en initState
    _updateUgvDeviceIdFromCharacteristics();

    /// Escucha los cambios en el mapa de dispositivos conectados para actualizar ugvDeviceId.
    /// Esto es importante si el dispositivo se desconecta y reconecta con un ID diferente.
    ever(bleController.connectedDevices, (devices) {
      _updateUgvDeviceIdFromCharacteristics();
    });

    /// También escucha directamente los cambios en el mapa de características conectadas.
    /// Esto es más robusto y asegura que el ugvDeviceId se actualice cuando las características
    /// específicas del UGV estén disponibles o dejen de estarlo.
    ever(bleController.connectedCharacteristics, (characteristics) {
      _updateUgvDeviceIdFromCharacteristics();
    });
  }

  /// Función auxiliar para actualizar el `ugvDeviceId` basándose en las características BLE conectadas.
  /// Se asegura de que `ugvDeviceId` sea el ID del dispositivo con la característica UGV, o `null` si no se encuentra.
  void _updateUgvDeviceIdFromCharacteristics() {
    final ugvEntry =
        bleController.connectedCharacteristics.entries.firstWhereOrNull(
      (entry) =>
          entry.value.uuid.toString().toLowerCase() ==
          BleController.characteristicUuidUGV,
    );
    if (ugvEntry != null) {
      ugvDeviceId = ugvEntry.key;
      _logger.i("ugvDeviceId actualizado a: $ugvDeviceId");
    } else {
      ugvDeviceId =
          null; // Asegura que sea null si la característica UGV no está presente
      _logger.i(
          "ugvDeviceId establecido en null (característica UGV no encontrada).");
    }
  }

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE SESIÓN Y COMUNICACIÓN BLE
  //----------------------------------------------------------------------------

  /// Muestra el diálogo para crear una nueva sesión de operación (ruta).
  /// Permite al usuario introducir un título, descripción y número de ruta.
  Future<void> _showCreateNewRouteDialog() async {
    if (_currentActiveSession.value != null) {
      Get.snackbar('Advertencia',
          'Ya hay una operación activa. Finalícela para crear una nueva.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: AppColors.textPrimary);
      return;
    }

    String? operationName;
    String? description;
    int? routeNumber;

    await Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.backgroundWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Crear Nueva Ruta',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary, // Color de título más vibrante
                  fontWeight: FontWeight.bold,
                )),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Título de la Ruta',
                  hintText: 'Ej. Ruta Estacionamiento Norte',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.drive_eta, color: AppColors.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color:
                              AppColors.neutralLight)), // Corrected BorderSide
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2)), // Corrected BorderSide
                ),
                onChanged: (value) => operationName = value,
              ),
              const SizedBox(height: 15),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Descripción de la Ruta',
                  hintText:
                      'Notas sobre el recorrido (ej. obstáculos, objetivo)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      Icon(Icons.description, color: AppColors.secondary1),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color:
                              AppColors.neutralLight)), // Corrected BorderSide
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.secondary1,
                          width: 2)), // Corrected BorderSide
                ),
                onChanged: (value) => description = value,
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 15),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Número de Ruta (Opcional)',
                  hintText: 'Ej. 1, 2, 3...',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.numbers, color: AppColors.accent),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color:
                              AppColors.neutralLight)), // Corrected BorderSide
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.accent,
                          width: 2)), // Corrected BorderSide
                ),
                onChanged: (value) => routeNumber = int.tryParse(value),
              ),
            ],
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (operationName != null && operationName!.isNotEmpty) {
                Get.back(); // Cierra el diálogo
                _startOperationSession(
                  operationName: operationName,
                  description: description,
                  routeNumber: routeNumber,
                );
              } else {
                Get.snackbar('Error', 'El Título de la Ruta es obligatorio',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.error,
                    colorText: AppColors.backgroundWhite);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.backgroundWhite,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 5,
            ),
            child: const Text('Crear Ruta'),
          ),
        ],
      ),
    );
  }

  /// Inicia una nueva sesión de operación UGV con estado 'pending_record'.
  /// Una vez creada, la sesión se considera activa para grabar o cargar rutas.
  Future<void> _startOperationSession(
      {String? operationName, String? description, int? routeNumber}) async {
    _logger.i('Attempting to create new route session: $operationName');
    final OperationSession? session =
        await _operationDataService.createOperationSession(
      operationName: operationName,
      description: description,
      mode: 'pending_record', // Nuevo modo: esperando para ser grabado
      routeNumber: routeNumber,
    );

    if (session != null) {
      _currentActiveSession.value = session;
      _resetRecorrido(); // Reinicia el mapa visual para la nueva sesión
      _loadedRouteCommands
          .clear(); // Limpiar cualquier ruta cargada previamente
      _isExecutingLoadedRoute.value = false;
      bleController.isAutomaticMode.value =
          false; // Asegurar que el modo auto esté apagado
      _logger.i(
          'UGV Route Session created with ID: ${session.id} and mode: ${session.mode}');
      Get.snackbar('Ruta Creada', 'Ahora puede grabar o cargar una ruta.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: AppColors.backgroundWhite);
    } else {
      _logger.e('Failed to create UGV Operation Session.');
      Get.snackbar('Error', 'No se pudo crear la sesión de ruta.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite);
    }
  }

  /// Actualiza el modo de la sesión de operación actual en la base de datos.
  /// También actualiza el objeto `_currentActiveSession` reactivo.
  Future<void> _updateSessionMode(String newMode) async {
    if (_currentActiveSession.value != null) {
      _logger.i(
          'Updating session ${_currentActiveSession.value!.id} mode to $newMode');
      final bool success =
          await _operationDataService.updateOperationSessionMode(
        _currentActiveSession.value!.id,
        newMode,
      );
      if (success) {
        _currentActiveSession.value!.mode =
            newMode; // Actualizar el objeto reactivo
        _currentActiveSession.refresh(); // Forzar actualización de Obx
        _logger.i('Session mode updated to $newMode');
      } else {
        _logger.e('Failed to update session mode to $newMode');
      }
    }
  }

  /// Finaliza la sesión de operación UGV actualmente activa.
  /// Si hay grabación o ejecución en curso, las detiene primero.
  /// [showSnackbar]: Si es `false`, suprime la visualización del SnackBar predeterminado.
  Future<void> _endUgvSession({bool showSnackbar = true}) async {
    if (_currentActiveSession.value == null) {
      if (showSnackbar) {
        Get.snackbar(
            'Advertencia', 'No hay una operación activa para finalizar.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.warning,
            colorText: AppColors.textPrimary);
      }
      return;
    }

    // Si la función es llamada por _toggleRecording (al detener grabación),
    // la lógica de mensajes la maneja _toggleRecording.
    // Solo se realiza la llamada al servicio para finalizar.
    if (_isRecording.value) {
      if (_currentActiveSession.value != null) {
        await _operationDataService
            .endOperationSession(_currentActiveSession.value!.id);
        _currentActiveSession.value = null; // Limpiar la sesión activa.
        _logger.i('UGV Operation Session ended by recording stop.');
      }
      // No mostrar snackbar aquí, _toggleRecording mostrará uno personalizado.
      return;
    }

    // Lógica para otros casos (desconexión, interrupción manual no asociada a grabación)
    _logger.i(
        'Attempting to end UGV operation session: ${_currentActiveSession.value!.id}');

    final bool success = await _operationDataService.endOperationSession(
      _currentActiveSession.value!.id,
    );
    if (success) {
      _currentActiveSession.value = null; // Limpia la sesión activa.
      _loadedRouteCommands.clear(); // Limpiar comandos cargados
      _isExecutingLoadedRoute.value = false;
      _isRecording.value = false;
      bleController.isAutomaticMode.value = false;
      _awaitingFinalTForManualControlsReactivation.value = false; // Resetear
      _logger.i('UGV Operation Session ended.');
      if (showSnackbar) {
        Get.snackbar('Operación Finalizada', 'La sesión ha sido terminada.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.success,
            colorText: AppColors.backgroundWhite);
      }
    } else {
      _logger.e('Failed to end UGV Operation Session.');
      if (showSnackbar) {
        Get.snackbar('Error', 'No se pudo finalizar la sesión.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: AppColors.backgroundWhite);
      }
    }
  }

  /// Inicia el movimiento del UGV en una dirección específica.
  /// Los controles manuales requieren solo que el UGV esté conectado.
  void _startMovement(String command) {
    final bool manualControlsEnabled = bleController.isUgvConnected.value;
    _logger.d(
        "Attempting manual movement for command: $command. UGV Connected: $manualControlsEnabled, ugvDeviceId: $ugvDeviceId");

    if (!manualControlsEnabled) {
      _showControlDisabledSnackbar(); // Este snackbar ahora solo aparecerá si el UGV no está conectado.
      return;
    }

    if (_lastSentDirectionalCommand != command) {
      _lastSentDirectionalCommand = command;
      // No se requiere sesión para enviar comando manual, solo para registro si se está grabando.
      _sendBleCommand(command, requiresSessionForLogging: false);
      _updatePosition(command); // Actualiza la posición visual en el mapa.
    }
  }

  /// Detiene el movimiento del UGV.
  /// Solo permite detener el movimiento si el UGV está conectado.
  void _stopMovement() {
    final bool manualControlsEnabled = bleController.isUgvConnected.value;
    _logger.d(
        "Attempting to stop movement. UGV Connected: $manualControlsEnabled, ugvDeviceId: $ugvDeviceId");

    if (!manualControlsEnabled) {
      return; // El SnackBar ya se mostró en onTapDown
    }

    // No se requiere sesión para enviar comando manual, solo para registro si se está grabando.
    _sendBleCommand(BleController.stop, requiresSessionForLogging: false);
    _lastSentDirectionalCommand = BleController.stop;
  }

  /// Interrumpe el movimiento actual del UGV (usado por el botón STOP general).
  /// Este botón SIEMPRE debe funcionar si el UGV está conectado, anulando cualquier modo.
  void _interruptMovement() {
    if (!bleController.isUgvConnected.value) {
      _showConnectionWarningSnackbar(
          'UGV no conectado para detener el movimiento.');
      return;
    }

    // No se requiere sesión para enviar comando de interrupción, solo para registro si se está grabando.
    _sendBleCommand(BleController.interruption,
        requiresSessionForLogging: false);
    _lastSentDirectionalCommand = BleController.interruption;

    bleController.isAutomaticMode.value = false;
    _isExecutingLoadedRoute.value = false;
    _awaitingFinalTForManualControlsReactivation.value = false;

    // Solo actualiza el modo de sesión si hay una sesión activa y estaba en un modo automático.
    if (_currentActiveSession.value != null) {
      if (_currentActiveSession.value?.mode == 'auto_executing' ||
          _currentActiveSession.value?.mode == 'auto_executing_default') {
        _updateSessionMode('interrupted');
      }
    }
  }

  /// Envía un comando BLE al dispositivo UGV y registra en la base de datos (si se está grabando).
  /// Si el UGV no está conectado, muestra una advertencia y no envía el comando.
  /// [requiresSessionForLogging]: Si `true`, exige una sesión activa para que el comando sea registrado en la BD.
  /// El comando BLE siempre se intenta enviar si el UGV está conectado, la lógica de registro es independiente.
  void _sendBleCommand(String commandToSend,
      {bool isInternal = false, bool requiresSessionForLogging = false}) {
    if (ugvDeviceId == null || !bleController.isDeviceConnected(ugvDeviceId!)) {
      if (!isInternal) {
        // Solo muestra snackbar si no es un comando interno que se está intentando enviar
        _showConnectionWarningSnackbar(
            'No hay UGV conectado para enviar comandos.');
      }
      return; // Si el UGV no está conectado, no se puede enviar el comando. Salir aquí.
    }

    // El UGV está conectado, se procede a enviar el comando independientemente de la sesión para el registro.
    _logger.d(
        "Intentando enviar comando BLE: $commandToSend al UGV ID: $ugvDeviceId");
    bleController.sendData(ugvDeviceId!, commandToSend);
    _connectionSnackbarShown =
        false; // Restablece la bandera del snackbar después de un intento de envío exitoso.

    // Ahora, se maneja el registro por separado.
    // Un comando se registra SOLO SI:
    // 1. `requiresSessionForLogging` es VERDADERO para esta llamada de comando específica.
    // 2. Una sesión (`_currentActiveSession.value`) ESTÁ activa.
    // 3. La sesión activa está en modo 'recording'.
    if (requiresSessionForLogging) {
      if (_currentActiveSession.value != null) {
        if (_currentActiveSession.value?.mode == 'recording') {
          _ugvService.createUgvTelemetry(
            sessionId: _currentActiveSession.value!.id,
            commandType: _getCommandType(commandToSend),
            commandValue: commandToSend,
            timestamp: DateTime.now(),
            status: 'enviado',
            ugvId: ugvDeviceId,
            notes: 'Comando enviado desde la app durante grabación.',
            latitude: null,
            longitude: null,
          );
        } else {
          // Si requiresSessionForLogging es verdadero, pero no está en modo de grabación, o el modo es incorrecto.
          _logger.w(
              'Intento de registrar comando "$commandToSend" que requiere sesión para registro, pero la sesión no está en modo "recording" o el modo es incorrecto.');
        }
      } else {
        // Si requiresSessionForLogging es verdadero, pero no hay una sesión activa.
        // Muestra snackbar solo si no es un comando interno que solo intenta registrar.
        if (!isInternal) {
          _showSessionRequiredSnackbar();
        }
        _logger.w(
            'Intento de registrar comando "$commandToSend" que requiere sesión para registro, pero no hay sesión activa.');
      }
    }
  }

  /// Mapea el comando BLE a un tipo de comando más descriptivo para la base de datos.
  String _getCommandType(String command) {
    switch (command) {
      case BleController.moveForward:
        return 'MOVE_FORWARD';
      case BleController.moveBack:
        return 'MOVE_BACK';
      case BleController.moveLeft:
        return 'TURN_LEFT';
      case BleController.moveRight:
        return 'TURN_RIGHT';
      case BleController.stop:
        return 'STOP';
      case BleController.interruption:
        return 'MANUAL_INTERRUPTION';
      case BleController.startRecording:
        return 'START_RECORDING';
      case BleController.stopRecording:
        return 'STOP_RECORDING';
      case BleController.startAutoMode:
        return 'START_AUTO_MODE';
      case BleController.endAutoMode:
        return 'END_AUTO_MODE';
      default:
        return 'UNKNOWN_COMMAND';
    }
  }

  /// Muestra un SnackBar de advertencia si no hay UGV conectado.
  /// Controla la visibilidad para evitar múltiples SnackBar.
  void _showConnectionWarningSnackbar(String message) {
    if (!_connectionSnackbarShown) {
      Get.snackbar("Advertencia", message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite,
          duration: const Duration(seconds: 3));
      _connectionSnackbarShown = true;
    }
  }

  /// Muestra un SnackBar si se requiere iniciar una sesión de operación para una acción.
  void _showSessionRequiredSnackbar() {
    Get.snackbar("Sesión Requerida",
        "Por favor, cree una operación UGV antes de ejecutar esta acción.", // Mensaje más general
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning, // Color de advertencia
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 3));
  }

  /// Muestra un SnackBar si los controles están deshabilitados (normalmente por UGV no conectado).
  void _showControlDisabledSnackbar() {
    Get.snackbar("Controles Deshabilitados",
        "El UGV no está conectado.", // Mensaje simplificado y directo
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.info, // Un color informativo
        colorText: AppColors.backgroundBlack,
        duration: const Duration(seconds: 3));
  }

  /// Actualiza la posición simulada del UGV en el mapa visual.
  void _updatePosition(String direction) {
    setState(() {
      Offset lastPosition = recorridoPoints.last;
      Offset newPosition = lastPosition;

      switch (direction) {
        case BleController.moveForward:
          newPosition = Offset(lastPosition.dx, lastPosition.dy - stepSize);
          break;
        case BleController.moveBack:
          newPosition = Offset(lastPosition.dx, lastPosition.dy + stepSize);
          break;
        case BleController.moveLeft:
          newPosition = Offset(lastPosition.dx - stepSize, lastPosition.dy);
          break;
        case BleController.moveRight:
          newPosition = Offset(lastPosition.dx + stepSize, lastPosition.dy);
          break;
        default:
          return;
      }

      if (newPosition != lastPosition) {
        recorridoPoints = List.from(recorridoPoints)..add(newPosition);
        currentPosition = newPosition;
      }
    });
  }

  /// Alterna el estado de grabación del recorrido del UGV.
  /// Si está grabando, lo detiene y guarda la ruta, finalizando la sesión.
  /// Si no está grabando, lo inicia (requiere sesión pre-existente).
  void _toggleRecording() async {
    if (!bleController.isUgvConnected.value) {
      _showConnectionWarningSnackbar(
          'El UGV debe estar conectado para grabar una ruta.');
      return;
    }

    if (_isRecording.value) {
      // Lógica para DETENER la grabación
      _sendBleCommand(BleController.stopRecording,
          isInternal: true, requiresSessionForLogging: true);
      _isRecording.value = false;
      await _updateSessionMode('recorded'); // Marcar la sesión como grabada

      // Finalizar la sesión activa. Suprimir el SnackBar predeterminado de _endUgvSession.
      await _endUgvSession(showSnackbar: false);

      Get.snackbar('Ruta Guardada y Sesión Finalizada',
          'La ruta ha sido guardada y la sesión cerrada.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: AppColors.backgroundWhite);
    } else {
      // Lógica para INICIAR la grabación
      // Requiere una sesión activa para poder asociar los datos grabados.
      if (_currentActiveSession.value == null) {
        _showSessionRequiredSnackbar();
        return;
      }

      // Verificación adicional de los modos de sesión permitidos para iniciar grabación.
      if (_currentActiveSession.value?.mode != 'pending_record' &&
          _currentActiveSession.value?.mode != 'recorded' &&
          _currentActiveSession.value?.mode != 'interrupted' &&
          _currentActiveSession.value?.mode != 'executed') {
        Get.snackbar('Error',
            'La sesión actual no está en un estado válido para grabar. Cree una nueva ruta si es necesario.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: AppColors.backgroundWhite);
        return;
      }

      _sendBleCommand(BleController.startRecording,
          isInternal: true, requiresSessionForLogging: true);
      _isRecording.value = true;
      await _updateSessionMode(
          'recording'); // Marcar la sesión en modo grabación
      _loadedRouteCommands.clear(); // Limpiar si había una ruta cargada
      _isExecutingLoadedRoute.value = false; // Desactivar ejecución de ruta
      bleController.isAutomaticMode.value =
          false; // Desactivar modo automático interno
      Get.snackbar(
          'Grabación Iniciada', 'El recorrido del UGV se está grabando.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.info,
          colorText: AppColors.backgroundBlack);
    }
    _connectionSnackbarShown = false;
  }

  /// Permite descartar una ruta que se está grabando actualmente sin guardarla.
  /// Elimina los datos asociados a la sesión de la base de datos.
  Future<void> _discardCurrentRecording() async {
    if (!_isRecording.value || _currentActiveSession.value == null) {
      Get.snackbar('Advertencia', 'No hay una grabación activa para descartar.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: AppColors.textPrimary);
      return;
    }

    // Diálogo de confirmación antes de descartar permanentemente.
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.backgroundWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Descartar Ruta Grabada',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                )),
        content: Text(
            '¿Está seguro de que desea descartar esta ruta y eliminar sus datos? Esta acción es irreversible.',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textPrimary)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.backgroundWhite),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Enviar comando para detener grabación al UGV (interno) si está conectado
        if (bleController.isUgvConnected.value && ugvDeviceId != null) {
          _sendBleCommand(BleController.stopRecording,
              isInternal: true, requiresSessionForLogging: false);
        }
        bleController.isRecording.value =
            false; // Actualizar estado en el controller

        // 2. Eliminar la sesión de la base de datos y todos sus registros asociados.
        final String sessionIdToDelete = _currentActiveSession.value!.id;
        final bool deleted = await _operationDataService
            .deleteOperationSession(sessionIdToDelete);

        if (deleted) {
          _currentActiveSession.value = null; // Limpiar la sesión activa
          _isRecording.value =
              false; // Asegurar que el estado de grabación esté apagado
          recorridoPoints = [
            const Offset(0, 0)
          ]; // Limpiar puntos del mapa visual
          currentPosition = const Offset(0, 0); // Resetear posición actual

          Get.snackbar('Ruta Descartada',
              'La grabación y sus datos han sido eliminados.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.success,
              colorText: AppColors.backgroundWhite);
          _logger
              .i('Recording session $sessionIdToDelete discarded and deleted.');
        } else {
          Get.snackbar('Error',
              'No se pudo eliminar la ruta grabada de la base de datos.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.error,
              colorText: AppColors.backgroundWhite);
          _logger.e(
              'Failed to delete recording session $sessionIdToDelete from DB.');
        }
      } catch (e) {
        _logger.e('Error discarding recording: $e');
        Get.snackbar('Error', 'Ocurrió un error al descartar la ruta: $e',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: AppColors.backgroundWhite);
      }
    }
  }

  /// Muestra la pantalla de rutas guardadas del UGV y, al seleccionar una,
  /// carga sus comandos de telemetría para su posible ejecución.
  Future<void> _showUgvRoutesScreen() async {
    final OperationSession? selectedSession =
        await Get.to<OperationSession?>(() => const UgvRoutesScreen());

    if (selectedSession != null) {
      // Si se seleccionó una ruta, se establece como la sesión activa
      _currentActiveSession.value = selectedSession;
      _resetRecorrido(); // Reiniciar el mapa para la nueva ruta

      if (!bleController.isUgvConnected.value) {
        _showConnectionWarningSnackbar(
            'UGV no conectado. Conéctelo para ejecutar la ruta "${selectedSession.operationName}".');
        _loadedRouteCommands
            .clear(); // No cargar comandos si no hay conexión para ejecutar
        return;
      }

      // Cargar los comandos de telemetría de la ruta seleccionada
      final List<Map<String, dynamic>> telemetryData =
          await _ugvService.getUgvTelemetry(
        sessionId: selectedSession.id,
      );
      _loadedRouteCommands.value =
          telemetryData.map((e) => e['command_value'] as String).toList();

      if (_loadedRouteCommands.isNotEmpty) {
        Get.snackbar('Ruta Cargada',
            'Ruta "${selectedSession.operationName}" lista para ejecución.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.success,
            colorText: AppColors.backgroundWhite);
      } else {
        Get.snackbar('Advertencia', 'La ruta seleccionada no tiene comandos.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.warning,
            colorText: AppColors.textPrimary);
        _loadedRouteCommands.clear(); // Limpiar si no hay comandos
      }
    }
  }

  /// Alterna el estado del modo automático del UGV.
  /// Puede activar el modo automático interno del UGV o ejecutar una ruta cargada.
  void _toggleAutomaticMode() async {
    // PRE-CONDICIONES para activar/desactivar cualquier modo automático
    if (!bleController.isUgvConnected.value) {
      _showConnectionWarningSnackbar(
          'El UGV debe estar conectado para activar el modo automático.');
      return;
    }
    if (_isRecording.value) {
      Get.snackbar('Advertencia',
          'No se puede activar el modo automático mientras se está grabando.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: AppColors.textPrimary);
      return;
    }

    // Determina si actualmente está en un estado automático (ruta o modo interno)
    if (_isExecutingLoadedRoute.value || bleController.isAutomaticMode.value) {
      // Lógica para DETENER el modo automático actual (el usuario presiona "Detener Auto")
      _logger.i(
          "Deteniendo el modo automático (ruta cargada o auto interno del UGV) desde la App (parada manual del usuario).");
      // ELIMINADO: _interruptMovement(); // Ya no se envía el comando 'P' aquí al detener desde el botón Auto

      // Establecer la bandera en true ya que ahora estamos esperando la 'T' del UGV para confirmar que su ciclo terminó debido a nuestra parada.
      _awaitingFinalTForManualControlsReactivation.value = true;
      // También, desactivar explícitamente bleController.isAutomaticMode.value aquí
      // para que el listener de 'T' sepa que fue una parada manual.
      bleController.isAutomaticMode.value =
          false; // Esto es crítico para la lógica del listener de 'T'.

      Get.snackbar(
          'Ejecución Detenida', 'La ejecución automática ha sido interrumpida.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.info,
          colorText: AppColors.backgroundBlack);
    } else {
      // Lógica para INICIAR el modo automático (el usuario presiona "Auto")
      if (_loadedRouteCommands.isNotEmpty) {
        // Caso 1: Ejecutar una ruta cargada (esto se ejecuta una vez, no en bucle)
        if (_currentActiveSession.value == null) {
          _showSessionRequiredSnackbar();
          return; // Sale, no se puede ejecutar una ruta cargada sin una sesión para registro
        }
        _logger.i("Iniciando la ejecución de la ruta cargada desde la App.");
        _isExecutingLoadedRoute.value = true;
        await _updateSessionMode(
            'auto_executing'); // Actualiza el modo de la sesión
        Get.snackbar('Ruta Ejecutando', 'La ruta cargada está en ejecución.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.success,
            colorText: AppColors.backgroundWhite);

        // Envía comandos de la ruta uno por uno con un pequeño retraso
        for (String command in _loadedRouteCommands) {
          if (!_isExecutingLoadedRoute.value) {
            // Verifica si la ejecución fue interrumpida
            _logger.i("Ejecución interrumpida para la ruta cargada.");
            break;
          }
          _sendBleCommand(command,
              requiresSessionForLogging:
                  true); // Se requiere registro para comandos de ruta cargada
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (_isExecutingLoadedRoute.value) {
          // Solo si no fue interrumpida antes de completar
          _logger.i("Ejecución de ruta cargada completada.");
          _isExecutingLoadedRoute.value = false;
          _loadedRouteCommands
              .clear(); // Limpia los comandos después de ejecutar
          await _updateSessionMode(
              'executed'); // Actualiza el modo de la sesión a 'ejecutada'
          Get.snackbar(
              'Ruta Completada', 'La ejecución de la ruta ha finalizado.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.success,
              colorText: AppColors.backgroundWhite);
        }
      } else {
        // Caso 2: Activar el modo automático interno del UGV (envía el comando 'A'). Esto debería entrar en bucle.
        _logger.i(
            "Activando el modo automático interno desde la App (enviando 'A').");
        _sendBleCommand(BleController.startAutoMode,
            isInternal: true,
            requiresSessionForLogging:
                false); // No se requiere sesión para enviar este comando al UGV

        bleController.isAutomaticMode.value =
            true; // La app quiere que el modo automático esté ACTIVO
        _awaitingFinalTForManualControlsReactivation.value =
            false; // No estamos esperando una 'T' para detener el auto

        // Si hay una sesión activa en este momento, actualiza su modo y registra el evento.
        if (_currentActiveSession.value != null) {
          await _updateSessionMode(
              'auto_executing_default'); // Marca la sesión como ejecutando modo auto default
          // Segunda verificación después del await para evitar Null check operator error si la sesión se anula.
          if (_currentActiveSession.value != null) {
            _ugvService.createUgvTelemetry(
              sessionId: _currentActiveSession.value!.id,
              commandType: _getCommandType(BleController.startAutoMode),
              commandValue: BleController.startAutoMode,
              timestamp: DateTime.now(),
              status: 'enviado',
              ugvId: ugvDeviceId,
              notes: 'Modo automático interno del UGV iniciado.',
              latitude: null,
              longitude: null,
            );
          }
        }
        Get.snackbar('Modo Automático Activado',
            'El UGV ha iniciado su modo automático interno.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.success,
            colorText: AppColors.backgroundWhite);
      }
    }
    _connectionSnackbarShown = false;
  }

  /// Reinicia el recorrido en el mapa visual.
  /// Este botón SIEMPRE debe funcionar, ya que solo afecta la UI.
  void _resetRecorrido() {
    setState(() {
      recorridoPoints = [const Offset(0, 0)];
      currentPosition = const Offset(0, 0);
    });
    Get.snackbar(
        "Mapa Reiniciado", "El recorrido del mapa ha sido restablecido.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.info,
        colorText: AppColors.backgroundBlack,
        duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    super.dispose();
    // No es necesario cancelar listeners aquí si GetX los maneja automáticamente
    // al ser el controlador descartado, o si se usan `ever` que tienen su propia gestión.
  }

  //----------------------------------------------------------------------------
  // SECCIÓN DE INTERFAZ DE USUARIO (BUILD METHODS)
  //----------------------------------------------------------------------------

  /// Widget para mostrar el estado de conexión del UGV.
  /// Muestra si el dispositivo está conectado o desconectado con un indicador visual.
  Widget _buildConnectionStatus(
      ThemeData theme, bool isConnected, String deviceName) {
    return Container(
      width: 250, // Ancho fijo para que quepa en el scroll horizontal
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin:
          const EdgeInsets.symmetric(horizontal: 5), // Espacio entre elementos
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.accentColor.withOpacity(0.15) // Color de éxito
            : AppColors.error.withOpacity(0.15), // Color de error
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? AppColors.accentColor : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? AppColors.accentColor : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isConnected
                  ? '$deviceName: Conectado'
                  : '$deviceName: Desconectado',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isConnected ? AppColors.accentColor : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el indicador de estado de la sesión de operación UGV.
  /// Muestra el estado actual de la sesión (grabando, ejecutando, inactiva, etc.).
  Widget _buildSessionStatusIndicator(ThemeData theme) {
    return Obx(() {
      final bool isActive = _currentActiveSession.value != null;
      String statusText = 'Operación Inactiva';
      Color statusColor = AppColors.secondary1;

      if (isActive) {
        switch (_currentActiveSession.value?.mode) {
          case 'pending_record':
            statusText = 'Ruta Pendiente Grabación';
            statusColor = AppColors.warning;
            break;
          case 'recording':
            statusText =
                'Grabando Ruta: ${_currentActiveSession.value!.operationName ?? "Sin Nombre"}'; // Usar null-aware
            statusColor = AppColors.error; // Rojo para grabar
            break;
          case 'recorded':
            statusText =
                'Ruta Grabada: ${_currentActiveSession.value!.operationName ?? "Sin Nombre"}';
            statusColor = AppColors.success;
            break;
          case 'auto_executing':
            statusText =
                'Ejecutando Ruta: ${_currentActiveSession.value!.operationName ?? "Sin Nombre"}';
            statusColor = AppColors.accentColor;
            break;
          case 'auto_executing_default':
            statusText = 'Modo Auto UGV Activo';
            statusColor = AppColors.accentColor;
            break;
          case 'executed':
            statusText =
                'Ruta Ejecutada: ${_currentActiveSession.value!.operationName ?? "Sin Nombre"}';
            statusColor = AppColors.info;
            break;
          case 'interrupted':
            statusText = 'Operación Interrumpida';
            statusColor = AppColors.error;
            break;
          default:
            statusText =
                'Operación Activa: ${_currentActiveSession.value!.operationName ?? "Sin Nombre"}';
            statusColor = AppColors.accentColor;
        }
      }

      return Container(
        width: 250, // Ancho fijo para el indicador
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: statusColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.drive_eta : Icons.not_interested,
              color: statusColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                statusText,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Construye la sección que contiene los indicadores de estado y los botones
  /// para gestionar las sesiones de operación (crear, grabar, rutas, descartar).
  Widget _buildIndicatorsAndSessionButtonsSection(BuildContext context) {
    final double sectionWidth = 370;

    return SizedBox(
      width: sectionWidth,
      // SingleChildScrollView para manejar el desbordamiento vertical
      child: SingleChildScrollView(
        child: Column(
          // mainAxisSize ya no es min, ya que SingleChildScrollView le da espacio ilimitado
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Indicadores de conexión y sesión
            Obx(() => _buildConnectionStatus(
                Theme.of(context),
                bleController.isUgvConnected.value,
                BleController.deviceNameUGV)),
            const SizedBox(height: 10),
            _buildSessionStatusIndicator(Theme.of(context)),
            const SizedBox(height: 20),

            // Botones de acción principales (Crear, Grabar/Detener, Rutas, Descartar)
            Obx(() {
              final bool isUgvConnected = bleController.isUgvConnected.value;
              final bool hasActiveSession = _currentActiveSession.value != null;
              final bool isRecordingActive = _isRecording.value;
              final bool isExecutingRoute = _isExecutingLoadedRoute.value;
              final bool isAutomaticModeActive =
                  bleController.isAutomaticMode.value;

              if (isRecordingActive) {
                // Si se está grabando, mostrar botones de Detener Grab. y Descartar Ruta
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Detener Grab.',
                            icon: Icons.pause_circle_filled,
                            onPressed: isUgvConnected
                                ? _toggleRecording // Solo detener grabación si está conectado
                                : null,
                            isActive:
                                true, // Siempre activo visualmente si está grabando
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Descartar Ruta',
                            icon: Icons.cancel,
                            onPressed: hasActiveSession
                                ? _discardCurrentRecording // Descartar no depende de la conexión UGV
                                : null,
                            isActive: false, // No es un modo activo per se
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Si no se está grabando, mostrar botones de Crear, Grabar, Rutas
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Botón "Crear Nueva Ruta"
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Crear Ruta',
                            icon: Icons.add_circle,
                            onPressed: (!hasActiveSession ||
                                        (_currentActiveSession.value?.mode ==
                                                'recorded' ||
                                            _currentActiveSession.value?.mode ==
                                                'executed' ||
                                            _currentActiveSession.value?.mode ==
                                                'interrupted' ||
                                            _currentActiveSession.value?.mode ==
                                                'pending_record')) &&
                                    !isExecutingRoute &&
                                    !isAutomaticModeActive
                                ? _showCreateNewRouteDialog
                                : null,
                            isActive: false,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón "Grabar Recorrido" (Habilitado si hay sesión activa para grabar y conectado)
                        Expanded(
                          child: _buildCompactActionButton(
                            text: 'Grabar Ruta',
                            icon: Icons.fiber_manual_record,
                            onPressed:
                                (isUgvConnected && // Debe estar conectado para grabar
                                        !isAutomaticModeActive && // No debe estar en modo automático
                                        !isExecutingRoute && // No debe estar ejecutando una ruta
                                        (hasActiveSession && // Debe haber una sesión activa (creada)
                                            (_currentActiveSession.value?.mode ==
                                                    'pending_record' ||
                                                _currentActiveSession
                                                        .value?.mode ==
                                                    'recorded' ||
                                                _currentActiveSession
                                                        .value?.mode ==
                                                    'interrupted' ||
                                                _currentActiveSession
                                                        .value?.mode ==
                                                    'executed')))
                                    ? _toggleRecording
                                    : null,
                            isActive: false,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón "Rutas" (Siempre habilitado para ver el historial de rutas)
                        Expanded(
                          child: _buildCompactActionButton(
                            text:
                                'Rutas', // Cambiado de 'Cargar Ruta' a 'Rutas'
                            icon: Icons.history, // Icono de historial
                            onPressed:
                                _showUgvRoutesScreen, // Siempre accesible
                            isActive: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary, // Fondo consistente
      body: Column(
        // Columna principal de la pantalla
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Encabezado de la pantalla (Fijo)
          Container(
            margin: const EdgeInsets.only(
                right: 16,
                bottom: 10,
                left: 16,
                top: 40), // Añadido top padding
            height: 60,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent, // Color azul profundo para el encabezado
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              'Modo UGV',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.backgroundWhite,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),

          // Sección superior con desplazamiento horizontal (Indicadores, Botones de Sesión, Mapa)
          Expanded(
            // Ocupa el espacio vertical restante y permite el desplazamiento horizontal de su contenido
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Desplazamiento horizontal
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0), // Padding para el contenido
              child: Row(
                // Contenedor de los elementos que se desplazan horizontalmente
                crossAxisAlignment: CrossAxisAlignment
                    .start, // Alinea los elementos al inicio (arriba)
                children: [
                  // Primera "columna" de la fila horizontal: Indicadores y Botones de Sesión
                  SizedBox(
                    width: 370, // Ancho fijo como antes
                    height: screenSize.height *
                        0.5, // Altura limitada para que coincida con el mapa
                    child: _buildIndicatorsAndSessionButtonsSection(context),
                  ),
                  const SizedBox(width: 20),

                  // Segunda "columna" de la fila horizontal: Mapa de Recorrido
                  SizedBox(
                    height: screenSize.height * 0.5, // Altura fija del mapa
                    width: screenSize.width *
                        0.90, // Ancho del mapa dentro del scroll horizontal
                    child: _buildCompactMapaRecorrido(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
              height:
                  12), // Espacio entre la sección desplazable y los controles fijos

          // Sección de control manual del UGV (Fija en la parte inferior)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCompactControlManual(context),
          ),
          const SizedBox(
              height: 12), // Espacio al final de los controles manuales
        ],
      ),
    );
  }

  /// Construye el widget para visualizar el mapa de recorrido del UGV.
  Widget _buildCompactMapaRecorrido(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: AppColors.neutral.withOpacity(0.3)), // Color de borde
        color: AppColors
            .backgroundLight, // Gris claro más oscuro para el fondo del mapa
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: TrayectoriaPainter(recorridoPoints),
      ),
    );
  }

  /// Construye la sección de control manual del UGV, incluyendo botones direccionales,
  /// y botones de Auto, Stop y Reiniciar.
  Widget _buildCompactControlManual(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonSize = constraints.maxWidth * 0.22;

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Botones de Auto, Stop y Reiniciar (agrupados aquí)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón "Auto"
                Expanded(
                  child: Obx(
                    () {
                      // El botón "Auto" está habilitado si el UGV está conectado y no se está grabando.
                      final bool isAutoButtonEnabled =
                          bleController.isUgvConnected.value &&
                              !_isRecording.value;

                      return _buildCompactActionButton(
                        text: bleController.isAutomaticMode.value ||
                                _isExecutingLoadedRoute.value
                            ? 'Detener Auto' // Si está activo, el texto es "Detener Auto"
                            : 'Auto', // Si no está activo, el texto es "Auto"
                        icon: bleController.isAutomaticMode.value ||
                                _isExecutingLoadedRoute.value
                            ? FontAwesomeIcons
                                .circleStop // Icono de detener si está activo (corrección de deprecado)
                            : FontAwesomeIcons
                                .robot, // Icono de robot si no está activo
                        onPressed:
                            isAutoButtonEnabled ? _toggleAutomaticMode : null,
                        isActive: bleController.isAutomaticMode.value ||
                            _isExecutingLoadedRoute.value,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Botón de Stop general
                Expanded(
                    child: Obx(() => _buildCompactActionButton(
                          text: 'Stop',
                          icon: FontAwesomeIcons.stop,
                          onPressed: bleController.isUgvConnected.value
                              ? _interruptMovement // Habilitado si UGV conectado
                              : null,
                          isActive:
                              true, // Siempre activo visualmente si está disponible
                        ))),
                const SizedBox(width: 10),
                // Botón de Reiniciar mapa visual
                Expanded(
                    child: _buildCompactActionButton(
                  text: 'Reiniciar',
                  icon: Icons.refresh,
                  onPressed:
                      _resetRecorrido, // Siempre habilitado, no necesita UGV conectado
                  isActive: false, // No es un modo activo de UGV
                )),
              ],
            ),
            const SizedBox(
                height:
                    20), // Espacio entre los botones de acción y los direccionales

            // Botones direccionales
            Obx(() {
              // Los botones de movimiento estarán habilitados si el UGV está conectado.
              // Esto permite el control manual para anular otros modos si es necesario.
              final bool areMovementButtonsEnabled =
                  bleController.isUgvConnected.value;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDirectionButton(
                    icon: Icons.arrow_upward,
                    command: BleController.moveForward,
                    size: buttonSize,
                    isEnabled: areMovementButtonsEnabled,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDirectionButton(
                        icon: Icons.arrow_back,
                        command: BleController.moveLeft,
                        size: buttonSize,
                        isEnabled: areMovementButtonsEnabled,
                      ),
                      SizedBox(
                          width: constraints.maxWidth *
                              0.2), // Espacio entre Left y Right
                      _buildDirectionButton(
                        icon: Icons.arrow_forward,
                        command: BleController.moveRight,
                        size: buttonSize,
                        isEnabled: areMovementButtonsEnabled,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDirectionButton(
                    icon: Icons.arrow_downward,
                    command: BleController.moveBack,
                    size: buttonSize,
                    isEnabled: areMovementButtonsEnabled,
                  ),
                ],
              );
            }), // Fin de Obx para botones direccionales
          ],
        );
      },
    );
  }

  /// Widget genérico para un botón de acción compacto.
  /// Adapta su apariencia según su estado (habilitado/deshabilitado) y propósito.
  Widget _buildCompactActionButton({
    required String text,
    required IconData icon,
    required Function()?
        onPressed, // onPressed puede ser nulo para deshabilitar
    bool isActive =
        false, // Determina el color del botón (ej. rojo para grabar activo, verde/azul para auto activo)
  }) {
    Color bgColor;
    Color fgColor =
        AppColors.backgroundWhite; // Color de texto blanco por defecto

    if (onPressed == null) {
      bgColor = AppColors.neutral; // Gris si está deshabilitado
    } else {
      if (text.contains('Grabar')) {
        // Para el botón de grabar/detener grabación
        bgColor = isActive
            ? AppColors.error
            : AppColors
                .secondary2; // Rojo para grabando, Verde oscuro para inactivo
      } else if (text.contains('Auto') || text.contains('Detener Auto')) {
        // Para el botón de modo automático
        bgColor = isActive
            ? AppColors.accent
            : AppColors
                .primary; // Azul profundo para auto activo, Verde lima para inactivo
      } else if (text.contains('Rutas')) {
        // Para el botón de rutas
        bgColor = AppColors.info; // Azul claro
      } else if (text.contains('Crear')) {
        // Para el botón de crear ruta
        bgColor = AppColors.primary; // Verde lima
      } else if (text.contains('Descartar')) {
        // Para el botón de descartar ruta
        bgColor = AppColors.neutralDark; // Gris oscuro para descartar
      } else if (text.contains('Stop')) {
        // Para el botón de Stop
        bgColor = AppColors.error;
      } else if (text.contains('Reiniciar')) {
        // Para el botón de Reiniciar
        bgColor = AppColors.accent;
      } else {
        bgColor = AppColors.primary; // Verde lima por defecto
      }
    }

    return SizedBox(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 3,
          shadowColor: bgColor.withOpacity(0.5),
        ),
        icon: FaIcon(icon, size: 16, color: fgColor),
        label: Text(
          text,
          style: TextStyle(fontSize: 13, color: fgColor),
          textAlign: TextAlign.center, // Centrar texto para mini botones
        ),
      ),
    );
  }

  /// Widget genérico para un botón direccional del UGV.
  /// Su habilitación depende del parámetro `isEnabled`.
  Widget _buildDirectionButton({
    required IconData icon,
    required String command,
    required double size,
    bool isEnabled = true, // Parámetro para controlar la habilitación
  }) {
    return GestureDetector(
      onTapDown: isEnabled
          ? (_) => _startMovement(command) // Inicia movimiento al presionar
          : null,
      onTapUp: isEnabled
          ? (_) => _stopMovement()
          : null, // Detiene movimiento al soltar
      onTapCancel: isEnabled
          ? () => _stopMovement()
          : null, // Detiene movimiento si el gesto es cancelado
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors
                  .primaryDark // Color más oscuro del primario si está habilitado
              : AppColors.neutral, // Gris si está deshabilitado
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.backgroundBlack
                  .withOpacity(0.3), // Sombra más oscura
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.backgroundWhite, size: size * 0.5),
      ),
    );
  }
}

/// CustomPainter para dibujar la trayectoria del UGV en el mapa.
/// Dibuja los puntos del recorrido y la posición actual del UGV simulada.
class TrayectoriaPainter extends CustomPainter {
  final List<Offset> points;

  TrayectoriaPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          AppColors.primary // Color de la línea de trayectoria (verde lima)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Offset center = Offset(size.width / 2, size.height / 2);

    if (points.isNotEmpty) {
      Offset startPoint = center;
      for (int i = 0; i < points.length; i++) {
        Offset currentPoint =
            Offset(center.dx + points[i].dx, center.dy + points[i].dy);
        canvas.drawLine(startPoint, currentPoint, paint);
        startPoint = currentPoint;
      }
      // Dibujar la posición actual del UGV (punto final)
      canvas.drawCircle(
          startPoint,
          5,
          paint
            ..color = AppColors.accent); // Punto azul para la posición actual
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
