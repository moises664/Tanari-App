import 'dart:async'; // Necesario para usar Timer

import 'package:flutter/material.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:get/get.dart'; // Importar GetX para inyección y reactividad
import 'package:tanari_app/src/controllers/services/operation_data_service.dart'; // Importar el servicio
import 'package:tanari_app/src/screens/menu/modos_historial/sessions_history_screen.dart';

/// Pantalla principal para el monitoreo de datos ambientales (Modo DP)
///
/// Esta pantalla muestra en tiempo real los valores de los sensores recibidos
/// del dispositivo Tanari DP a través de Bluetooth Low Energy (BLE).
/// Permite al usuario iniciar y detener sesiones de monitoreo, durante las cuales
/// los datos de los sensores son persistidos en una base de datos Supabase.
///
/// Se implementa un mecanismo de "debounce" para controlar la frecuencia
/// de las escrituras a la base de datos, evitando saturarla con datos duplicados
/// o que cambian mínimamente en ráfagas rápidas de BLE.
class ModoMonitoreo extends StatefulWidget {
  const ModoMonitoreo({super.key});

  @override
  State<ModoMonitoreo> createState() => _ModoDPState();
}

/// Estado que gestiona la lógica de carga, actualización y visualización de los datos de los sensores.
class _ModoDPState extends State<ModoMonitoreo> {
  //----------------------------------------------------------------------------
  // VARIABLES DE ESTADO Y CONTROL
  //----------------------------------------------------------------------------

  /// Instancia del [BleController] para manejar la comunicación BLE.
  final BleController _bleController = Get.find<BleController>();

  /// Instancia del [OperationDataService] para interactuar con la base de datos Supabase.
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();

  /// [RxString] para el valor de CO2. Observado por la UI para actualizaciones reactivas.
  final RxString _co2 = '--'.obs;

  /// [RxString] para el valor de CH4. Observado por la UI para actualizaciones reactivas.
  final RxString _ch4 = '--'.obs;

  /// [RxString] para el valor de Temperatura. Observado por la UI para actualizaciones reactivas.
  final RxString _temperatura = '--'.obs;

  /// [RxString] para el valor de Humedad. Observado por la UI para actualizaciones reactivas.
  final RxString _humedad = '--'.obs;

  /// [Rx] que contiene la sesión de operación [OperationSession] actualmente activa.
  /// Se usa para determinar si el monitoreo está en curso y a qué sesión pertenecen los datos.
  final Rx<OperationSession?> _currentActiveSession =
      Rx<OperationSession?>(null);

  /// Contador para la secuencia de lotes de mediciones.
  /// Se incrementa cada vez que un conjunto de 4 lecturas (CO2, CH4, Temp, Humedad)
  /// es enviado a la base de datos, permitiendo agruparlos lógicamente.
  int _currentBatchSequence = 0;

  /// [Timer] utilizado para implementar el "debounce" en las escrituras a la base de datos.
  /// Esto asegura que los datos se guarden solo después de un breve periodo de "silencio"
  /// en las actualizaciones de BLE, evitando escrituras excesivas.
  Timer? _debounceTimer;

  //----------------------------------------------------------------------------
  // MÉTODOS DEL CICLO DE VIDA DEL WIDGET
  //----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    /// Escucha los cambios en [BleController.portableData].
    /// Cada vez que se reciben nuevos datos del dispositivo DP, este listener se activa.
    _bleController.portableData.listen((data) {
      if (mounted) {
        // Asegúrate de que el widget aún esté montado antes de actualizar el estado de la UI.
        _co2.value = data['co2'] ?? '--';
        _ch4.value = data['ch4'] ?? '--';
        _temperatura.value = data['temperature'] ?? '--';
        _humedad.value = data['humidity'] ?? '--';

        // Si hay una sesión de monitoreo activa, prepara para guardar los datos en Supabase.
        if (_currentActiveSession.value != null) {
          // 1. Cancela cualquier timer de debounce existente. Si una nueva actualización
          //    llega antes de que el timer actual se dispare, este se cancela.
          _debounceTimer?.cancel();

          // 2. Inicia un nuevo timer. El código dentro de este timer solo se ejecutará
          //    si no se recibe otra actualización de BLE en los próximos 500 milisegundos.
          //    Esto agrupa múltiples actualizaciones rápidas del BLE en una única escritura a la DB.
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            // Incrementa la secuencia de lote para agrupar este nuevo conjunto de lecturas.
            _currentBatchSequence++;

            final String sessionId = _currentActiveSession.value!.id;

            // Guardar cada lectura de sensor en la base de datos.
            // Se pasa el 'batchSequence' para poder agrupar estas lecturas en la DB.
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'CO2',
              value: double.tryParse(_co2.value) ?? 0.0,
              unit: 'ppm',
              batchSequence: _currentBatchSequence, // Pasa el batchSequence
            );
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'CH4',
              value: double.tryParse(_ch4.value) ?? 0.0,
              unit: 'ppm',
              batchSequence: _currentBatchSequence, // Pasa el batchSequence
            );
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'Temperatura',
              value: double.tryParse(_temperatura.value) ?? 0.0,
              unit: 'ºC',
              batchSequence: _currentBatchSequence, // Pasa el batchSequence
            );
            _operationDataService.createSensorReading(
              sessionId: sessionId,
              sensorType: 'Humedad',
              value: double.tryParse(_humedad.value) ?? 0.0,
              unit: '%',
              batchSequence: _currentBatchSequence, // Pasa el batchSequence
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Es crucial cancelar cualquier timer activo cuando el widget es removido
    // del árbol de widgets para evitar fugas de memoria y posibles errores.
    _debounceTimer?.cancel();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE SESIÓN
  //----------------------------------------------------------------------------

  /// Inicia una nueva sesión de monitoreo en modo 'manual'.
  ///
  /// Muestra un diálogo al usuario para que ingrese un nombre y una descripción
  /// para la sesión. Si se confirma y los datos son válidos, crea un nuevo
  /// registro en la tabla `operation_sessions` de Supabase y establece la
  /// sesión como activa en [_currentActiveSession].
  Future<void> _startMonitoring() async {
    String? operationName;
    String? description;

    // Muestra un diálogo para que el usuario ingrese el nombre y la descripción.
    await Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.backgroundWhite,
        title: Text('Iniciar Monitoreo',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Nombre de la Operación (Obligatorio)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.neutralLight)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: (value) => operationName = value,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'Descripción (Opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.neutralLight)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary)),
              ),
              onChanged: (value) => description = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(), // Cierra el diálogo sin iniciar
            child: Text('Cancelar', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () {
              // Valida que el nombre de la operación no esté vacío.
              if (operationName != null && operationName!.isNotEmpty) {
                Get.back(); // Cierra el diálogo y permite que la ejecución continúe
              } else {
                // Muestra un SnackBar si el nombre es obligatorio
                Get.snackbar(
                  'Error',
                  'El nombre de la operación es obligatorio',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.backgroundWhite,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Iniciar',
                style: TextStyle(color: AppColors.backgroundWhite)),
          ),
        ],
      ),
    );

    // Si el usuario canceló el diálogo o el nombre estaba vacío, no se procede.
    if (operationName == null || operationName!.isEmpty) {
      Get.snackbar(
        'Monitoreo Cancelado',
        'La operación de monitoreo no fue iniciada.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    // Espera la lista de sesiones antes de acceder a su longitud para el routeNumber
    final List<OperationSession> sessions =
        await _operationDataService.userOperationSessions;
    final OperationSession? session =
        await _operationDataService.createOperationSession(
      operationName: operationName,
      description: description,
      mode: 'manual', // El modo viene por defecto como 'manual'
      routeNumber: sessions.length + 1, // Número de ruta incremental
    );

    if (session != null) {
      _currentActiveSession.value = session;
      _currentBatchSequence =
          0; // Reinicia la secuencia de lote para la nueva sesión.
      Get.snackbar(
        'Monitoreo Iniciado',
        'Sesión "${session.operationName}" iniciada con éxito.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.accentColor,
        colorText: AppColors.backgroundWhite,
      );
    } else {
      Get.snackbar(
        'Error al Iniciar',
        'No se pudo iniciar la sesión de monitoreo. Intente de nuevo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.backgroundWhite,
      );
    }
  }

  /// Finaliza la sesión de monitoreo actualmente activa.
  ///
  /// Actualiza el campo `end_time` y el estado a 'completed' en el registro
  /// de la sesión activa en la tabla `operation_sessions` de Supabase.
  /// También limpia la sesión activa en la aplicación y cancela el timer de debounce.
  Future<void> _stopMonitoring() async {
    if (_currentActiveSession.value != null) {
      final bool success = await _operationDataService.endOperationSession(
        _currentActiveSession.value!.id,
      );
      if (success) {
        _currentActiveSession.value = null; // Limpia la sesión activa.
        _currentBatchSequence = 0; // Reinicia el contador de secuencia.
        _debounceTimer?.cancel(); // Cancela el timer al detener el monitoreo.
        Get.snackbar(
          'Monitoreo Detenido',
          'Sesión finalizada con éxito.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.secondary,
          colorText: AppColors.textPrimary,
        );
      } else {
        Get.snackbar(
          'Error al Detener',
          'No se pudo finalizar la sesión de monitoreo.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite,
        );
      }
    } else {
      Get.snackbar(
          'Advertencia', 'No hay una sesión de monitoreo activa para detener.');
    }
  }

  //----------------------------------------------------------------------------
  // SECCIÓN DE INTERFAZ DE USUARIO
  //----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary, // Fondo consistente
      body: SingleChildScrollView(
        physics:
            const BouncingScrollPhysics(), // Efecto de rebote al hacer scroll
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05, // Padding horizontal relativo
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitleContainer(theme), // Título principal de la pantalla
              const SizedBox(height: 20),
              _buildHeader(theme), // Subtítulo de la sección de monitoreo
              const SizedBox(height: 10),

              // Indicador de estado de la sesión de monitoreo (Activa/Inactiva)
              Obx(() {
                final bool isActive = _currentActiveSession.value != null;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accentColor.withAlpha(39)
                        : AppColors.secondary1.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? AppColors.accentColor
                          : AppColors.secondary1,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive
                            ? Icons.play_arrow_rounded
                            : Icons.stop_rounded,
                        color: isActive
                            ? AppColors.accentColor
                            : AppColors.secondary1,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // Se usa Expanded para evitar el desbordamiento de texto si el nombre de la sesión es largo.
                      Expanded(
                        child: Text(
                          isActive
                              ? 'Sesión Activa: ${_currentActiveSession.value?.operationName ?? 'Sin Nombre'}'
                              : 'Monitoreo Inactivo',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isActive
                                ? AppColors.accentColor
                                : AppColors.secondary1,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow
                              .ellipsis, // Recorta el texto si es muy largo
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Botones de control para Iniciar y Detener el Monitoreo.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                          onPressed: _currentActiveSession.value == null
                              ? _startMonitoring // Habilitado si no hay sesión activa
                              : null, // Deshabilitado si ya hay una sesión activa
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar Monitoreo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors
                                .accentColor, // Verde vibrante para iniciar
                            foregroundColor: AppColors.backgroundWhite,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                          ),
                        )),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                          onPressed: _currentActiveSession.value != null
                              ? _stopMonitoring // Habilitado si hay sesión activa
                              : null, // Deshabilitado si no hay sesión activa
                          icon: const Icon(Icons.stop),
                          label: const Text('Detener Monitoreo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.error, // Rojo para detener
                            foregroundColor: AppColors.backgroundWhite,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                          ),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Indicador de estado de conexión del dispositivo Tanari DP vía BLE.
              Obx(() => _buildConnectionStatus(
                  theme,
                  _bleController.isPortableConnected.value,
                  BleController.deviceNameDP)),
              const SizedBox(height: 20),

              // Lista de tarjetas que muestran los valores de los sensores.
              _buildSensorList(),
              const SizedBox(height: 25), // Espacio al final de la pantalla
            ],
          ),
        ),
      ),
      // Botón flotante para acceder al historial de sesiones.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Get.to(() => const SessionsHistoryScreen());
        },
        label: Text(
          'Historial de Sesiones',
          style: TextStyle(color: AppColors.backgroundWhite),
        ),
        icon: Icon(Icons.history, color: AppColors.backgroundWhite),
        backgroundColor: AppColors.secondary1, // Un color que se destaque
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Construye el contenedor del título principal de la pantalla.
  ///
  /// Proporciona un estilo visual para el título "Modo DP".
  Widget _buildTitleContainer(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary, // Verde lima brillante
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(77), // Sombra sutil
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        'Modo DP',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: AppColors.backgroundWhite, // Texto blanco para contraste
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Construye el encabezado (subtítulo) de la sección de monitoreo.
  ///
  /// Muestra el texto "Monitoreo Ambiental".
  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Monitoreo Ambiental',
      style: theme.textTheme.headlineSmall?.copyWith(
        color: AppColors.textPrimary, // Gris oscuro para el texto
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Construye la lista de tarjetas de sensores.
  ///
  /// Cada sensor (CO2, CH4, Temperatura, Humedad) se representa con una
  /// [_SensorCard] reactiva que muestra su valor actual.
  Widget _buildSensorList() {
    return Column(
      children: [
        // Tarjeta para el sensor de CO2
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'CO2',
                value: _co2.value,
                unit: 'ppm',
                icon: Icons.cloud,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.accent,
              ),
            )),
        const SizedBox(height: 15),
        // Tarjeta para el sensor de CH4
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'CH4',
                value: _ch4.value,
                unit: 'ppm',
                icon: Icons.local_fire_department,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.error,
              ),
            )),
        const SizedBox(height: 15),
        // Tarjeta para el sensor de Temperatura
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'Temperatura',
                value: _temperatura.value,
                unit: 'ºC',
                icon: Icons.thermostat,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.secondary,
              ),
            )),
        const SizedBox(height: 15),
        // Tarjeta para el sensor de Humedad
        Obx(() => _buildSensorCardContainer(
              _SensorCard(
                label: 'Humedad',
                value: _humedad.value,
                unit: '%',
                icon: Icons.water_drop,
                cardColor: AppColors.secondary1,
                iconColor: AppColors.accentColor,
              ),
            )),
      ],
    );
  }

  /// Envolver una [_SensorCard] en un [Container] con estilo para resaltarla.
  ///
  /// Aplica un fondo, bordes redondeados y una sombra para un diseño atractivo.
  Widget _buildSensorCardContainer(Widget sensorCard) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.backgroundBlack.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: sensorCard,
    );
  }

  /// Construye un widget para mostrar el estado de la conexión BLE de un dispositivo específico.
  ///
  /// Muestra un icono de Bluetooth y un texto indicando si el dispositivo está conectado o desconectado.
  Widget _buildConnectionStatus(
      ThemeData theme, bool isConnected, String deviceName) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.accentColor.withAlpha(38)
            : AppColors.error.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
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
          const SizedBox(width: 10),
          Text(
            isConnected
                ? '$deviceName: Conectado'
                : '$deviceName: Desconectado',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isConnected ? AppColors.accentColor : AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de tarjeta individual para mostrar el valor de un sensor.
///
/// Este es un [StatelessWidget] que se encarga solo de la presentación visual
/// de una lectura de sensor específica (etiqueta, valor, unidad, icono y colores).
class _SensorCard extends StatelessWidget {
  final String label; // Etiqueta del sensor (ej. "CO2")
  final String value; // Valor actual del sensor (ej. "450")
  final String unit; // Unidad de medida (ej. "ppm")
  final IconData icon; // Icono representativo del sensor
  final Color cardColor; // Color principal para el texto de la tarjeta
  final Color iconColor; // Color específico para el icono del sensor

  const _SensorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.cardColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite, // Fondo blanco de la tarjeta interna
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Contenedor para el icono del sensor con un fondo circular semi-transparente
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor
                  .withAlpha(39), // Color suave basado en el color del icono
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor, // Color del icono
              size: 32,
            ),
          ),
          const SizedBox(width: 15), // Espacio entre el icono y el texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Etiqueta del sensor (ej. "CO2" en mayúsculas)
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                  overflow:
                      TextOverflow.ellipsis, // Recorta el texto si es muy largo
                  maxLines: 1,
                ),
                const SizedBox(
                    height: 6), // Espacio entre la etiqueta y el valor
                // Valor del sensor y su unidad
                RichText(
                  text: TextSpan(
                    text: value, // El valor numérico del sensor
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors
                          .backgroundBlack, // Valor en negro para alto contraste
                      fontWeight: FontWeight.bold,
                      fontSize: 30, // Tamaño de fuente más grande para el valor
                    ),
                    children: [
                      TextSpan(
                        text: ' $unit', // La unidad de medida (ej. " ppm")
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color:
                              AppColors.textSecondary, // Unidad en gris medio
                          fontWeight: FontWeight.w500,
                          fontSize:
                              20, // Tamaño de fuente más pequeño para la unidad
                        ),
                      ),
                    ],
                  ),
                  overflow:
                      TextOverflow.ellipsis, // Recorta el texto si es muy largo
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
