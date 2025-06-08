import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Importa tus colores personalizados
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart'; // Importa tu BleController
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Para los íconos de los botones de control

/// Pantalla principal para el control en Modo Acople (DP + UGV).
class ModoAcople extends StatefulWidget {
  const ModoAcople({super.key});

  @override
  State<ModoAcople> createState() => _ModoAcopleState();
}

class _ModoAcopleState extends State<ModoAcople> {
  // Obtenemos la instancia de BleController
  final BleController bleController = Get.find<BleController>();

  // Último comando de movimiento direccional enviado para evitar duplicados.
  String? _lastSentDirectionalCommand;

  // NUEVA VARIABLE DE ESTADO: Controla si estamos esperando la 'T' final para reactivar los controles manuales.
  // Esto previene que se puedan enviar comandos manuales inmediatamente después de detener el modo automático,
  // hasta que el UGV confirme la finalización del ciclo con 'T'.
  final RxBool _awaitingFinalTForManualControlsReactivation = false.obs;

  @override
  void initState() {
    super.initState();
    // Establece el último comando direccional enviado como "detener" al inicio.
    _lastSentDirectionalCommand = BleController.stop;

    // Escucha los datos recibidos del ESP32 a través del BleController
    // Esto es crucial para saber cuándo un ciclo automático ha terminado.
    ever(bleController.receivedData, (String? data) async {
      // Usamos 'data == BleController.endAutoMode' para la comparación
      // ya que receivedData puede ser null.
      if (data == BleController.endAutoMode) {
        // Se recibió 'T' del ESP32, indicando que el modo automático (o un ciclo) ha terminado.
        // Si el modo automático está activo en la aplicación (botón rojo),
        // reenviar 'A' para iniciar el siguiente ciclo.
        if (bleController.isAutomaticMode.value) {
          // Si estamos en modo automático y recibimos 'T', significa que un ciclo terminó,
          // y debemos re-enviar 'A' para el siguiente ciclo si el usuario no ha cancelado.
          await Future.delayed(const Duration(
              milliseconds: 100)); // Pequeño retraso antes de reenviar
          _sendBleCommand(BleController
              .startAutoMode); // Re-envía 'A' para el siguiente ciclo
        } else if (_awaitingFinalTForManualControlsReactivation.value) {
          // Si el modo automático NO está activo Y estábamos esperando la 'T' final,
          // entonces es el momento de reactivar los controles manuales.
          _awaitingFinalTForManualControlsReactivation.value =
              false; // Reactivar controles manuales
          Get.snackbar(
            "Modo Automático Finalizado",
            "Los controles manuales han sido reactivados.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.secondary, // Un color más suave
            colorText: AppColors.textPrimary,
            duration: const Duration(seconds: 3),
          );
        }
      }
    });
  }

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE MOVIMIENTO Y COMUNICACIÓN BLE
  //----------------------------------------------------------------------------

  /// Inicia el movimiento del UGV en una dirección específica.
  void _startMovement(String command) {
    if (bleController.isUgvConnected.value &&
        !bleController.isAutomaticMode.value &&
        !_awaitingFinalTForManualControlsReactivation.value) {
      if (_lastSentDirectionalCommand != command) {
        _lastSentDirectionalCommand = command;
        _sendBleCommand(command);
      }
    }
  }

  /// Detiene el movimiento del UGV.
  void _stopMovement() {
    if (bleController.isUgvConnected.value &&
        !bleController.isAutomaticMode.value &&
        !_awaitingFinalTForManualControlsReactivation.value) {
      _sendBleCommand(BleController.stop);
      _lastSentDirectionalCommand = BleController.stop;
    }
  }

  /// Interrumpe el movimiento actual del UGV (tanto manual como automático).
  void _interruptMovement() {
    if (bleController.isUgvConnected.value) {
      _sendBleCommand(BleController.interruption);
      _lastSentDirectionalCommand = BleController.interruption;
      bleController.isAutomaticMode.value =
          false; // Desactiva el modo automático en la app
      _awaitingFinalTForManualControlsReactivation.value =
          false; // Asegura que los controles se reactiven
      Get.snackbar(
        "Interrupción",
        "El UGV ha sido detenido. Modo automático desactivado.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: AppColors.backgroundWhite,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Envía un comando BLE al dispositivo UGV.
  void _sendBleCommand(String commandToSend) {
    if (bleController.ugvDeviceId != null &&
        bleController.isDeviceConnected(bleController.ugvDeviceId!)) {
      bleController.sendData(bleController.ugvDeviceId!, commandToSend);
    } else {
      Get.snackbar(
        "Advertencia",
        "No se ha conectado al UGV. Por favor, conecte el UGV.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: AppColors.backgroundWhite,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Alterna el estado del modo automático del UGV.
  void _toggleAutomaticMode() {
    if (bleController.ugvDeviceId != null &&
        bleController.isDeviceConnected(bleController.ugvDeviceId!)) {
      if (bleController.isAutomaticMode.value) {
        // Si el modo automático está activo, lo desactivamos y enviamos comando de finalización
        bleController.isAutomaticMode.value = false;
        _sendBleCommand(BleController
            .endAutoMode); // Envía 'T' para detener el ciclo actual
        _awaitingFinalTForManualControlsReactivation.value =
            true; // Esperar 'T' del UGV
        Get.snackbar(
          "Modo Automático",
          "Solicitando finalización del modo automático. Esperando confirmación del UGV...",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: AppColors.backgroundWhite,
          duration: const Duration(seconds: 4),
        );
      } else {
        // Si el modo automático está inactivo, lo activamos y enviamos comando de inicio
        bleController.isAutomaticMode.value = true;
        _sendBleCommand(BleController.startAutoMode);
        _awaitingFinalTForManualControlsReactivation.value =
            false; // No estamos esperando 'T'
        Get.snackbar(
          "Modo Automático",
          "Modo automático iniciado.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.accentColor, // Color verde vibrante
          colorText: AppColors.backgroundWhite,
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      Get.snackbar(
        "Advertencia",
        "No hay UGV conectado para activar/desactivar el modo automático.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: AppColors.backgroundWhite,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Modo de Acople',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.backgroundWhite,
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundBlack,
        foregroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección de Monitoreo del DP
              _buildMonitoringPanel(),
              const SizedBox(height: 20),
              // Sección de Control del UGV
              _buildUgvControlPanel(),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el panel de monitoreo (datos del Tanari DP).
  Widget _buildMonitoringPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight, // Usa el color claro para el panel
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withAlpha((255 * 0.1).round()), // Usa .withAlpha()
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monitoreo del Tanari DP:',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const Divider(height: 20, color: AppColors.backgroundBlack),
          // MODIFICACIÓN CRÍTICA: Acceso a datos a través de portableData['clave']
          Obx(() => _buildDataRow('CO2:',
              '${bleController.portableData['co2'] ?? '--'} ppm', Icons.cloud)),
          Obx(() => _buildDataRow(
              'CH4:',
              '${bleController.portableData['ch4'] ?? '--'} ppm',
              Icons.local_gas_station)),
          Obx(() => _buildDataRow(
              'Temperatura:',
              '${bleController.portableData['temperature'] ?? '--'} °C',
              Icons.thermostat)),
          Obx(() => _buildDataRow(
              'Humedad:',
              '${bleController.portableData['humidity'] ?? '--'} %',
              Icons.water_drop)),
          // Aquí, si tu DP no envía presión, se mostrará '--' por defecto.
          // Si sí envía presión, necesitarás ajustar _parseAndStorePortableData en ble_controller.dart
          // para leerla y guardarla en portableData['pressure'].
          //   Obx(() => _buildDataRow(
          //       'Presión:',
          //       '${bleController.portableData['pressure'] ?? '--'} hPa',
          //       Icons.speed)),
        ],
      ),
    );
  }

  /// Construye una fila para mostrar un dato específico.
  Widget _buildDataRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.backgroundBlack, size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el panel de control del UGV.
  Widget _buildUgvControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight, // Usa el color claro para el panel
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withAlpha((255 * 0.1).round()), // Usa .withAlpha()
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Control del Tanari UGV:',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const Divider(height: 20, color: AppColors.backgroundBlack),
          const SizedBox(height: 10),
          _buildActionButtons(context), // Botones de Auto y Stop (Interrupción)
          const SizedBox(height: 20),
          _buildDirectionalControls(context), // Botones direccionales
        ],
      ),
    );
  }

  /// Construye los botones de acción (Auto e Interrumpir).
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón "Auto"
        Obx(
          () => _buildActionButton(
            text: 'Auto',
            icon: FontAwesomeIcons.robot,
            // Habilita/deshabilita el botón "Auto" basado en la conexión del UGV
            // y si se está esperando la 'T' final del UGV.
            onPressed: (bleController.isUgvConnected.value &&
                    !_awaitingFinalTForManualControlsReactivation.value)
                ? _toggleAutomaticMode
                : null,
            isActive: bleController.isAutomaticMode.value,
          ),
        ),
        const SizedBox(width: 20),
        // Botón "Interrumpir"
        _buildActionButton(
          text: 'Interrumpir',
          icon: FontAwesomeIcons.stop,
          // Habilita el botón "Interrumpir" solo si el UGV está conectado.
          onPressed:
              bleController.isUgvConnected.value ? _interruptMovement : null,
          isPrimaryColor: false, // Para que sea rojo
        ),
      ],
    );
  }

  /// Widget genérico para un botón de acción compacto.
  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Function()? onPressed,
    bool isActive = false,
    bool isPrimaryColor =
        true, // true para color primario/accent, false para rojo (interrumpir)
  }) {
    Color buttonColor =
        Colors.grey; // Color por defecto cuando está deshabilitado

    if (onPressed != null) {
      if (isPrimaryColor) {
        // Si el botón es "Auto", cambia entre verde (activo) y primary (inactivo)
        buttonColor = isActive ? Colors.red : Colors.blue;
      } else {
        // Si no es primary (ej. "Interrumpir"), siempre es rojo cuando está habilitado
        buttonColor = Colors.red;
      }
    }

    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 5,
        ),
        icon: FaIcon(icon, size: 20, color: AppColors.backgroundWhite),
        label: Text(
          text,
          style:
              const TextStyle(fontSize: 14, color: AppColors.backgroundWhite),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Construye los controles direccionales para el UGV.
  Widget _buildDirectionalControls(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonSize =
            constraints.maxWidth * 0.22; // Ajustar el tamaño del botón

        return Obx(() {
          // Los botones de movimiento solo se habilitan si el UGV está conectado,
          // NO está en modo automático y NO estamos esperando la 'T' final del UGV.
          final bool areMovementButtonsEnabled =
              bleController.isUgvConnected.value &&
                  !bleController.isAutomaticMode.value &&
                  !_awaitingFinalTForManualControlsReactivation.value;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDirectionButton(
                icon: Icons.arrow_upward,
                command: BleController.moveForward,
                size: buttonSize,
                isEnabled: areMovementButtonsEnabled,
              ),
              const SizedBox(height: 10),
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
                          0.25), // Espacio entre Left y Right
                  _buildDirectionButton(
                    icon: Icons.arrow_forward,
                    command: BleController.moveRight,
                    size: buttonSize,
                    isEnabled: areMovementButtonsEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDirectionButton(
                icon: Icons.arrow_downward,
                command: BleController.moveBack,
                size: buttonSize,
                isEnabled: areMovementButtonsEnabled,
              ),
            ],
          );
        });
      },
    );
  }

  /// Widget genérico para un botón direccional del UGV.
  Widget _buildDirectionButton({
    required IconData icon,
    required String command,
    required double size,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTapDown: isEnabled ? (_) => _startMovement(command) : null,
      onTapUp: isEnabled ? (_) => _stopMovement() : null,
      onTapCancel: isEnabled ? () => _stopMovement() : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.blue : Colors.grey,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withAlpha((255 * 0.2).round()), // Usa .withAlpha()
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.backgroundWhite, size: size * 0.5),
      ),
    );
  }
}
