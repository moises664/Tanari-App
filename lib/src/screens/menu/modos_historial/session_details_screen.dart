import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:logger/logger.dart';
import 'package:tanari_app/src/screens/menu/map_tanari_screen.dart';
import 'package:tanari_app/src/services/api/operation_data_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

// --- INICIO DE CAMBIO: GlobalKeys para capturar los widgets de las gráficas ---
final GlobalKey _combinedChartKey = GlobalKey();
final GlobalKey _co2ChartKey = GlobalKey();
final GlobalKey _ch4ChartKey = GlobalKey();
final GlobalKey _tempChartKey = GlobalKey();
final GlobalKey _humChartKey = GlobalKey();
final GlobalKey _tempHumCombinedChartKey = GlobalKey();
// --- FIN DE CAMBIO ---

class SensorChartData {
  final double timeInSeconds;
  final double value;
  SensorChartData({required this.timeInSeconds, required this.value});
}

class SensorStats {
  final double min;
  final double max;
  final double average;
  SensorStats({required this.min, required this.max, required this.average});
}

class SessionDetailsController extends GetxController {
  final String sessionId;
  final OperationDataService _operationDataService =
      Get.find<OperationDataService>();
  final Logger _logger = Logger();

  final Rx<OperationSession?> session = Rx<OperationSession?>(null);
  final RxList<Map<String, dynamic>> rawSensorReadings =
      <Map<String, dynamic>>[].obs;
  final RxList<SensorChartData> co2Data = <SensorChartData>[].obs;
  final RxList<SensorChartData> ch4Data = <SensorChartData>[].obs;
  final RxList<SensorChartData> temperaturaData = <SensorChartData>[].obs;
  final RxList<SensorChartData> humedadData = <SensorChartData>[].obs;
  final Rx<SensorStats?> co2Stats = Rx<SensorStats?>(null);
  final Rx<SensorStats?> ch4Stats = Rx<SensorStats?>(null);
  final Rx<SensorStats?> temperaturaStats = Rx<SensorStats?>(null);
  final Rx<SensorStats?> humedadStats = Rx<SensorStats?>(null);
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString visualizationMode = 'individual'.obs;
  final RxList<String> selectedSensors = <String>[].obs;
  final RxDouble timeRange = 1.0.obs;
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

  Future<void> _fetchSessionDetails() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final fetchedSession =
          await _operationDataService.getSessionById(sessionId);
      if (fetchedSession == null) {
        errorMessage.value = 'Sesión no encontrada.';
        isLoading.value = false;
        return;
      }
      session.value = fetchedSession;

      if (fetchedSession.mode == 'data_recuperada') {
        final fetchedReadings =
            await _operationDataService.getRecoveredDataForSession(sessionId);
        _processRecoveredData(fetchedReadings);
      } else {
        final fetchedReadings =
            await _operationDataService.getSensorReadingsForSession(sessionId);
        rawSensorReadings.assignAll(fetchedReadings);
        _processSensorDataFromRaw();
      }

      _calculateStatistics();
      selectedSensors.assignAll(['CO2', 'CH4', 'Temperatura', 'Humedad']);
    } catch (e) {
      errorMessage.value = 'Error al cargar los datos de la sesión: $e';
      _logger.e('Error en _fetchSessionDetails: $e', error: e);
    } finally {
      isLoading.value = false;
    }
  }

  void _processSensorDataFromRaw() {
    if (session.value == null || rawSensorReadings.isEmpty) return;
    _clearDataLists();
    final DateTime sessionStartTime = session.value!.startTime;
    for (var reading in rawSensorReadings) {
      final DateTime timestamp = DateTime.parse(reading['timestamp']);
      final double timeInSeconds =
          timestamp.difference(sessionStartTime).inSeconds.toDouble();
      final double value = (reading['sensor_value'] as num).toDouble();
      final String sensorType = reading['sensor_type'];
      _addChartData(sensorType, timeInSeconds, value);
    }
    _sortAllSensorData();
  }

  void _processRecoveredData(List<Map<String, dynamic>> readings) {
    if (session.value == null || readings.isEmpty) return;
    _clearDataLists();
    final DateTime sessionStartTime = session.value!.startTime;
    for (var reading in readings) {
      final DateTime timestamp = DateTime.parse(reading['timestamp']);
      final double timeInSeconds =
          timestamp.difference(sessionStartTime).inSeconds.toDouble();
      if (reading['co2'] != null) {
        _addChartData('CO2', timeInSeconds, (reading['co2'] as num).toDouble());
      }
      if (reading['ch4'] != null) {
        _addChartData('CH4', timeInSeconds, (reading['ch4'] as num).toDouble());
      }
      if (reading['temperatura'] != null) {
        _addChartData('Temperatura', timeInSeconds,
            (reading['temperatura'] as num).toDouble());
      }
      if (reading['humedad'] != null) {
        _addChartData(
            'Humedad', timeInSeconds, (reading['humedad'] as num).toDouble());
      }
    }
    _sortAllSensorData();
  }

  void _clearDataLists() {
    co2Data.clear();
    ch4Data.clear();
    temperaturaData.clear();
    humedadData.clear();
  }

  void _addChartData(String type, double time, double value) {
    switch (type) {
      case 'CO2':
        co2Data.add(SensorChartData(timeInSeconds: time, value: value));
        break;
      case 'CH4':
        ch4Data.add(SensorChartData(timeInSeconds: time, value: value));
        break;
      case 'Temperatura':
        temperaturaData.add(SensorChartData(timeInSeconds: time, value: value));
        break;
      case 'Humedad':
        humedadData.add(SensorChartData(timeInSeconds: time, value: value));
        break;
    }
  }

  void _sortAllSensorData() {
    co2Data.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    ch4Data.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    temperaturaData.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    humedadData.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
  }

  void _calculateStatistics() {
    co2Stats.value = _calculateSensorStats(co2Data);
    ch4Stats.value = _calculateSensorStats(ch4Data);
    temperaturaStats.value = _calculateSensorStats(temperaturaData);
    humedadStats.value = _calculateSensorStats(humedadData);
  }

  SensorStats? _calculateSensorStats(List<SensorChartData> data) {
    if (data.isEmpty) return null;
    double min = double.maxFinite, max = double.negativeInfinity, sum = 0;
    for (var item in data) {
      if (item.value < min) min = item.value;
      if (item.value > max) max = item.value;
      sum += item.value;
    }
    return SensorStats(min: min, max: max, average: sum / data.length);
  }

  double get maxTime {
    double maxVal = 0;
    List<List<SensorChartData>> allData = [
      co2Data,
      ch4Data,
      temperaturaData,
      humedadData
    ];
    for (var dataList in allData) {
      if (dataList.isNotEmpty && dataList.last.timeInSeconds > maxVal) {
        maxVal = dataList.last.timeInSeconds;
      }
    }
    return maxVal > 0 ? maxVal : 1;
  }
}

class SessionDetailsScreen extends StatelessWidget {
  final String sessionId;
  const SessionDetailsScreen({super.key, required this.sessionId});

  // --- INICIO DE CAMBIO: Función _captureWidget actualizada ---
  /// Captura un widget (identificado por su GlobalKey) como una imagen.
  Future<Uint8List?> _captureWidget(GlobalKey key, Logger logger) async {
    try {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image =
          await boundary.toImage(pixelRatio: 2.0); // Aumentar la resolución
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      // Se utiliza el logger pasado como parámetro para evitar el error 'Logger not found'.
      logger.e("Error capturando widget para PDF: $e");
      return null;
    }
  }

  // --- FIN DE CAMBIO ---
  // --- INICIO DE CAMBIO: Función _generatePdfReport mejorada ---
  Future<void> _generatePdfReport(SessionDetailsController controller) async {
    final pdf = pw.Document();
    final session = controller.session.value;

    if (session == null) {
      Get.snackbar(
          "Error", "No se pueden generar reportes sin datos de sesión.");
      return;
    }

    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final textStyle = pw.TextStyle(font: font, fontSize: 9);
    final headerStyle = pw.TextStyle(font: boldFont, fontSize: 11);
    final smallHeaderStyle = pw.TextStyle(font: boldFont, fontSize: 9);

    // Capturar imágenes de las gráficas pasando el logger del controlador
    final logger = controller._logger;
    final combinedChartBytes = await _captureWidget(_combinedChartKey, logger);
    final co2ChartBytes = await _captureWidget(_co2ChartKey, logger);
    final ch4ChartBytes = await _captureWidget(_ch4ChartKey, logger);
    final tempChartBytes = await _captureWidget(_tempChartKey, logger);
    final humChartBytes = await _captureWidget(_humChartKey, logger);
    final tempHumCombinedChartBytes =
        await _captureWidget(_tempHumCombinedChartKey, logger);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (pw.Context context) => pw.Header(
        level: 0,
        child: pw.Text('Reporte de Monitoreo - TANARI',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
      ),
      footer: (pw.Context context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey)),
      ),
      build: (pw.Context context) => [
        // SECCIÓN 1: Información de la Sesión
        pw.Header(level: 1, text: session.operationName ?? 'Sesión sin Nombre'),
        pw.Paragraph(text: session.description ?? 'Sin descripción.'),
        pw.SizedBox(height: 10),
        pw.Text(
            'Inicio: ${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)}'),
        pw.Text(
            'Fin: ${session.endTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(session.endTime!) : "En curso"}'),
        pw.Divider(height: 10),

        // SECCIÓN 2: Visualización Gráfica

        // Combinados charts
        pw.Header(level: 2, text: 'Visualización Gráfica'),
        pw.SizedBox(height: 15),
        if (combinedChartBytes != null) ...[
          pw.Text('Gráfica Combinada de Gases (ppm)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.SizedBox(
            height: 400,
            width: 600,
            child: pw.Image(pw.MemoryImage(combinedChartBytes)),
          ),
          // pw.Image(pw.MemoryImage(combinedChartBytes), fit: pw.BoxFit.contain),
          _buildPdfStatsRow(
              stats1: controller.co2Stats.value,
              label1: 'CO2',
              stats2: controller.ch4Stats.value,
              label2: 'CH4'),
          pw.SizedBox(height: 1),
        ],
        if (tempHumCombinedChartBytes != null) ...[
          pw.Text('Gráfica Combinada de Parámetros Ambientales',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.SizedBox(
            height: 400,
            width: 600,
            child: pw.Image(pw.MemoryImage(tempHumCombinedChartBytes)),
          ),
          // pw.Image(pw.MemoryImage(tempHumCombinedChartBytes),
          //     fit: pw.BoxFit.contain),
          _buildPdfStatsRow(
              stats1: controller.temperaturaStats.value,
              label1: 'Temp (°C)',
              stats2: controller.humedadStats.value,
              label2: 'Hum (%)'),
          pw.SizedBox(height: 15),
        ],
// --- INICIO DE CAMBIO: Gráficos individuales en una cuadrícula 2x2 ---
        pw.Text('Gráficos Individuales', style: headerStyle),
        pw.SizedBox(height: 5),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              child: pw.Column(children: [
            if (co2ChartBytes != null) ...[
              pw.Text('CO₂ (ppm)', style: smallHeaderStyle),
              pw.Image(pw.MemoryImage(co2ChartBytes)),
            ]
          ])),
          pw.SizedBox(width: 10),
          pw.Expanded(
              child: pw.Column(children: [
            if (ch4ChartBytes != null) ...[
              pw.Text('CH₄ (ppm)', style: smallHeaderStyle),
              pw.Image(pw.MemoryImage(ch4ChartBytes)),
            ]
          ])),
        ]),
        pw.SizedBox(height: 10),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              child: pw.Column(children: [
            if (tempChartBytes != null) ...[
              pw.Text('Temperatura (°C)', style: smallHeaderStyle),
              pw.Image(pw.MemoryImage(tempChartBytes)),
            ]
          ])),
          pw.SizedBox(width: 10),
          pw.Expanded(
              child: pw.Column(children: [
            if (humChartBytes != null) ...[
              pw.Text('Humedad (%)', style: smallHeaderStyle),
              pw.Image(pw.MemoryImage(humChartBytes)),
            ]
          ])),
        ]),
        // --- FIN DE CAMBIO ---
        //Individual Charts
        // if (co2ChartBytes != null) ...[
        //   pw.Text('Gráfica de CO₂ (ppm)',
        //       style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        //   pw.Image(pw.MemoryImage(co2ChartBytes), fit: pw.BoxFit.contain),
        //   pw.SizedBox(height: 15),
        // ],
        // if (ch4ChartBytes != null) ...[
        //   pw.Text('Gráfica de CH₄ (ppm)',
        //       style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        //   pw.Image(pw.MemoryImage(ch4ChartBytes), fit: pw.BoxFit.contain),
        //   pw.SizedBox(height: 15),
        // ],
        // if (tempChartBytes != null) ...[
        //   pw.Text('Gráfica de Temperatura (°C)',
        //       style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        //   pw.Image(pw.MemoryImage(tempChartBytes), fit: pw.BoxFit.contain),
        //   pw.SizedBox(height: 15),
        // ],
        // if (humChartBytes != null) ...[
        //   pw.Text('Gráfica de Humedad (%)',
        //       style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        //   pw.Image(pw.MemoryImage(humChartBytes), fit: pw.BoxFit.contain),
        // ],

        // SECCIÓN 3: Datos en Tablas
        pw.NewPage(),
        pw.Header(level: 2, text: 'Datos Detallados en Tablas'),
        pw.Text('Datos de CO2 y CH4:'),
        _buildPdfTable([
          'Tiempo (s)',
          'CO2 (ppm)',
          'CH4 (ppm)'
        ], [
          for (var i = 0; i < controller.co2Data.length; i++)
            [
              controller.co2Data[i].timeInSeconds.toStringAsFixed(0),
              controller.co2Data[i].value.toStringAsFixed(2),
              (i < controller.ch4Data.length)
                  ? controller.ch4Data[i].value.toStringAsFixed(2)
                  : 'N/A'
            ]
        ]),
        pw.SizedBox(height: 20),
        pw.Text('Datos de Temperatura y Humedad:'),
        _buildPdfTable([
          'Tiempo (s)',
          'Temp (°C)',
          'Hum (%)'
        ], [
          for (var i = 0; i < controller.temperaturaData.length; i++)
            [
              controller.temperaturaData[i].timeInSeconds.toStringAsFixed(0),
              controller.temperaturaData[i].value.toStringAsFixed(2),
              (i < controller.humedadData.length)
                  ? controller.humedadData[i].value.toStringAsFixed(2)
                  : 'N/A'
            ]
        ]),
      ],
    ));

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _buildPdfStatsRow(
      {SensorStats? stats1,
      String? label1,
      SensorStats? stats2,
      String? label2}) {
    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey, width: 0.5),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            if (stats1 != null && label1 != null)
              _buildPdfStatItem(label1, stats1),
            if (stats2 != null && label2 != null)
              _buildPdfStatItem(label2, stats2),
          ],
        ));
  }

  pw.Widget _buildPdfStatItem(String label, SensorStats stats) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Mín: ${stats.min.toStringAsFixed(2)}'),
          pw.Text('Máx: ${stats.max.toStringAsFixed(2)}'),
          pw.Text('Prom: ${stats.average.toStringAsFixed(2)}'),
        ]);
  }

  pw.Widget _buildPdfTable(List<String> headers, List<List<String>> data) {
    return pw.Table.fromTextArray(
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      headers: headers,
      data: data,
      border: pw.TableBorder.all(),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 15,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
      },
    );
  }
  // --- FIN DE CAMBIO ---

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
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Ver en Mapa',
            onPressed: () =>
                Get.to(() => MapTanariScreen(sessionId: sessionId)),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Generar Reporte PDF',
            onPressed: () => _generatePdfReport(controller),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (controller.errorMessage.isNotEmpty) {
          return Center(
              child: Text(controller.errorMessage.value,
                  style: TextStyle(color: AppColors.error)));
        }
        if (controller.session.value == null) {
          return const Center(child: Text('No hay detalles para esta sesión.'));
        }
        final sessionDetails = controller.session.value!;
        final maxTime = controller.maxTime;
        final currentMaxX = maxTime * controller.timeRange.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSessionInfoCard(theme, sessionDetails),
              const SizedBox(height: 20),
              _buildVisualizationSelector(controller, theme),
              const SizedBox(height: 16),
              if (controller.visualizationMode.value == 'individual')
                _buildSensorSelector(controller, theme),
              const SizedBox(height: 16),
              _buildTimeRangeSelector(controller, maxTime),
              const SizedBox(height: 16),
              if (controller.visualizationMode.value == 'individual')
                _buildGraphStyleSelector(controller, theme),
              const SizedBox(height: 20),
              Text('Gráficos de Sensores',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildChartSection(controller, theme, currentMaxX),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSessionInfoCard(
      ThemeData theme, OperationSession sessionDetails) {
    final duration = sessionDetails.endTime != null
        ? sessionDetails.endTime!.difference(sessionDetails.startTime)
        : Duration.zero;
    String durationString = '${duration.inMinutes} minutos';
    if (duration.inSeconds < 60 && duration.inMinutes == 0) {
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
            Text(sessionDetails.operationName ?? 'Sesión Sin Nombre',
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const Divider(height: 20, thickness: 1),
            _buildInfoRow(theme, Icons.info_outline, 'Descripción',
                sessionDetails.description ?? 'N/A'),
            _buildInfoRow(
                theme,
                Icons.calendar_today,
                'Inicio',
                DateFormat('dd/MM/yyyy HH:mm:ss')
                    .format(sessionDetails.startTime)),
            _buildInfoRow(
                theme,
                Icons.access_time,
                'Fin',
                sessionDetails.endTime != null
                    ? DateFormat('dd/MM/yyyy HH:mm:ss')
                        .format(sessionDetails.endTime!)
                    : 'En curso'),
            _buildInfoRow(theme, Icons.timer, 'Duración', durationString),
            _buildInfoRow(theme, Icons.settings, 'Modo',
                sessionDetails.mode.capitalizeFirst ?? 'Desconocido'),
            if (sessionDetails.routeNumber != null)
              _buildInfoRow(theme, Icons.alt_route, 'Ruta',
                  sessionDetails.routeNumber.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.neutralDark),
          const SizedBox(width: 10),
          Text('$label:',
              style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(width: 5),
          Expanded(
              child: Text(value,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textSecondary))),
        ],
      ),
    );
  }

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
                label: 'Individual'),
            _buildVisualizationOption(
                controller: controller,
                theme: theme,
                mode: 'todas',
                icon: Icons.auto_graph,
                label: 'Combinado'),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizationOption(
      {required SessionDetailsController controller,
      required ThemeData theme,
      required String mode,
      required IconData icon,
      required String label}) {
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
              width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label,
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

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
                color: AppColors.chartCO2),
            _buildSensorOption(
                controller: controller,
                theme: theme,
                sensor: 'CH4',
                label: 'CH₄',
                color: AppColors.chartCH4),
            _buildSensorOption(
                controller: controller,
                theme: theme,
                sensor: 'Temperatura',
                label: 'Temperatura',
                color: AppColors.chartTemperature),
            _buildSensorOption(
                controller: controller,
                theme: theme,
                sensor: 'Humedad',
                label: 'Humedad',
                color: AppColors.chartHumidity),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorOption(
      {required SessionDetailsController controller,
      required ThemeData theme,
      required String sensor,
      required String label,
      required Color color}) {
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
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: isSelected ? color : AppColors.neutralLight, width: 1)),
    );
  }

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
            Text('Rango de Tiempo',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('0s'),
                Expanded(
                    child: Obx(() => Slider(
                        value: controller.timeRange.value,
                        onChanged: (value) =>
                            controller.timeRange.value = value,
                        min: 0,
                        max: 1))),
                Obx(() => Text(
                    '${(maxTime * controller.timeRange.value).toStringAsFixed(0)}s')),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
            Text('Estilo de Gráfica',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                    color: AppColors.chartCO2),
                _buildGraphStyleOption(
                    controller: controller,
                    theme: theme,
                    sensor: 'CH4',
                    label: 'CH₄',
                    color: AppColors.chartCH4),
                _buildGraphStyleOption(
                    controller: controller,
                    theme: theme,
                    sensor: 'Temperatura',
                    label: 'Temperatura',
                    color: AppColors.chartTemperature),
                _buildGraphStyleOption(
                    controller: controller,
                    theme: theme,
                    sensor: 'Humedad',
                    label: 'Humedad',
                    color: AppColors.chartHumidity),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphStyleOption(
      {required SessionDetailsController controller,
      required ThemeData theme,
      required String sensor,
      required String label,
      required Color color}) {
    final bool isDiscrete = controller.discreteMode[sensor] ?? false;
    return ChoiceChip(
      label: Text(label),
      selected: isDiscrete,
      onSelected: (selected) => controller.discreteMode[sensor] = selected,
      backgroundColor: Colors.transparent,
      selectedColor: color.withAlpha(51),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: isDiscrete ? color : AppColors.textSecondary,
          fontWeight: isDiscrete ? FontWeight.bold : FontWeight.normal),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: isDiscrete ? color : AppColors.neutralLight, width: 1)),
    );
  }

  Widget _buildChartSection(SessionDetailsController controller,
      ThemeData theme, double currentMaxX) {
    return Column(
      children: [
        if (controller.visualizationMode.value == 'todas')
          Column(
            children: [
              RepaintBoundary(
                key: _combinedChartKey,
                child: _buildCombinedChart(controller, theme, currentMaxX),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _tempHumCombinedChartKey,
                child:
                    _buildTempHumCombinedChart(controller, theme, currentMaxX),
              ),
            ],
          ),
        if (controller.visualizationMode.value == 'individual')
          _buildIndividualCharts(controller, theme, currentMaxX),
      ],
    );
  }

  Widget _buildIndividualCharts(SessionDetailsController controller,
      ThemeData theme, double currentMaxX) {
    return SizedBox(
      height: 420,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (controller.selectedSensors.contains('CO2'))
            RepaintBoundary(
                key: _co2ChartKey,
                child: _buildSensorCard(
                    theme: theme,
                    title: 'CO₂ (ppm)',
                    data: controller.co2Data,
                    color: AppColors.chartCO2,
                    unit: 'ppm',
                    showPoints: controller.discreteMode['CO2'] ?? false,
                    currentMaxX: currentMaxX)),
          if (controller.selectedSensors.contains('CH4'))
            const SizedBox(width: 16),
          if (controller.selectedSensors.contains('CH4'))
            RepaintBoundary(
                key: _ch4ChartKey,
                child: _buildSensorCard(
                    theme: theme,
                    title: 'CH₄ (ppm)',
                    data: controller.ch4Data,
                    color: AppColors.chartCH4,
                    unit: 'ppm',
                    showPoints: controller.discreteMode['CH4'] ?? false,
                    currentMaxX: currentMaxX)),
          if (controller.selectedSensors.contains('Temperatura'))
            const SizedBox(width: 16),
          if (controller.selectedSensors.contains('Temperatura'))
            RepaintBoundary(
                key: _tempChartKey,
                child: _buildSensorCard(
                    theme: theme,
                    title: 'Temperatura (°C)',
                    data: controller.temperaturaData,
                    color: AppColors.chartTemperature,
                    unit: '°C',
                    showPoints: controller.discreteMode['Temperatura'] ?? false,
                    currentMaxX: currentMaxX)),
          if (controller.selectedSensors.contains('Humedad'))
            const SizedBox(width: 16),
          if (controller.selectedSensors.contains('Humedad'))
            RepaintBoundary(
                key: _humChartKey,
                child: _buildSensorCard(
                    theme: theme,
                    title: 'Humedad (%)',
                    data: controller.humedadData,
                    color: AppColors.chartHumidity,
                    unit: '%',
                    showPoints: controller.discreteMode['Humedad'] ?? false,
                    currentMaxX: currentMaxX)),
        ],
      ),
    );
  }

  // --- INICIO DE CAMBIO: Nueva gráfica combinada para Temp/Hum ---
  Widget _buildTempHumCombinedChart(SessionDetailsController controller,
      ThemeData theme, double currentMaxX) {
    final hasTemp = controller.temperaturaData.isNotEmpty;
    final hasHum = controller.humedadData.isNotEmpty;

    if (!hasTemp && !hasHum) {
      return const SizedBox(
          height: 300,
          child: Center(child: Text("No hay datos ambientales para mostrar.")));
    }

    // Eje Y izquierdo para Temperatura
    double minTemp = double.maxFinite, maxTemp = double.negativeInfinity;
    if (hasTemp) {
      final tempStats = controller.temperaturaStats.value;
      if (tempStats != null) {
        minTemp = tempStats.min;
        maxTemp = tempStats.max;
      }
    }
    if (minTemp == double.maxFinite) minTemp = 0;
    if (maxTemp == double.negativeInfinity) maxTemp = 40;
    if (minTemp == maxTemp) {
      minTemp -= 5;
      maxTemp += 5;
    }

    return SizedBox(
      height: 400,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("Parámetros Ambientales",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: currentMaxX > 0 ? currentMaxX : 1,

                    // Configuración de los ejes Y
                    minY: minTemp - (maxTemp - minTemp) * 0.1,
                    maxY: maxTemp + (maxTemp - minTemp) * 0.1,

                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) =>
                                Text('${value.toStringAsFixed(0)}°C')),
                        axisNameWidget: const Text("Temp"),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            // Mapear el valor del eje izquierdo (Temp) al rango del derecho (Hum)
                            final tempRange =
                                (maxTemp + (maxTemp - minTemp) * 0.1) -
                                    (minTemp - (maxTemp - minTemp) * 0.1);
                            final humValue = ((value -
                                        (minTemp - (maxTemp - minTemp) * 0.1)) /
                                    tempRange) *
                                100;
                            return Text('${humValue.toStringAsFixed(0)}%');
                          },
                        ),
                        axisNameWidget: const Text("Hum"),
                      ),
                      bottomTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 30)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      // Línea de Temperatura (usa el eje izquierdo por defecto)
                      if (hasTemp)
                        _buildLineChartBarData(controller.temperaturaData,
                            AppColors.chartTemperature, currentMaxX),
                      // Línea de Humedad (mapeada para ajustarse a la escala de temperatura)
                      if (hasHum)
                        LineChartBarData(
                          spots: controller.humedadData
                              .where((d) => d.timeInSeconds <= currentMaxX)
                              .map((d) {
                            // Mapear valor de 0-100 a la escala de temperatura
                            final tempRange =
                                (maxTemp + (maxTemp - minTemp) * 0.1) -
                                    (minTemp - (maxTemp - minTemp) * 0.1);
                            final scaledValue = (d.value / 100) * tempRange +
                                (minTemp - (maxTemp - minTemp) * 0.1);
                            return FlSpot(d.timeInSeconds, scaledValue);
                          }).toList(),
                          isCurved: true,
                          color: AppColors.chartHumidity,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10), // Add a legend for the combined chart
              _buildChartLegend(AppColors.chartTemperature, 'Temp',
                  AppColors.chartHumidity, 'Hum'),
            ],
          ),
        ),
      ),
    );
  }
  // --- FIN DE CAMBIO ---

  Widget _buildCombinedChart(SessionDetailsController controller,
      ThemeData theme, double currentMaxX) {
    final hasCo2 = controller.co2Data.isNotEmpty;
    final hasCh4 = controller.ch4Data.isNotEmpty;

    if (!hasCo2 && !hasCh4) {
      return const SizedBox(
          height: 300,
          child: Center(child: Text("No hay datos de gases para mostrar.")));
    }

    double minY = double.maxFinite, maxY = double.negativeInfinity;
    if (hasCo2) {
      final co2Stats = controller.co2Stats.value;
      if (co2Stats != null) {
        if (co2Stats.min < minY) minY = co2Stats.min;
        if (co2Stats.max > maxY) maxY = co2Stats.max;
      }
    }
    if (hasCh4) {
      final ch4Stats = controller.ch4Stats.value;
      if (ch4Stats != null) {
        if (ch4Stats.min < minY) minY = ch4Stats.min;
        if (ch4Stats.max > maxY) maxY = ch4Stats.max;
      }
    }

    if (minY == double.maxFinite) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 100;

    if (minY == maxY) {
      minY -= 10;
      maxY += 10;
    }
    minY -= (maxY - minY) * 0.1;
    maxY += (maxY - minY) * 0.1;
    if (minY < 0) minY = 0;

    return SizedBox(
      height: 400,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("Gases (ppm)",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: currentMaxX > 0 ? currentMaxX : 1,
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 40)),
                      bottomTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 30)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      if (hasCo2)
                        _buildLineChartBarData(controller.co2Data,
                            AppColors.chartCO2, currentMaxX),
                      if (hasCh4)
                        _buildLineChartBarData(controller.ch4Data,
                            AppColors.chartCH4, currentMaxX),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final isCo2 =
                                barSpot.bar.color == AppColors.chartCO2;
                            String sensorName = isCo2 ? 'CO₂' : 'CH₄';
                            return LineTooltipItem(
                              '$sensorName: ${barSpot.y.toStringAsFixed(2)} ppm',
                              TextStyle(
                                  color: barSpot.bar.color,
                                  fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // --- INICIO DE CAMBIO: Leyenda para la gráfica combinada ---
              const SizedBox(height: 10),
              _buildChartLegend(
                  AppColors.chartCO2, 'CO₂', AppColors.chartCH4, 'CH₄'),
              // --- FIN DE CAMBIO ---
            ],
          ),
        ),
      ),
    );
  }

  // --- INICIO DE CAMBIO: Widget para la leyenda ---
  Widget _buildChartLegend(
      Color color1, String label1, Color color2, String label2) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(color1, label1),
        const SizedBox(width: 20),
        _legendItem(color2, label2),
      ],
    );
  }

  Widget _legendItem(Color color, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(name),
      ],
    );
  }
  // --- FIN DE CAMBIO ---

  LineChartBarData _buildLineChartBarData(
      List<SensorChartData> data, Color color, double currentMaxX) {
    return LineChartBarData(
      spots: data
          .where((d) => d.timeInSeconds <= currentMaxX)
          .map((d) => FlSpot(d.timeInSeconds, d.value))
          .toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(show: false),
    );
  }

  Widget _buildSensorCard({
    required ThemeData theme,
    required String title,
    required List<SensorChartData> data,
    required Color color,
    required String unit,
    bool showPoints = false,
    required double currentMaxX,
  }) {
    final filteredData =
        data.where((d) => d.timeInSeconds <= currentMaxX).toList();
    final hasData = filteredData.isNotEmpty;
    SensorStats? stats;
    if (hasData) {
      double min = double.maxFinite, max = double.negativeInfinity, sum = 0;
      for (var item in filteredData) {
        if (item.value < min) min = item.value;
        if (item.value > max) max = item.value;
        sum += item.value;
      }
      stats =
          SensorStats(min: min, max: max, average: sum / filteredData.length);
    }
    double minY = 0, maxY = 100;
    if (stats != null) {
      minY = stats.min - (stats.max - stats.min) * 0.1;
      maxY = stats.max + (stats.max - stats.min) * 0.1;
      if (minY < 0) minY = 0;
      if (minY == maxY) {
        minY -= 10;
        maxY += 10;
      }
    }
    return SizedBox(
      width: 380,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: hasData
                    ? LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: currentMaxX > 0 ? currentMaxX : 1,
                          minY: minY,
                          maxY: maxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: filteredData
                                  .map((d) => FlSpot(d.timeInSeconds, d.value))
                                  .toList(),
                              isCurved: !showPoints,
                              color: color,
                              barWidth: 3,
                              dotData: FlDotData(show: showPoints),
                              belowBarData: BarAreaData(
                                  show: true, color: color.withAlpha(77)),
                            ),
                          ],
                        ),
                      )
                    : const Center(child: Text("No hay datos")),
              ),
              if (stats != null) ...[
                const SizedBox(height: 8),
                _buildStatsTable(theme, stats, color),
              ]
            ],
          ),
        ),
      ),
    );
  }

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
              theme: theme, title: 'MÍN', value: stats.min, color: color),
          Container(width: 1, height: 40, color: color.withAlpha(77)),
          _buildStatBox(
              theme: theme, title: 'MÁX', value: stats.max, color: color),
          Container(width: 1, height: 40, color: color.withAlpha(77)),
          _buildStatBox(
              theme: theme, title: 'PROM', value: stats.average, color: color),
        ],
      ),
    );
  }

  Widget _buildStatBox(
      {required ThemeData theme,
      required String title,
      required double value,
      required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withAlpha(51), width: 1)),
          child: Text(value.toStringAsFixed(2),
              style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ],
    );
  }
}
