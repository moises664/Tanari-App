import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Pantalla "Acerca de TANARI"**
///
/// Funciona como un manual de usuario interactivo que explica el propósito,
/// la tecnología y el funcionamiento de la aplicación TANARI en el contexto del
/// proyecto de tesis.
class AcercaApp extends StatelessWidget {
  const AcercaApp({super.key});

  /// Función para abrir un enlace URL en el navegador externo.
  /// Utilizada para los créditos y enlaces a recursos.
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Manejo de error si no se puede abrir el enlace.
      // En una app real, aquí se podría mostrar un Get.snackbar o un diálogo.
      debugPrint('No se pudo lanzar $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          'Acerca de TANARI',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.backgroundWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(color: AppColors.backgroundWhite),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de bienvenida y resumen del proyecto.
            _buildInfoCard(
              theme: theme,
              icon: Icons.science_outlined,
              title: 'Trabajo Especial de Grado: Ingeniería Electrónica',
              content:
                  'Esta aplicación es la interfaz de control para el Trabajo Especial de Grado, la cual tiene el nombre de:\n\n'
                  '**"DISPOSITIVO PORTÁTIL PARA MONITOREO DE EMISIONES DE GASES DE EFECTO INVERNADERO CON ACOPLE A UN VEHÍCULO TERRESTRE NO TRIPULADO"**',
            ),
            const SizedBox(height: 20),

            // Sección interactiva con paneles desplegables.
            _buildInteractiveManual(theme),

            const SizedBox(height: 20),
            // Card con los créditos de los desarrolladores.
            _buildCreditsCard(theme),
          ],
        ),
      ),
    );
  }

  /// Construye la sección principal del manual con paneles desplegables.
  Widget _buildInteractiveManual(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: AppColors.backgroundLight,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Panel 1: ¿Qué es TANARI?
            _buildExpansionTile(
              theme: theme,
              icon: Icons.help_outline,
              title: '¿Qué es TANARI?',
              children: [
                _buildRichText(
                  '**TANARI** es el corazón de nuestro sistema. No es solo una aplicación, sino el puente de comunicación y control entre el **Dispositivo Portátil (DP)** de monitoreo y el **Vehículo Terrestre no Tripulado (UGV)**.',
                ),
                _buildRichText(
                  'Su propósito principal es permitir el control del UGV en recorridos de monitoreo prolongados y servir como nexo para subir todos los datos recolectados a la nube (**Supabase**), creando un registro histórico para su posterior análisis.',
                ),
              ],
            ),
            const Divider(height: 1),

            // Panel 2: Nuestra Tecnología
            _buildExpansionTile(
              theme: theme,
              icon: Icons.memory,
              title: 'Nuestra Tecnología',
              children: [
                _buildRichText(
                  '**Tanari** usa la comunicacion via **BLE (Bluetooth Low Energy)** para conectarse a los dispositivos **DP** y **UGV**, donde estos datos se transmiten en tiempo real a la **APP**. A su vez, la aplicación utiliza **Supabase** como backend en la nube para almacenar y gestionar todos los datos recolectados, asegurando que estén accesibles para análisis futuros y toma de decisiones informadas.',
                ),
                _buildRichText(
                  'Aunque nuestra trabajo especial de grado es de naturaleza electrónica, generamos datos valiosos. Por ello, el **Dispositivo Portátil (DP)** está equipado con sensores para medir gases de efecto invernadero como **CO2** y **CH4**, además de parámetros ambientales como **temperatura** y **humedad**.',
                ),
                _buildRichText(
                  'El **UGV** o **Vehicullo terrestre no tripulado **,  usa **odometría** y un **magnetómetro**, para estimar su posición y desplazamiento, lo que permite la creación de rutas autónomas precisas.',
                ),
              ],
            ),
            const Divider(height: 1),

            // Panel 3: Guía de Uso por Modos
            _buildExpansionTile(
              theme: theme,
              icon: Icons.rule,
              title: 'Guía de Uso por Modos',
              children: [
                _buildRichText(
                  '**1. Modo DP (Monitoreo):**\n'
                  'Ideal para mediciones manuales en puntos específicos. Pero al conectar el Dispositivo Portátil (DP) vía Bluetooth, se puede iniciar un nuevo registro y comienza a recibir datos de los sensores en tiempo real para poder cargarlos en una base datos..',
                ),
                _buildRichText(
                  '**2. Modo UGV:**\n'
                  'Permite el control total del vehículo. Desde aquí puedes grabar nuevas rutas, guardar puntos de interés y ejecutar recorridos autónomos previamente guardados. ¡Ideal para mapear áreas de interés!',
                ),
                _buildRichText(
                  '**3. Modo Acople:**\n'
                  'La sinergia perfecta. En este modo, el DP se monta sobre el UGV. Puedes controlar el vehículo manualmente mientras el DP recolecta y transmite datos de forma simultánea, perfecto para misiones de exploración y monitoreo en tiempo real.',
                ),
              ],
            ),
            const Divider(height: 1),

            // Panel 4: El Panorama General
            _buildExpansionTile(
              theme: theme,
              icon: Icons.public,
              title: 'El Panorama General',
              children: [
                _buildRichText(
                  'Este proyecto busca ofrecer una herramienta viable y de bajo costo para el monitoreo de gases de efecto invernadero. Al generar datos geolocalizados y accesibles desde la nube, contribuimos a un mejor entendimiento y a la toma de decisiones informadas para mitigar el cambio climático.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget genérico para una tarjeta de información.
  Widget _buildInfoCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: AppColors.backgroundLight,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildRichText(content),
          ],
        ),
      ),
    );
  }

  /// Widget para construir un panel desplegable (`ExpansionTile`) con estilo personalizado.
  Widget _buildExpansionTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      expandedAlignment: Alignment.topLeft,
      children: children,
    );
  }

  /// Widget para renderizar texto con formato (negritas).
  /// Parsea un texto simple y aplica `FontWeight.bold` a los fragmentos
  /// encerrados en `**`.
  Widget _buildRichText(String text) {
    List<TextSpan> spans = [];
    text.split('**').asMap().forEach((index, part) {
      spans.add(
        TextSpan(
          text: part,
          style: TextStyle(
            fontWeight: index.isOdd ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: RichText(
        text: TextSpan(children: spans),
      ),
    );
  }

  /// Construye la tarjeta de créditos con los nombres de los autores.
  Widget _buildCreditsCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: AppColors.backgroundLight,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Desarrollado por:',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Divider(height: 20),
            _buildCreditRow(
              name: 'José Méndez',
              githubUrl: 'https://github.com/JoseM059',
            ),
            const SizedBox(height: 10),
            _buildCreditRow(
              name: 'Moisés Rivera',
              githubUrl: 'https://github.com/moises664',
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una fila para un crédito, con nombre y enlace a GitHub.
  Widget _buildCreditRow({required String name, required String githubUrl}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.code), // O un logo de GitHub si lo tuvieras
          color: AppColors.textSecondary,
          tooltip: 'Ver en GitHub',
          onPressed: () => _launchURL(githubUrl),
        ),
      ],
    );
  }
}
