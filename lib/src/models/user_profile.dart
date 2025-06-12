// lib/src/models/user_profile.dart
class UserProfile {
  final String id;
  final String? username;
  final String? email;
  final DateTime? createdAt;
  final String? bio;
  final String? avatarUrl; // ¡Asegúrate de tener esta propiedad!

  UserProfile({
    required this.id,
    this.username,
    this.email,
    this.createdAt,
    this.bio,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?, // Asegúrate de mapear esto
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
      'bio': bio,
      'avatar_url': avatarUrl, // Asegúrate de incluir esto al toJson si lo usas
    };
  }

  // Método copyWith para facilitar la creación de nuevas instancias con cambios
  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    DateTime? createdAt,
    String? bio,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
