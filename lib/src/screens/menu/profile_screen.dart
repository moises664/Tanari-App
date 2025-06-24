import 'dart:async'; // Importación necesaria para StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:tanari_app/src/controllers/services/auth_service.dart';
import 'package:tanari_app/src/controllers/services/user_profile_service.dart';
import 'package:tanari_app/src/core/app_colors.dart';
import 'package:tanari_app/src/routes/app_pages.dart';

/// Pantalla de perfil de usuario
///
/// Muestra y permite editar la información del perfil del usuario.
///
/// Mejoras de seguridad implementadas:
///   - Manejo adecuado del ciclo de vida de los controladores
///   - Cancelación explícita de suscripciones
///   - Verificación de estado 'mounted' antes de actualizar UI
///   - Protección contra actualizaciones en widgets eliminados
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileService _profileService = Get.find<UserProfileService>();
  final _formKey = GlobalKey<FormState>();

  // Controladores para campos editables
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  // Estados de la UI
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  // Suscripción para escuchar cambios en el perfil
  late StreamSubscription _profileSubscription;

  @override
  void initState() {
    super.initState();

    // Inicializar controladores
    _usernameController = TextEditingController();
    _bioController = TextEditingController();

    // Configurar listener para cambios en el perfil
    // IMPORTANTE: Guardar la suscripción para poder cancelarla después
    _profileSubscription = _profileService.currentProfile.listen((profile) {
      // Verificar que el widget aún esté montado antes de actualizar UI
      if (mounted && !_isEditing && profile != null) {
        _usernameController.text = profile.username;
        _bioController.text = profile.bio ?? '';
      }
    });
  }

  @override
  void dispose() {
    // PASO CRÍTICO: Cancelar la suscripción cuando el widget se elimina
    _profileSubscription.cancel();

    // Eliminar controladores para liberar recursos
    _usernameController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  /// Alterna entre modo de visualización y edición
  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        final profile = _profileService.currentProfile.value;
        if (profile != null) {
          _usernameController.text = profile.username;
          _bioController.text = profile.bio ?? '';
        }
      }
    });
  }

  /// Guarda los cambios realizados en el perfil
  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final userId = _profileService.currentProfile.value!.id;
        await _profileService.updateProfile(
          userId: userId,
          username: _usernameController.text,
          bio: _bioController.text,
        );
        _toggleEditing();
        Get.snackbar(
          'Éxito',
          'Perfil actualizado correctamente',
          backgroundColor: AppColors.success,
          colorText: AppColors.backgroundWhite,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'No se pudo actualizar el perfil: $e',
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite,
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Selecciona una imagen de la galería y la sube como avatar
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() => _isUploadingAvatar = true);
      try {
        final userId = _profileService.currentProfile.value!.id;
        await _profileService.uploadAvatar(
            userId: userId, imageFile: File(image.path));

        Get.snackbar(
          'Éxito',
          'Foto de perfil actualizada.',
          backgroundColor: AppColors.success,
          colorText: AppColors.backgroundWhite,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'No se pudo subir la foto: $e',
          backgroundColor: AppColors.error,
          colorText: AppColors.backgroundWhite,
        );
      } finally {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
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
          Obx(() {
            if (_profileService.currentProfile.value != null) {
              return IconButton(
                icon: Icon(
                  _isEditing ? Icons.close : Icons.edit,
                  color: AppColors.primary,
                ),
                onPressed: _toggleEditing,
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (_profileService.currentProfile.value == null) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final profile = _profileService.currentProfile.value!;

        return Stack(
          children: [
            // Fondo decorativo
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.9),
                      AppColors.secondary.withOpacity(0.7),
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

            // Contenido principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 80),

                    // Avatar
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 70,
                              backgroundColor: AppColors.backgroundWhite,
                              backgroundImage: profile.avatarUrl != null
                                  ? NetworkImage(profile.avatarUrl!)
                                  : null,
                              child: profile.avatarUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 70,
                                      color: AppColors.textSecondary,
                                    )
                                  : null,
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: _isUploadingAvatar
                                  ? CircularProgressIndicator(
                                      color: AppColors.accent)
                                  : GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppColors.backgroundWhite,
                                              width: 2),
                                        ),
                                        child: Icon(
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

                    // Información de usuario
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

                    // Tarjeta de información
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
                            if (profile.bio != null &&
                                profile.bio!.isNotEmpty) ...[
                              _buildProfileItem(
                                icon: Icons.info,
                                title: 'Biografía',
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

                    // Sección de edición
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
                                      return 'Por favor ingresa un nombre de usuario';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _bioController,
                                  decoration: InputDecoration(
                                    labelText: 'Biografía',
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

                    // Botones de acción
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
                        onPressed: () => Get.find<AuthService>().signOut(),
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

  /// Construye un elemento de información del perfil
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

  /// Construye un botón de acción grande
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

  /// Navega a la pantalla de cambio de contraseña
  void _changePassword() {
    Get.toNamed(Routes.changePassword, arguments: {'fromRecovery': false});
  }
}
