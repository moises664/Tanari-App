// lib/src/models/user_profile.dart
class UserProfile {
  final String id;
  final String username;
  final String
      email; // Asume que el email también se guarda en la tabla de perfiles o se puede obtener del usuario autenticado
  final String? avatarUrl;
  final DateTime? createdAt;
  // Agrega cualquier otro campo que tengas en tu tabla 'profiles' en Supabase
  // Por ejemplo:
  // final String? fullName;
  // final String? bio;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.createdAt,
    // this.fullName,
    // this.bio,
  });

  // Factory constructor para crear una instancia de UserProfile desde un Map (por ejemplo, de Supabase)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email']
          as String, // Asegúrate de que este campo exista en tu tabla 'profiles'
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      // fullName: json['full_name'] as String?,
      // bio: json['bio'] as String?,
    );
  }

  // Método para convertir la instancia de UserProfile a un Map (útil para enviar a Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
      // 'full_name': fullName,
      // 'bio': bio,
    };
  }
}
