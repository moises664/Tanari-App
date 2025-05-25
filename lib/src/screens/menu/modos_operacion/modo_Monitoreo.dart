import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:shared_preferences/shared_preferences.dart'; // Importar Shared Preferences

/// Pantalla principal para el monitoreo de datos ambientales (Modo DP)
/// Muestra valores de sensores en tarjetas con diseño consistente y persistencia de datos.
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

  // Valores actuales de los sensores. Inicializados a '--' para indicar que no hay datos.
  String _co2 = '--';
  String _ch4 = '--';
  String _temperatura = '--';
  String _humedad = '--';

  // Instancia de SharedPreferences para la persistencia de datos.
  // Es nullable (?) porque se inicializa de forma asíncrona.
  SharedPreferences? _prefs;

  //----------------------------------------------------------------------------
  // MÉTODOS DEL CICLO DE VIDA DEL WIDGET
  //----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadSensorData(); // Llama a la carga de datos guardados al iniciar la pantalla
  }

  //----------------------------------------------------------------------------
  // MÉTODOS DE LÓGICA DE NEGOCIO Y PERSISTENCIA
  //----------------------------------------------------------------------------

  /// Carga los datos de los sensores desde SharedPreferences.
  /// Si no hay datos guardados, las variables de los sensores mantendrán su valor inicial '--'.
  Future<void> _loadSensorData() async {
    _prefs = await SharedPreferences
        .getInstance(); // Obtiene la instancia de SharedPreferences
    setState(() {
      // Carga los valores guardados, usando '--' como fallback si no existen.
      // El operador '!' se usa porque, después del 'await', _prefs ya no será nulo.
      _co2 = _prefs!.getString('co2') ?? '--';
      _ch4 = _prefs!.getString('ch4') ?? '--';
      _temperatura = _prefs!.getString('temperatura') ?? '--';
      _humedad = _prefs!.getString('humedad') ?? '--';
    });
  }

  /// Guarda los valores actuales de los sensores en SharedPreferences.
  /// Solo guarda si la instancia de SharedPreferences ya está inicializada.
  Future<void> _saveSensorData() async {
    if (_prefs != null) {
      // Guarda cada valor de sensor como String.
      await _prefs!.setString('co2', _co2);
      await _prefs!.setString('ch4', _ch4);
      await _prefs!.setString('temperatura', _temperatura);
      await _prefs!.setString('humedad', _humedad);
    } else {
      // Advertencia en la consola si se intenta guardar antes de la inicialización.
      debugPrint(
          "Advertencia: SharedPreferences no inicializado aún. No se pueden guardar datos.");
    }
  }

  /// Simula la actualización de los valores de los sensores y los guarda.
  void _actualizarDatos() {
    setState(() {
      // Asigna nuevos valores simulados a las variables de estado.
      _co2 = '450';
      _ch4 = '1.2';
      _temperatura = '25.5';
      _humedad = '65';
    });

    _saveSensorData(); // Llama al método para guardar los datos actualizados.

    // Muestra un SnackBar para notificar al usuario que los datos se han actualizado.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos actualizados y guardados.'),
          duration: Duration(seconds: 1),
        ),
      );
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
      // El AppBar ha sido removido intencionalmente para usar un título personalizado.
      body: SingleChildScrollView(
        physics:
            const BouncingScrollPhysics(), // Permite un efecto de rebote al hacer scroll
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal:
                screenSize.width * 0.05, // Padding horizontal adaptativo
            vertical: 20, // Padding vertical
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título de la pantalla centrado en un contenedor con el color primario
              _buildTitleContainer(theme),
              const SizedBox(
                  height: 20), // Espacio entre el título y el encabezado
              // Encabezado secundario de la pantalla
              _buildHeader(theme),
              const SizedBox(
                  height:
                      20), // Espacio entre el encabezado y la lista de sensores
              // Lista de tarjetas de sensores
              _buildSensorList(),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el contenedor del título principal de la pantalla.
  Widget _buildTitleContainer(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 16), // Margen para el contenedor
      height: 60, // Altura fija para el contenedor del título
      width: double.infinity, // Ancho completo disponible
      alignment: Alignment.center, // Centra el contenido dentro del contenedor
      decoration: BoxDecoration(
        color: AppColors.primary, // Color de fondo del contenedor del título
        borderRadius: BorderRadius.circular(20), // Bordes redondeados
      ),
      child: Text(
        'Modo DP', // Texto del título
        style: theme.textTheme.headlineSmall?.copyWith(
          color: AppColors.backgroundWhite, // Color del texto del título
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Construye el encabezado (subtítulo) de la sección de monitoreo.
  Widget _buildHeader(ThemeData theme) {
    return Text(
      'Monitoreo Ambiental',
      style: theme.textTheme.headlineSmall?.copyWith(
        color: AppColors.backgroundBlack,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Construye la lista de tarjetas de sensores, cada una envuelta en un contenedor con color primario.
  Widget _buildSensorList() {
    return Column(
      children: [
        _buildSensorCardContainer(
          _SensorCard(
            label: 'CO2',
            value: _co2,
            unit: 'ppm',
            icon: Icons.cloud,
            cardColor: Colors.green,
            iconColor: Colors.grey.shade700,
          ),
        ),
        const SizedBox(
            height: 15), // Espacio entre los contenedores de las tarjetas

        _buildSensorCardContainer(
          _SensorCard(
            label: 'CH4',
            value: _ch4,
            unit: 'ppm',
            icon: Icons.local_fire_department,
            cardColor: Colors.green,
            iconColor: Colors.red.shade700,
          ),
        ),
        const SizedBox(height: 15),

        _buildSensorCardContainer(
          _SensorCard(
            label: 'Temperatura',
            value: _temperatura,
            unit: 'ºC',
            icon: Icons.thermostat,
            cardColor: Colors.green,
            iconColor: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 15),

        _buildSensorCardContainer(
          _SensorCard(
            label: 'Humedad',
            value: _humedad,
            unit: '%',
            icon: Icons.water_drop,
            cardColor: Colors.green,
            iconColor: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 25), // Más espacio antes del botón

        // Botón para actualizar los datos de los sensores.
        ElevatedButton.icon(
          onPressed: _actualizarDatos,
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          label: Text(
            'Actualizar Datos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                AppColors.backgroundBlack, // Fondo oscuro para contraste
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// Envolver una _SensorCard en un Container con estilo para resaltarla.
  Widget _buildSensorCardContainer(Widget sensorCard) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary, // Color de fondo del contenedor externo
        borderRadius:
            BorderRadius.circular(15), // Bordes redondeados del contenedor
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51), // Sombra para dar profundidad
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(
          5), // Pequeño padding interno para que se vea el borde primario
      child: sensorCard, // La _SensorCard se coloca dentro de este contenedor
    );
  }
}

/// Widget de tarjeta individual para mostrar el valor de un sensor.
class _SensorCard extends StatelessWidget {
  final String label; // Etiqueta del sensor (ej. 'CO2')
  final String value; // Valor del sensor (ej. '450')
  final String unit; // Unidad de medida (ej. 'ppm')
  final IconData icon; // Icono representativo del sensor
  final Color
      cardColor; // Color principal para el texto y elementos de la tarjeta
  final Color iconColor; // Color específico para el icono

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
      // Contenedor interno de la tarjeta, con su propio estilo y color de fondo.
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite, // Fondo blanco de la tarjeta interna
        borderRadius:
            BorderRadius.circular(10), // Bordes ligeramente redondeados
      ),
      child: Row(
        children: [
          // Contenedor circular para el icono del sensor.
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color.alphaBlend(cardColor.withAlpha(51),
                  Colors.white), // Color semitransparente basado en cardColor
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
                // Etiqueta del sensor en mayúsculas.
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cardColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(
                    height: 6), // Espacio entre la etiqueta y el valor
                // Valor del sensor con su unidad.
                RichText(
                  text: TextSpan(
                    text: value, // El valor numérico
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: cardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                    children: [
                      TextSpan(
                        text: ' $unit', // La unidad de medida
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Color.alphaBlend(
                              cardColor.withAlpha(204), Colors.white),
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
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
