import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Clase helper para manejar operaciones de base de datos SQLite
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._private();
  static Database? _database;

  // Constructor privado
  DatabaseHelper._private();

  /// Obtiene la instancia de la base de datos (inicializa si es necesario)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'tanari_database.db');
    return await openDatabase(
      path,
      version: 2, // Incrementar versión al modificar esquema
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea la estructura inicial de la base de datos
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
      )
    ''');
  }

  /// Maneja actualizaciones de esquema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Si la versión anterior es menor a 2 y la nueva es 2 o más, crea la tabla si no existe.
    // Esto es útil si un usuario instala una versión antigua y luego actualiza.
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL
        )
      ''');
    }
    // Puedes añadir más bloques 'if (oldVersion < X)' para futuras migraciones.
  }

  /// Inserta un nuevo usuario en la base de datos
  /// [name]: Nombre completo del usuario
  /// [email]: Email único del usuario
  /// [password]: Contraseña del usuario
  Future<int> insertUser(String name, String email, String password) async {
    final db = await instance.database;
    return await db.insert(
      'users',
      {'name': name, 'email': email, 'password': password},
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Obtiene un usuario por su email
  /// [email]: Email del usuario a buscar
  Future<Map<String, dynamic>?> getUser(String email) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Elimina un usuario por su email
  /// [email]: Email del usuario a eliminar
  Future<int> deleteUser(String email) async {
    final db = await instance.database;
    return await db.delete(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  /// Actualiza la contraseña de un usuario
  /// [email]: Email del usuario
  /// [newPassword]: Nueva contraseña
  Future<int> updatePassword(String email, String newPassword) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  /// Obtiene todos los usuarios (solo para debug)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await instance.database;
    return await db.query('users');
  }

  /// Elimina toda la tabla de usuarios (solo para desarrollo)
  Future<void> deleteAllUsers() async {
    final db = await instance.database;
    await db.delete('users');
  }
}
