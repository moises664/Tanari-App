// PROFILE SCREEN

import 'dart:async'; // Para manejo de suscripciones
import 'dart:io'; // Para acceso a archivos
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart'; // Para selección de imágenes
import 'package:intl/intl.dart'; // Para formateo de fechas
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart';

/// Pantalla de perfil de usuario - Muestra y permite editar la información del usuario.
///
/// Características principales:
/// - Visualización de información del perfil (nombre de usuario, email, tipo de cuenta, fecha de registro, biografía).
/// - Edición de nombre de usuario y biografía.
/// - Cambio de foto de perfil (subida a Supabase Storage).
/// - Opciones para cambiar contraseña y cerrar sesión.
///
/// Mejoras de seguridad y rendimiento implementadas:
/// - Manejo adecuado del ciclo de vida de los controladores de texto.
/// - Cancelación explícita de suscripciones para evitar fugas de memoria.
/// - Verificación de estado `mounted` antes de actualizar la UI después de operaciones asíncronas.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Instancias de servicios obtenidas a través de GetX.
  final UserProfileService _profileService = Get.find<UserProfileService>();
  final AuthService _authService = Get.find<AuthService>();

  final _formKey =
      GlobalKey<FormState>(); // Clave para el formulario de edición.

  // Controladores para los campos de texto editables del perfil.
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  // Estados de la UI para controlar la interactividad y los indicadores de carga.
  bool _isEditing = false; // Controla si la pantalla está en modo edición.
  bool _isLoading = false; // Indicador de carga para operaciones de guardado.
  bool _isUploadingAvatar = false; // Indicador de carga para subida de avatar.

  // Suscripción para escuchar cambios en el perfil del usuario.
  late StreamSubscription _profileSubscription;

  @override
  void initState() {
    super.initState();

    // Inicializar controladores con valores vacíos. Se actualizarán con los datos del perfil
    // una vez que el listener de `currentProfile` se active.
    _usernameController = TextEditingController();
    _bioController = TextEditingController();

    // Configurar un listener para reaccionar a los cambios en el perfil del usuario.
    // Esto asegura que la UI se actualice automáticamente si el perfil cambia
    // (ej. por una actualización desde otra parte de la app o el servidor).
    _profileSubscription = _profileService.currentProfile.listen((profile) {
      // Actualizar la UI solo si el widget está montado y no estamos en medio de una edición
      // (para evitar sobrescribir los campos mientras el usuario está escribiendo).
      if (mounted && !_isEditing && profile != null) {
        _usernameController.text = profile.username;
        _bioController.text = profile.bio ?? '';
      }
    });
  }

  @override
  void dispose() {
    // CRÍTICO: Cancelar la suscripción para evitar fugas de memoria.
    _profileSubscription.cancel();

    // Liberar los recursos de los controladores de texto.
    _usernameController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  /// Alterna entre el modo de visualización y el modo de edición del perfil.
  /// Cuando se entra en modo edición, los campos de texto se precargan con los datos actuales.
  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      // Al entrar en modo edición, cargar los datos actuales del perfil en los controladores.
      if (_isEditing) {
        final profile = _profileService.currentProfile.value;
        if (profile != null) {
          _usernameController.text = profile.username;
          _bioController.text = profile.bio ?? '';
        }
      }
    });
  }

  /// Guarda los cambios realizados en el perfil del usuario.
  ///
  /// Valida el formulario y llama a `updateProfile` de [UserProfileService].
  Future<void> _saveChanges() async {
    // Validar el formulario antes de intentar guardar los cambios.
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // Activar indicador de carga.
      try {
        // Ahora updateProfile espera un mapa con los campos a actualizar
        await _profileService.updateProfile({
          'username': _usernameController.text.trim(),
          'bio': _bioController.text.trim(),
        });
        _toggleEditing(); // Salir del modo edición después de guardar.
        // El snackbar de éxito se muestra desde UserProfileService.
      } catch (e) {
        // El snackbar de error se muestra desde UserProfileService.
        _profileService.currentProfile
            .refresh(); // Forzar refresco si hubo error.
      } finally {
        if (mounted) {
          setState(() => _isLoading = false); // Desactivar indicador de carga.
        }
      }
    }
  }

  /// Permite al usuario seleccionar una imagen de la galería y la sube como avatar.
  ///
  /// Utiliza `image_picker` para la selección y `UserProfileService` para la subida.
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() =>
          _isUploadingAvatar = true); // Activar indicador de carga de avatar.
      try {
        // Ahora uploadAvatar espera solo el File
        await _profileService.uploadAvatar(File(image.path));
        // El snackbar de éxito se muestra desde UserProfileService.
      } catch (e) {
        // El snackbar de error se muestra desde UserProfileService.
      } finally {
        if (mounted) {
          setState(() => _isUploadingAvatar = false); // Desactivar indicador.
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          // Botón de editar/cerrar en la AppBar, visible solo si hay un perfil cargado.
          Obx(() {
            if (_profileService.currentProfile.value != null) {
              return IconButton(
                icon: Icon(
                  _isEditing
                      ? Icons.close
                      : Icons.edit, // Icono cambia según el modo.
                  color: AppColors.primary,
                ),
                onPressed: _toggleEditing, // Alternar modo edición.
              );
            }
            return const SizedBox.shrink(); // No mostrar nada si no hay perfil.
          }),
        ],
      ),
      body: Obx(() {
        // Mostrar un indicador de carga mientras el perfil se está obteniendo.
        if (_profileService.currentProfile.value == null) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final profile =
            _profileService.currentProfile.value!; // Obtener el perfil actual.

        return Stack(
          children: [
            // Fondo decorativo en la parte superior de la pantalla.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withAlpha(230),
                      AppColors.secondary.withAlpha(179),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
              ),
            ),

            // Contenido principal del perfil, envuelto en un SingleChildScrollView
            // para permitir el desplazamiento si el contenido es demasiado largo.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 80), // Espacio para el avatar.

                    // Área del avatar con botón de cámara en modo edición.
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          // Contenedor para el avatar con sombra.
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(102),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            // Avatar circular del usuario.
                            child: CircleAvatar(
                              radius: 70,
                              backgroundColor: AppColors.backgroundWhite,
                              backgroundImage: profile.avatarUrl != null
                                  ? NetworkImage(_profileService
                                      .getAvatarUrl(profile.avatarUrl))
                                  : null,
                              child: profile.avatarUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 70,
                                      color: AppColors.textSecondary,
                                    )
                                  : null,
                            ),
                          ),
                          // Botón de cámara (solo visible en modo edición).
                          if (_isEditing)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: _isUploadingAvatar
                                  ? CircularProgressIndicator(
                                      color: AppColors
                                          .accent) // Indicador de carga.
                                  : GestureDetector(
                                      onTap:
                                          _pickImage, // Abrir selector de imagen.
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppColors.backgroundWhite,
                                              width: 2),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: AppColors.backgroundWhite,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Información básica del usuario (nombre y email).
                    Text(
                      profile.username,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile.email,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Tarjeta de información con detalles adicionales del perfil.
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: AppColors.backgroundWhite,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildProfileItem(
                              icon: Icons.badge,
                              title: 'Tipo de cuenta',
                              value:
                                  profile.isAdmin ? 'Administrador' : 'Usuario',
                              iconColor: AppColors.secondary1,
                            ),
                            const Divider(
                                color: AppColors.neutralLight, height: 10),
                            _buildProfileItem(
                              icon: Icons.calendar_today,
                              title: 'Registrado',
                              value: DateFormat('dd/MM/yyyy')
                                  .format(profile.createdAt),
                              iconColor: AppColors.info,
                            ),
                            const Divider(
                                color: AppColors.neutralLight, height: 10),
                            // Mostrar fecha de actualización si existe.
                            if (profile.updatedAt != null) ...[
                              _buildProfileItem(
                                icon: Icons.update,
                                title: 'Última actualización',
                                value: DateFormat('dd/MM/yyyy HH:mm')
                                    .format(profile.updatedAt!),
                                iconColor: AppColors.success,
                              ),
                              const Divider(
                                  color: AppColors.neutralLight, height: 10),
                            ],
                            if (profile.bio != null &&
                                profile.bio!.isNotEmpty) ...[
                              _buildProfileItem(
                                icon: Icons.info,
                                title: 'Información adicional',
                                value: profile.bio!,
                                iconColor: AppColors.primary,
                              ),
                              const Divider(
                                  color: AppColors.neutralLight, height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sección de edición (solo visible en modo edición).
                    if (_isEditing) ...[
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Campo de texto para el nombre de usuario.
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nombre de usuario',
                                    labelStyle: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: AppColors.neutralLight,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, ingresa un nombre de usuario.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Campo de texto para la biografía.
                                TextFormField(
                                  controller: _bioController,
                                  decoration: InputDecoration(
                                    labelText: 'Información adicional',
                                    labelStyle: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.info,
                                      color: AppColors.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: AppColors.neutralLight,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  maxLines: 3,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Botón para guardar los cambios.
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _saveChanges,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 3,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Guardar Cambios',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.backgroundWhite,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Botones de acción (solo visibles fuera del modo edición).
                    if (!_isEditing) ...[
                      _buildActionButton(
                        icon: Icons.camera_alt,
                        text: 'Cambiar Foto de Perfil',
                        color: AppColors.accent,
                        onPressed: _pickImage,
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        icon: Icons.lock,
                        text: 'Cambiar Contraseña',
                        color: AppColors.secondary1,
                        onPressed: _changePassword,
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        icon: Icons.logout,
                        text: 'Cerrar Sesión',
                        color: AppColors.error,
                        onPressed: () => _authService
                            .signOut(), // Llama a signOut de AuthService.
                      ),
                      const SizedBox(height: 20),
                    ]
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Construye un elemento de información del perfil con un icono, título y valor.
  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor ?? AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un botón de acción grande con un icono, texto y color.
  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: AppColors.backgroundWhite),
        label: Text(
          text,
          style: const TextStyle(
            color: AppColors.backgroundWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  /// Navega a la pantalla de cambio de contraseña.
  void _changePassword() {
    Get.toNamed(Routes.changePassword, arguments: {'fromRecovery': false});
  }
}
