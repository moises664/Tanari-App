import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tanari_app/src/controllers/services/operation_data_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:logger/logger.dart';

/// Representa un punto de datos para gráficos de sensores
/// - [timeInSeconds]: Tiempo en segundos desde el inicio de la sesión
/// - [value]: Valor de la lectura del sensor
class SensorChartData {
  final double timeInSeconds;
  final double value;

  SensorChartData({required this.timeInSeconds, required this.value});
}

/// Contiene estadísticas resumidas para lecturas de sensores
/// - [min]: Valor mínimo registrado
/// - [max]: Valor máximo registrado
/// - [average]: Valor promedio
class SensorStats {
  final double min;
  final double max;
  final double average;

  SensorStats({
    required this.min,
    required this.max,
    required this.average,
  });
}

/// Controlador para la pantalla de detalles de sesión
/// Gestiona la lógica de negocio y estado de la UI
class SessionDetailsController extends GetxController {
  final String sessionId;
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final Logger _logger = Logger();

  // Estados reactivos
  final Rx<OperationSession?> session = Rx<OperationSession?>(null);
  final RxList<Map<String, dynamic>> rawSensorReadings =
      <Map<String, dynamic>>[].obs;

  // Datos de los sensores para gráficos
  final RxList<SensorChartData> co2Data = <SensorChartData>[].obs;
  final RxList<SensorChartData> ch4Data = <SensorChartData>[].obs;
  final RxList<SensorChartData> temperaturaData = <SensorChartData>[].obs;
  final RxList<SensorChartData> humedadData = <SensorChartData>[].obs;

  // Estadísticas de los sensores
  final Rx<SensorStats?> co2Stats = Rx<SensorStats?>(null);
  final Rx<SensorStats?> ch4Stats = Rx<SensorStats?>(null);
  final Rx<SensorStats?> temperaturaStats = Rx<SensorStats?>(null);
  final Rx<SensorStats?> humedadStats = Rx<SensorStats?>(null);

  // Estados de carga y error
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  // Modo de visualización: 'individual' o 'todas'
  final RxString visualizationMode = 'individual'.obs;

  // Sensores seleccionados para el modo individual
  final RxList<String> selectedSensors = <String>[].obs;

  // Rango de tiempo visible (0 a 1, siendo 1 el 100% del tiempo)
  final RxDouble timeRange = 0.0.obs;

  // Modo de gráfica por sensor: true para puntos (discreta), false para línea (continua)
  final RxMap<String, bool> discreteMode = <String, bool>{
    'CO2': false,
    'CH4': false,
    'Temperatura': false,
    'Humedad': false,
  }.obs;

  SessionDetailsController({required this.sessionId});

  @override
  void onInit() {
    super.onInit();
    _fetchSessionDetails();
  }

  /// Carga los detalles de la sesión y las lecturas de los sensores
  Future<void> _fetchSessionDetails() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      // Obtener sesión por ID
      final fetchedSession =
          await _operationDataService.getSessionById(sessionId);
      if (fetchedSession == null) {
        errorMessage.value = 'Sesión no encontrada.';
        isLoading.value = false;
        return;
      }
      session.value = fetchedSession;

      // Obtener lecturas de sensores para la sesión
      final fetchedReadings =
          await _operationDataService.getSensorReadingsForSession(sessionId);
      rawSensorReadings.assignAll(fetchedReadings);

      // Procesar datos y calcular estadísticas
      _processSensorData();
      _calculateStatistics();

      // Seleccionar todos los sensores por defecto
      selectedSensors.addAll(['CO2', 'CH4', 'Temperatura', 'Humedad']);
    } catch (e) {
      errorMessage.value = 'Error al cargar los datos de la sesión: $e';
      _logger.e('Error en _fetchSessionDetails: $e', error: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Procesa las lecturas brutas de los sensores y las convierte en datos de gráfico
  void _processSensorData() {
    if (session.value == null || rawSensorReadings.isEmpty) return;

    // Limpiar datos anteriores
    co2Data.clear();
    ch4Data.clear();
    temperaturaData.clear();
    humedadData.clear();

    final DateTime sessionStartTime = session.value!.startTime;

    for (var reading in rawSensorReadings) {
      final DateTime timestamp = DateTime.parse(reading['timestamp']);
      final double timeInSeconds =
          timestamp.difference(sessionStartTime).inSeconds.toDouble();
      final double value = (reading['sensor_value'] as num).toDouble();
      final String sensorType = reading['sensor_type'];

      // Clasificar lecturas por tipo de sensor
      switch (sensorType) {
        case 'CO2':
          co2Data
              .add(SensorChartData(timeInSeconds: timeInSeconds, value: value));
          break;
        case 'CH4':
          ch4Data
              .add(SensorChartData(timeInSeconds: timeInSeconds, value: value));
          break;
        case 'Temperatura':
          temperaturaData
              .add(SensorChartData(timeInSeconds: timeInSeconds, value: value));
          break;
        case 'Humedad':
          humedadData
              .add(SensorChartData(timeInSeconds: timeInSeconds, value: value));
          break;
      }
    }

    // Ordenar datos por tiempo
    co2Data.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    ch4Data.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    temperaturaData.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    humedadData.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
  }

  /// Calcula estadísticas (min, max, promedio) para cada sensor
  void _calculateStatistics() {
    co2Stats.value = _calculateSensorStats(co2Data);
    ch4Stats.value = _calculateSensorStats(ch4Data);
    temperaturaStats.value = _calculateSensorStats(temperaturaData);
    humedadStats.value = _calculateSensorStats(humedadData);
  }

  /// Calcula las estadísticas para una lista de datos de sensor
  SensorStats _calculateSensorStats(List<SensorChartData> data) {
    if (data.isEmpty) {
      return SensorStats(min: 0, max: 0, average: 0);
    }

    double min = double.maxFinite;
    double max = double.negativeInfinity;
    double sum = 0;

    for (var item in data) {
      if (item.value < min) min = item.value;
      if (item.value > max) max = item.value;
      sum += item.value;
    }

    return SensorStats(
      min: min,
      max: max,
      average: sum / data.length,
    );
  }

  /// Obtiene el tiempo máximo entre todos los sensores
  double get maxTime {
    double max = 0;
    if (co2Data.isNotEmpty) {
      double t = co2Data.last.timeInSeconds;
      if (t > max) max = t;
    }
    if (ch4Data.isNotEmpty) {
      double t = ch4Data.last.timeInSeconds;
      if (t > max) max = t;
    }
    if (temperaturaData.isNotEmpty) {
      double t = temperaturaData.last.timeInSeconds;
      if (t > max) max = t;
    }
    if (humedadData.isNotEmpty) {
      double t = humedadData.last.timeInSeconds;
      if (t > max) max = t;
    }
    return max;
  }
}

/// Pantalla que muestra los detalles de una sesión y gráficos de sensores
class SessionDetailsScreen extends StatelessWidget {
  final String sessionId;

  const SessionDetailsScreen({super.key, required this.sessionId});

  /// Formatea el tiempo en segundos a un string legible (mm:ss o ss)
  String _formatTime(double seconds) {
    if (seconds < 60) {
      return '${seconds.toInt()}s';
    } else {
      int totalSecs = seconds.toInt();
      int mins = totalSecs ~/ 60;
      int secs = totalSecs % 60;
      return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionDetailsController controller =
        Get.put(SessionDetailsController(sessionId: sessionId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Obx(() => Text(
              controller.session.value?.operationName ?? 'Detalles de Sesión',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            )),
        backgroundColor: AppColors.backgroundWhite,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        elevation: 1,
      ),
      body: Obx(() {
        // Estados de carga
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        // Manejo de errores
        else if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: AppColors.error),
                  const SizedBox(height: 10),
                  Text(
                    controller.errorMessage.value,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => controller._fetchSessionDetails(),
                    icon: Icon(Icons.refresh, color: AppColors.backgroundWhite),
                    label: Text('Reintentar',
                        style: TextStyle(color: AppColors.backgroundWhite)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          );
        }
        // Sesión no encontrada
        else if (controller.session.value == null) {
          return Center(
            child: Text(
              'No se encontraron detalles para esta sesión.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }

        // Configuración de visualización
        final sessionDetails = controller.session.value!;
        final maxTime = controller.maxTime;
        final currentMaxX = controller.timeRange.value > 0
            ? maxTime * controller.timeRange.value
            : maxTime;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información de la sesión
              _buildSessionInfoCard(theme, sessionDetails),
              const SizedBox(height: 20),

              // Selector de visualización
              _buildVisualizationSelector(controller, theme),
              const SizedBox(height: 16),

              // Selector de sensores (solo en modo individual)
              if (controller.visualizationMode.value == 'individual')
                _buildSensorSelector(controller, theme),
              const SizedBox(height: 16),

              // Selector de rango de tiempo
              _buildTimeRangeSelector(controller, maxTime),
              const SizedBox(height: 16),

              // Selector de modo de gráfica (discreta/continua) por sensor
              if (controller.visualizationMode.value == 'individual')
                _buildGraphStyleSelector(controller, theme),
              const SizedBox(height: 16),

              // Título para la sección de gráficos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  controller.visualizationMode.value == 'todas'
                      ? 'Gráfico Combinado'
                      : 'Gráficos de Sensores',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Contenedor de gráficos (individual o combinado)
              _buildChartSection(controller, theme, currentMaxX),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  /// Construye el selector de modo de visualización (individual o combinado)
  Widget _buildVisualizationSelector(
      SessionDetailsController controller, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildVisualizationOption(
              controller: controller,
              theme: theme,
              mode: 'individual',
              icon: Icons.view_agenda,
              label: 'Individual',
            ),
            _buildVisualizationOption(
              controller: controller,
              theme: theme,
              mode: 'todas',
              icon: Icons.auto_graph,
              label: 'Combinado',
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una opción de visualización (botón)
  Widget _buildVisualizationOption({
    required SessionDetailsController controller,
    required ThemeData theme,
    required String mode,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = controller.visualizationMode.value == mode;
    return GestureDetector(
      onTap: () => controller.visualizationMode.value = mode,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el selector de sensores para el modo individual
  Widget _buildSensorSelector(
      SessionDetailsController controller, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSensorOption(
              controller: controller,
              theme: theme,
              sensor: 'CO2',
              label: 'CO₂',
              color: AppColors.chartCO2,
            ),
            _buildSensorOption(
              controller: controller,
              theme: theme,
              sensor: 'CH4',
              label: 'CH₄',
              color: AppColors.chartCH4,
            ),
            _buildSensorOption(
              controller: controller,
              theme: theme,
              sensor: 'Temperatura',
              label: 'Temperatura',
              color: AppColors.chartTemperature,
            ),
            _buildSensorOption(
              controller: controller,
              theme: theme,
              sensor: 'Humedad',
              label: 'Humedad',
              color: AppColors.chartHumidity,
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una opción de sensor (chip)
  Widget _buildSensorOption({
    required SessionDetailsController controller,
    required ThemeData theme,
    required String sensor,
    required String label,
    required Color color,
  }) {
    final bool isSelected = controller.selectedSensors.contains(sensor);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          controller.selectedSensors.add(sensor);
        } else {
          controller.selectedSensors.remove(sensor);
        }
      },
      backgroundColor: Colors.transparent,
      selectedColor: color.withAlpha(51),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: isSelected ? color : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? color : AppColors.neutralLight,
          width: 1,
        ),
      ),
    );
  }

  /// Construye el selector de rango de tiempo
  Widget _buildTimeRangeSelector(
      SessionDetailsController controller, double maxTime) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rango de Tiempo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '0s',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Expanded(
                  child: Obx(() => Slider(
                        value: controller.timeRange.value,
                        onChanged: (value) {
                          controller.timeRange.value = value;
                        },
                        min: 0,
                        max: 1,
                      )),
                ),
                Obx(() => Text(
                      '${(maxTime * controller.timeRange.value).toStringAsFixed(0)}s',
                      style: TextStyle(color: AppColors.textSecondary),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el selector de estilo de gráfica (discreta/continua) por sensor
  Widget _buildGraphStyleSelector(
      SessionDetailsController controller, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estilo de Gráfica',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildGraphStyleOption(
                  controller: controller,
                  theme: theme,
                  sensor: 'CO2',
                  label: 'CO₂',
                  color: AppColors.chartCO2,
                ),
                _buildGraphStyleOption(
                  controller: controller,
                  theme: theme,
                  sensor: 'CH4',
                  label: 'CH₄',
                  color: AppColors.chartCH4,
                ),
                _buildGraphStyleOption(
                  controller: controller,
                  theme: theme,
                  sensor: 'Temperatura',
                  label: 'Temperatura',
                  color: AppColors.chartTemperature,
                ),
                _buildGraphStyleOption(
                  controller: controller,
                  theme: theme,
                  sensor: 'Humedad',
                  label: 'Humedad',
                  color: AppColors.chartHumidity,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una opción de estilo de gráfica (chip)
  Widget _buildGraphStyleOption({
    required SessionDetailsController controller,
    required ThemeData theme,
    required String sensor,
    required String label,
    required Color color,
  }) {
    final bool isDiscrete = controller.discreteMode[sensor] ?? false;
    return ChoiceChip(
      label: Text(label),
      selected: isDiscrete,
      onSelected: (selected) {
        controller.discreteMode[sensor] = selected;
      },
      backgroundColor: Colors.transparent,
      selectedColor: color.withAlpha(51),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: isDiscrete ? color : AppColors.textSecondary,
        fontWeight: isDiscrete ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDiscrete ? color : AppColors.neutralLight,
          width: 1,
        ),
      ),
    );
  }

  /// Construye la sección de gráficos según el modo de visualización
  Widget _buildChartSection(SessionDetailsController controller,
      ThemeData theme, double currentMaxX) {
    if (controller.visualizationMode.value == 'todas') {
      return _buildCombinedChart(controller, theme, currentMaxX);
    } else {
      return _buildIndividualCharts(controller, theme, currentMaxX);
    }
  }

  /// Construye los gráficos individuales en un carrusel horizontal
  Widget _buildIndividualCharts(SessionDetailsController controller,
      ThemeData theme, double currentMaxX) {
    return SizedBox(
      height: 420,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 8),
          if (controller.selectedSensors.contains('CO2'))
            _buildSensorCard(
              theme: theme,
              title: 'CO₂ (ppm)',
              data: controller.co2Data,
              color: AppColors.chartCO2,
              unit: 'ppm',
              showPoints: controller.discreteMode['CO2'] ?? false,
              currentMaxX: currentMaxX,
            ),
          if (controller.selectedSensors.contains('CH4'))
            const SizedBox(width: 16),
          if (controller.selectedSensors.contains('CH4'))
            _buildSensorCard(
              theme: theme,
              title: 'CH₄ (ppm)',
              data: controller.ch4Data,
              color: AppColors.chartCH4,
              unit: 'ppm',
              showPoints: controller.discreteMode['CH4'] ?? false,
              currentMaxX: currentMaxX,
            ),
          if (controller.selectedSensors.contains('Temperatura'))
            const SizedBox(width: 16),
          if (controller.selectedSensors.contains('Temperatura'))
            _buildSensorCard(
              theme: theme,
              title: 'Temperatura (ºC)',
              data: controller.temperaturaData,
              color: AppColors.chartTemperature,
              unit: 'ºC',
              showPoints: controller.discreteMode['Temperatura'] ?? false,
              currentMaxX: currentMaxX,
            ),
          if (controller.selectedSensors.contains('Humedad'))
            const SizedBox(width: 16),
          if (controller.selectedSensors.contains('Humedad'))
            _buildSensorCard(
              theme: theme,
              title: 'Humedad (%)',
              data: controller.humedadData,
              color: AppColors.chartHumidity,
              unit: '%',
              showPoints: controller.discreteMode['Humedad'] ?? false,
              currentMaxX: currentMaxX,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Construye el gráfico combinado que muestra todos los sensores en un solo gráfico
  Widget _buildCombinedChart(SessionDetailsController controller,
      ThemeData theme, double currentMaxX) {
    // Calcular valores máximos y mínimos para todos los sensores
    double minY = 0;
    double maxY = 100;

    // Función para encontrar el valor máximo transformado
    double getMaxTransformedValue(
        List<SensorChartData> data, double Function(double) transform) {
      if (data.isEmpty) return 0;
      return data
          .where((d) => d.timeInSeconds <= currentMaxX)
          .map((d) => transform(d.value))
          .reduce((a, b) => a > b ? a : b);
    }

    // Función para encontrar el valor mínimo transformado
    double getMinTransformedValue(
        List<SensorChartData> data, double Function(double) transform) {
      if (data.isEmpty) return 0;
      return data
          .where((d) => d.timeInSeconds <= currentMaxX)
          .map((d) => transform(d.value))
          .reduce((a, b) => a < b ? a : b);
    }

    // Obtener todos los valores transformados
    List<double> allValues = [];

    // CO₂: dividir por 10
    if (controller.co2Data.isNotEmpty) {
      allValues.addAll(controller.co2Data
          .where((d) => d.timeInSeconds <= currentMaxX)
          .map((d) => d.value / 10));
    }

    // CH₄: multiplicar por 10
    if (controller.ch4Data.isNotEmpty) {
      allValues.addAll(controller.ch4Data
          .where((d) => d.timeInSeconds <= currentMaxX)
          .map((d) => d.value * 10));
    }

    // Temperatura: multiplicar por 2
    if (controller.temperaturaData.isNotEmpty) {
      allValues.addAll(controller.temperaturaData
          .where((d) => d.timeInSeconds <= currentMaxX)
          .map((d) => d.value * 2));
    }

    // Humedad: sin transformación
    if (controller.humedadData.isNotEmpty) {
      allValues.addAll(controller.humedadData
          .where((d) => d.timeInSeconds <= currentMaxX)
          .map((d) => d.value));
    }

    // Calcular min y max globales
    if (allValues.isNotEmpty) {
      minY = allValues.reduce((a, b) => a < b ? a : b);
      maxY = allValues.reduce((a, b) => a > b ? a : b);

      // Aplicar margen del 15%
      double range = maxY - minY;
      double margin = range * 0.15;
      minY = minY - margin;
      maxY = maxY + margin;

      // Asegurar valores mínimos
      if (minY == maxY) {
        minY -= 10;
        maxY += 10;
      }

      // Evitar valores negativos
      if (minY < 0) minY = 0;
    }

    // Calcular intervalos seguros para evitar errores
    double horizontalInterval = maxY - minY > 0 ? (maxY - minY) / 5 : 1.0;
    double verticalInterval = currentMaxX > 0 ? currentMaxX / 5 : 1.0;

    return SizedBox(
      height: 420,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: AppColors.backgroundWhite,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Todas las mediciones',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: horizontalInterval,
                      verticalInterval: verticalInterval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.neutralLight,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: verticalInterval,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              _formatTime(value),
                              style: theme.textTheme.bodySmall,
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: horizontalInterval,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}',
                                style: theme.textTheme.bodySmall);
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border:
                          Border.all(color: AppColors.neutralLight, width: 1),
                    ),
                    minX: 0,
                    maxX: currentMaxX,
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      if (controller.co2Data.isNotEmpty)
                        LineChartBarData(
                          spots: controller.co2Data
                              .where((d) => d.timeInSeconds <= currentMaxX)
                              .map((d) => FlSpot(d.timeInSeconds, d.value / 10))
                              .toList(),
                          isCurved: true,
                          color: AppColors.chartCO2,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      if (controller.ch4Data.isNotEmpty)
                        LineChartBarData(
                          spots: controller.ch4Data
                              .where((d) => d.timeInSeconds <= currentMaxX)
                              .map((d) => FlSpot(d.timeInSeconds, d.value * 10))
                              .toList(),
                          isCurved: true,
                          color: AppColors.chartCH4,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      if (controller.temperaturaData.isNotEmpty)
                        LineChartBarData(
                          spots: controller.temperaturaData
                              .where((d) => d.timeInSeconds <= currentMaxX)
                              .map((d) => FlSpot(d.timeInSeconds, d.value * 2))
                              .toList(),
                          isCurved: true,
                          color: AppColors.chartTemperature,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      if (controller.humedadData.isNotEmpty)
                        LineChartBarData(
                          spots: controller.humedadData
                              .where((d) => d.timeInSeconds <= currentMaxX)
                              .map((d) => FlSpot(d.timeInSeconds, d.value))
                              .toList(),
                          isCurved: true,
                          color: AppColors.chartHumidity,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Color.alphaBlend(
                            AppColors.textPrimary.withAlpha(204),
                            Colors.transparent),
                        tooltipRoundedRadius: 8.0,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((LineBarSpot touchedSpot) {
                            final flSpot = touchedSpot;
                            String unit = '';
                            double realValue = flSpot.y;

                            // Determinar unidad y valor real basado en la serie
                            switch (touchedSpot.barIndex) {
                              case 0:
                                realValue = flSpot.y * 10; // Revertir escalado
                                unit = 'ppm (CO₂)';
                                break;
                              case 1:
                                realValue = flSpot.y / 10; // Revertir escalado
                                unit = 'ppm (CH₄)';
                                break;
                              case 2:
                                realValue = flSpot.y / 2; // Revertir escalado
                                unit = 'ºC';
                                break;
                              case 3:
                                unit = '%';
                                break;
                              default:
                                unit = '';
                            }

                            final timeString = _formatTime(flSpot.x);
                            return LineTooltipItem(
                              '${realValue.toStringAsFixed(2)} $unit\n',
                              TextStyle(
                                  color: AppColors.backgroundWhite,
                                  fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: 'Tiempo: $timeString',
                                  style: TextStyle(
                                      color: Color.alphaBlend(
                                          AppColors.backgroundWhite
                                              .withAlpha(204),
                                          Colors.transparent),
                                      fontSize: 10),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye la tarjeta de información de la sesión
  Widget _buildSessionInfoCard(
      ThemeData theme, OperationSession sessionDetails) {
    // Calcular la duración manualmente
    final duration = sessionDetails.endTime != null
        ? sessionDetails.endTime!.difference(sessionDetails.startTime)
        : Duration.zero;

    String durationString = '${duration.inMinutes} minutos';
    if (duration.inSeconds < 60) {
      durationString = '${duration.inSeconds} segundos';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: AppColors.backgroundWhite,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sessionDetails.operationName ?? 'Sesión Sin Nombre',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Divider(height: 20, thickness: 1),
            _buildInfoRow(
              theme,
              Icons.info_outline,
              'Descripción',
              sessionDetails.description ?? 'No se proporcionó descripción.',
            ),
            _buildInfoRow(
              theme,
              Icons.calendar_today,
              'Inicio',
              DateFormat('dd/MM/yyyy HH:mm:ss')
                  .format(sessionDetails.startTime),
            ),
            _buildInfoRow(
              theme,
              Icons.access_time,
              'Fin',
              sessionDetails.endTime != null
                  ? DateFormat('dd/MM/yyyy HH:mm:ss')
                      .format(sessionDetails.endTime!)
                  : 'Sesión activa',
            ),
            _buildInfoRow(
              theme,
              Icons.timer,
              'Duración',
              durationString,
            ),
            _buildInfoRow(
              theme,
              Icons.settings,
              'Modo',
              sessionDetails.mode.capitalizeFirst ?? 'Desconocido',
            ),
            if (sessionDetails.routeNumber != null)
              _buildInfoRow(
                theme,
                Icons.alt_route,
                'Ruta',
                sessionDetails.routeNumber.toString(),
              ),
          ],
        ),
      ),
    );
  }

  /// Construye una fila de información para la tarjeta de sesión
  Widget _buildInfoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.neutralDark),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta de sensor con gráfico y estadísticas
  Widget _buildSensorCard({
    required ThemeData theme,
    required String title,
    required List<SensorChartData> data,
    required Color color,
    required String unit,
    bool showPoints = false,
    required double currentMaxX,
  }) {
    // Filtrar datos dentro del rango de tiempo seleccionado
    final filteredData =
        data.where((d) => d.timeInSeconds <= currentMaxX).toList();
    final hasData = filteredData.isNotEmpty;

    // Calcular estadísticas para los datos filtrados
    SensorStats stats;
    if (hasData) {
      double min = double.maxFinite;
      double max = double.negativeInfinity;
      double sum = 0;
      for (var item in filteredData) {
        if (item.value < min) min = item.value;
        if (item.value > max) max = item.value;
        sum += item.value;
      }
      stats = SensorStats(
        min: min,
        max: max,
        average: sum / filteredData.length,
      );
    } else {
      stats = SensorStats(min: 0, max: 0, average: 0);
    }

    // Determinar los límites del eje Y con un margen
    double minY = 0;
    double maxY = 100;
    if (hasData) {
      final double range = stats.max - stats.min;
      final double margin = range * 0.15; // margen del 15%
      minY = (stats.min - margin).clamp(0, double.infinity);
      maxY = stats.max + margin;

      // Si todos los valores son iguales, ajustamos un rango mínimo
      if (minY == maxY) {
        minY = minY - 10;
        maxY = maxY + 10;
      }

      // Manejo especial para CO2 (evitar valores negativos)
      if (title.contains('CO₂')) {
        minY = minY.clamp(0, double.infinity);
      }
    }

    // Calcular intervalos para las cuadrículas
    final double yRange = maxY - minY;
    // Asegurar que el intervalo horizontal no sea cero
    final double horizontalInterval = yRange > 0 ? yRange / 5 : 1.0;
    // Asegurar que el intervalo vertical no sea cero
    final double verticalInterval = currentMaxX > 0 ? currentMaxX / 5 : 1.0;

    final spots =
        filteredData.map((d) => FlSpot(d.timeInSeconds, d.value)).toList();

    return SizedBox(
      width: 380,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: AppColors.backgroundWhite,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Gráfica con escala dinámica
              AspectRatio(
                aspectRatio: 1.5,
                child: hasData
                    ? LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: horizontalInterval,
                            verticalInterval: verticalInterval,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: AppColors.neutralLight,
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (value) => FlLine(
                              color: AppColors.neutralLight,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: verticalInterval,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    _formatTime(value),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: horizontalInterval,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toInt()}',
                                      style: theme.textTheme.bodySmall);
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                                color: AppColors.neutralLight, width: 1),
                          ),
                          minX: 0,
                          maxX: currentMaxX,
                          minY: minY,
                          maxY: maxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: color,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: showPoints,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: color,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Color.alphaBlend(
                                    color.withAlpha(77), Colors.transparent),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: Color.alphaBlend(
                                  AppColors.textPrimary.withAlpha(204),
                                  Colors.transparent),
                              tooltipRoundedRadius: 8.0,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots
                                    .map((LineBarSpot touchedSpot) {
                                  final flSpot = touchedSpot;
                                  final timeString = _formatTime(flSpot.x);
                                  return LineTooltipItem(
                                    '${flSpot.y.toStringAsFixed(2)} $unit\n',
                                    TextStyle(
                                        color: AppColors.backgroundWhite,
                                        fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                        text: 'Tiempo: $timeString',
                                        style: TextStyle(
                                            color: Color.alphaBlend(
                                                AppColors.backgroundWhite
                                                    .withAlpha(204),
                                                Colors.transparent),
                                            fontSize: 10),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                            ),
                            handleBuiltInTouches: true,
                          ),
                        ),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No hay datos para mostrar',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
              ),
              if (hasData) ...[
                const SizedBox(height: 8),
                _buildStatsTable(theme, stats, color),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Construye la tabla de estadísticas (min, max, promedio)
  Widget _buildStatsTable(ThemeData theme, SensorStats stats, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatBox(
            theme: theme,
            title: 'MÍN',
            value: stats.min,
            color: color,
          ),
          Container(
            width: 1,
            height: 40,
            color: color.withAlpha(77),
          ),
          _buildStatBox(
            theme: theme,
            title: 'MÁX',
            value: stats.max,
            color: color,
          ),
          Container(
            width: 1,
            height: 40,
            color: color.withAlpha(77),
          ),
          _buildStatBox(
            theme: theme,
            title: 'PROM',
            value: stats.average,
            color: color,
          ),
        ],
      ),
    );
  }

  /// Construye una caja de estadística individual (min, max, promedio)
  Widget _buildStatBox({
    required ThemeData theme,
    required String title,
    required double value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(51), width: 1),
          ),
          child: Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
