// USER PROFILE

/// Clase de modelo [UserProfile] que representa la estructura de un perfil de usuario
/// almacenado en la tabla `public.profiles` de Supabase.
///
/// Incluye campos como ID, nombre de usuario, correo electrónico, estado de administrador,
/// fecha de creación, fecha de última actualización, URL del avatar y biografía.
class UserProfile {
  final String id;
  final String username;
  final String email;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime?
      updatedAt; // Nuevo campo: fecha de última actualización (opcional)
  final String? avatarUrl;
  final String? bio;

  /// Constructor para crear una instancia de [UserProfile].
  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
    required this.createdAt,
    this.updatedAt, // El campo updatedAt es opcional
    this.avatarUrl,
    this.bio,
  });

  /// Factory constructor para crear una instancia de [UserProfile] desde un mapa (JSON).
  ///
  /// Realiza el mapeo de los nombres de las columnas de la base de datos a los nombres
  /// de las propiedades del modelo.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      isAdmin:
          map['is_admin'] as bool? ?? false, // Valor por defecto si es nulo
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null // Mapear updatedAt si existe
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
    );
  }

  /// Convierte la instancia actual de [UserProfile] en un mapa (JSON) para su almacenamiento
  /// en la base de datos.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String(), // Incluir updatedAt en el mapa
      'avatar_url': avatarUrl,
      'bio': bio,
    };
  }

  /// Crea una nueva instancia de [UserProfile] copiando los valores de la instancia actual,
  /// permitiendo sobrescribir propiedades específicas.
  UserProfile copyWith({
    String? username,
    String? email,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt, // Permitir copiar updatedAt
    String? avatarUrl,
    String? bio,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt, // Copiar updatedAt
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
    );
  }
}
