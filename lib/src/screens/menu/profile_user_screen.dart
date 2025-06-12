import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'dart:io'; // Para usar File

import 'package:logging/logging.dart'; // Para el logging
import 'package:tanari_app/src/core/app_colors.dart'; // Importar AppColors

// Define un logger para esta pantalla para un manejo consistente de los mensajes.
final _screenLogger = Logger('ProfileUserScreen');

/// `ProfileUserScreen` es una pantalla sin estado (StatelessWidget)
/// que muestra y permite editar el perfil del usuario.
/// Utiliza GetX para la gestión de estados y la inyección de dependencias.
class ProfileUserScreen extends StatelessWidget {
  // Inyección de dependencia del UserProfileService usando Get.find.
  // Esto permite acceder a la lógica del perfil de forma reactiva.
  final UserProfileService userProfileService = Get.find<UserProfileService>();

  // Controladores para los campos de texto del formulario.
  // Se inicializan aquí y se gestionan por el widget.
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  // Controlador para el campo de texto del correo electrónico (solo lectura)
  final TextEditingController _emailController = TextEditingController();

  // Variable reactiva para almacenar temporalmente el archivo de imagen seleccionado
  // por el usuario antes de que sea subido y procesado.
  final Rx<File?> _selectedImageFile = Rx<File?>(null);

  /// Construye la interfaz de usuario de la pantalla de perfil.
  @override
  Widget build(BuildContext context) {
    // Obx escucha las actualizaciones de `currentUserProfile` de UserProfileService
    // y reconstruye solo la parte del widget que depende de este valor,
    // optimizando el rendimiento y simplificando la gestión del estado.
    return Obx(() {
      final currentUserProfile = userProfileService.currentUserProfile.value;

      // Si el perfil del usuario está disponible, actualiza los controladores de texto.
      // `addPostFrameCallback` asegura que esta operación se realice después de que
      // el frame actual haya sido construido, evitando errores de "setState during build".
      if (currentUserProfile != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _usernameController.text = currentUserProfile.username ?? '';
          _bioController.text = currentUserProfile.bio ?? '';
          _emailController.text =
              currentUserProfile.email ?? ''; // Asigna el correo electrónico
        });
      }

      return Scaffold(
        backgroundColor: AppColors
            .backgroundPrimary, // Fondo principal de la pantalla, un gris claro.
        appBar: AppBar(
          title: const Text(
            'Mi Perfil', // Título de la barra de aplicación.
            style: TextStyle(
              fontWeight: FontWeight.bold, // Texto del título en negrita.
              color: AppColors
                  .backgroundWhite, // Color del texto del título, blanco para contraste.
            ),
          ),
          backgroundColor:
              AppColors.accent, // Color de fondo del AppBar, un azul profundo.
          foregroundColor: AppColors
              .backgroundWhite, // Color de los íconos y texto por defecto en el AppBar.
          elevation:
              0, // Elimina la sombra del AppBar para un diseño más plano.
          centerTitle: true, // Centra el título en la barra.
          actions: [
            // Botón "Guardar Cambios" movido a la AppBar como un IconButton.
            IconButton(
              icon: const Icon(Icons.save), // Ícono de guardar.
              color: AppColors
                  .backgroundWhite, // Color del ícono, blanco para contraste con el azul oscuro.
              onPressed: () async {
                _screenLogger.info('Saving profile changes...');
                await userProfileService.updateProfile(
                  username: _usernameController.text,
                  bio: _bioController.text,
                );
                _screenLogger.info('Profile changes saved.');
                // Opcional: Mostrar un Snackbar de éxito o navegar de vuelta.
                Get.snackbar(
                  'Éxito',
                  'Perfil actualizado correctamente',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor:
                      AppColors.primary, // Usar verde lima para éxito
                  colorText: AppColors.textPrimary, // Texto oscuro en botón
                );
              },
            ),
            // Aquí puedes añadir otras acciones a la AppBar, como un botón de logout.
            // IconButton(
            //   icon: const Icon(Icons.logout),
            //   color: AppColors.backgroundWhite, // Color del ícono de logout.
            //   onPressed: () async {
            //     // Lógica para cerrar sesión, por ejemplo:
            //     // await Get.find<AuthController>().signOut();
            //     // Get.offAllNamed('/login');
            //   },
            // ),
          ],
        ),
        // Si el perfil es nulo (aún cargando), muestra un indicador de progreso.
        // Si ya está cargado, muestra el contenido del perfil.
        body: currentUserProfile == null
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors
                      .accentColor), // Color del indicador de carga (verde vibrante).
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(
                    24.0), // Padding generoso alrededor del contenido.
                child: Column(
                  children: [
                    // GestureDetector permite que el CircleAvatar sea interactivo (para cambiar la imagen).
                    GestureDetector(
                      onTap: () async {
                        final ImagePicker picker =
                            ImagePicker(); // Instancia del ImagePicker.
                        final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery); // Abre la galería.
                        if (image != null) {
                          _selectedImageFile.value = File(image
                              .path); // Almacena temporalmente la imagen seleccionada.
                          _screenLogger.info('Image selected: ${image.path}');
                          // Sube la imagen y actualiza el perfil a través del servicio.
                          await userProfileService
                              .uploadAndSetAvatar(_selectedImageFile.value!);
                          // El Obx se encargará de actualizar la UI cuando la URL del avatar en el servicio cambie.
                        } else {
                          _screenLogger.info('Image selection cancelled.');
                        }
                      },
                      child: Stack(
                        alignment: Alignment
                            .bottomRight, // Alinea el ícono de la cámara en la esquina inferior derecha.
                        children: [
                          // Obx para el avatar, reacciona a cambios en la URL del perfil o la imagen seleccionada.
                          Obx(() {
                            final currentAvatarUrl = userProfileService
                                .currentUserProfile.value?.avatarUrl;
                            final selectedImage = _selectedImageFile.value;

                            ImageProvider?
                                avatarImage; // Puede ser FileImage o NetworkImage.
                            if (selectedImage != null) {
                              avatarImage = FileImage(
                                  selectedImage); // Muestra la imagen local seleccionada.
                            } else if (currentAvatarUrl != null &&
                                currentAvatarUrl.isNotEmpty) {
                              avatarImage = NetworkImage(
                                  currentAvatarUrl); // Muestra la imagen de red del perfil.
                            }

                            return CircleAvatar(
                              radius: 80, // Tamaño del avatar.
                              backgroundColor: AppColors.secondary1.withOpacity(
                                  0.2), // Fondo sutil del avatar (verde oliva oscuro).
                              backgroundImage:
                                  avatarImage, // La imagen a mostrar.
                              // Callback para manejar errores de carga de la imagen de red.
                              onBackgroundImageError:
                                  (Object exception, StackTrace? stackTrace) {
                                _screenLogger.severe(
                                    "Error al cargar la imagen de red: $exception",
                                    exception,
                                    stackTrace);
                                // No se devuelve nada aquí; el 'child' del CircleAvatar actuará como fallback.
                              },
                              // Si no hay imagen cargada (o hubo error), se muestra un ícono de persona.
                              child: avatarImage == null
                                  ? Icon(Icons.person,
                                      size: 80,
                                      color: AppColors.secondary1.withOpacity(
                                          0.7)) // Ícono de persona (verde oliva oscuro tenue).
                                  : null, // Si hay imagen, el child es nulo.
                            );
                          }),
                          // Pequeño contenedor para el ícono de la cámara.
                          Container(
                            padding: const EdgeInsets.all(
                                8), // Padding alrededor del ícono.
                            decoration: BoxDecoration(
                              color: AppColors
                                  .primary, // Color de fondo del ícono (verde lima brillante).
                              shape: BoxShape.circle, // Forma circular.
                              border: Border.all(
                                  color: AppColors.backgroundWhite,
                                  width: 3), // Borde blanco para destacarlo.
                            ),
                            child: const Icon(
                              Icons.camera_alt, // Ícono de cámara.
                              color: AppColors
                                  .textPrimary, // Color del ícono (gris oscuro, buen contraste).
                              size: 24, // Tamaño del ícono.
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                        height:
                            20), // Espacio vertical considerable después del avatar.

                    // Sección para mostrar el correo electrónico (no editable)
                    // Se usa un TextFormField con readOnly para mantener el formato visual.
                    TextFormField(
                      controller: _emailController,
                      readOnly: true, // Esto hace el campo no editable
                      style: TextStyle(
                        color: AppColors.textPrimary
                            .withOpacity(0.8), // Color del texto del correo
                        fontWeight: FontWeight.bold, // Para destacarlo
                      ),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        prefixIcon:
                            Icon(Icons.email, color: AppColors.secondary1),
                        fillColor: AppColors.backgroundLight,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          // Borde para estado no enfocado
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.3),
                              width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          // Borde para estado enfocado (aunque sea readOnly, el estilo se mantiene)
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.5),
                              width:
                                  1.0), // Menos prominente que los campos editables
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Espacio entre campos.

                    // Campo de Nombre de Usuario
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(
                          color: AppColors
                              .textPrimary), // Color del texto de entrada (gris oscuro).
                      decoration: InputDecoration(
                        labelText: 'Nombre de usuario', // Etiqueta del campo.
                        labelStyle: TextStyle(
                            color: AppColors
                                .textSecondary), // Estilo de la etiqueta (gris medio).
                        prefixIcon: Icon(Icons.person,
                            color: AppColors
                                .secondary1), // Ícono a la izquierda del campo (verde oliva oscuro).
                        fillColor: AppColors
                            .backgroundLight, // Color de fondo del campo de texto (gris claro más oscuro).
                        filled: true, // Habilita el color de fondo.
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              12.0), // Bordes redondeados.
                          borderSide: BorderSide.none, // Sin borde por defecto.
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.5),
                              width:
                                  1.0), // Borde cuando el campo no está enfocado (gris medio tenue).
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: AppColors.accent,
                              width:
                                  2.0), // Borde cuando el campo está enfocado (azul profundo).
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Espacio entre campos.

                    // Campo de Biografía
                    TextFormField(
                      controller: _bioController,
                      maxLines:
                          4, // Permite múltiples líneas para la biografía.
                      style: const TextStyle(
                          color: AppColors
                              .textPrimary), // Color del texto de entrada (gris oscuro).
                      decoration: InputDecoration(
                        labelText: 'Biografía', // Etiqueta del campo.
                        labelStyle: TextStyle(
                            color: AppColors
                                .textSecondary), // Estilo de la etiqueta (gris medio).
                        prefixIcon: Icon(Icons.description,
                            color: AppColors
                                .secondary1), // Ícono a la izquierda del campo (verde oliva oscuro).
                        fillColor: AppColors
                            .backgroundLight, // Color de fondo del campo de texto (gris claro más oscuro).
                        filled: true, // Habilita el color de fondo.
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              12.0), // Bordes redondeados.
                          borderSide: BorderSide.none, // Sin borde por defecto.
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.5),
                              width:
                                  1.0), // Borde cuando el campo no está enfocado (gris medio tenue).
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: AppColors.accent,
                              width:
                                  2.0), // Borde cuando el campo está enfocado (azul profundo).
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: 40), // Espacio al final del contenido.

                    // El botón de "Guardar Cambios" ahora está en la AppBar.
                  ],
                ),
              ),
      );
    });
  }
}
