// user_profile.dart

/// Modelo de datos para el perfil de usuario.
/// Representa la estructura de la tabla 'profiles' en Supabase.
class UserProfile {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isAdmin; // Nueva columna para el rol de administrador

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
    this.updatedAt,
    this.isAdmin = false, // Valor por defecto
  });

  /// Crea una instancia de [UserProfile] desde un mapa JSON.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isAdmin: json['is_admin'] as bool? ??
          false, // Asegura que sea un booleano, con default false
    );
  }

  /// Convierte la instancia actual de [UserProfile] en un mapa (JSON) para su almacenamiento
  /// en la base de datos.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_admin': isAdmin,
    };
  }

  /// Crea una nueva instancia de [UserProfile] copiando los valores de la instancia actual,
  /// permitiendo sobrescribir propiedades específicas.
  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdmin,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
