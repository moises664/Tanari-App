class UserProfile {
  final String id;
  final String username;
  final String email;
  final bool isAdmin;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? bio; // Nuevo campo de biografía

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
    required this.createdAt,
    this.avatarUrl,
    this.bio,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      isAdmin: map['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?, // Mapeo del campo bio
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      'avatar_url': avatarUrl,
      'bio': bio, // Incluido en el mapa
    };
  }

  // Método para copiar el perfil con nuevos valores
  UserProfile copyWith({
    String? username,
    String? email,
    bool? isAdmin,
    DateTime? createdAt,
    String? avatarUrl,
    String? bio,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
    );
  }
}
