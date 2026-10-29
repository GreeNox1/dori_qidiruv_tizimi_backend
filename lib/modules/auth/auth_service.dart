import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../../config/database.dart';
import '../../config/env_config.dart';
import '../../utils/password_hasher.dart';

class AuthService {
  String generateToken({
    required int userId,
    required String email,
    required String role,
    int? branchId,
  }) {
    final jwt = JWT({
      'sub': userId,
      'email': email,
      'role': role,
      'branch_id': branchId,
    });

    return jwt.sign(
      SecretKey(EnvConfig.jwtSecret),
      expiresIn: Duration(hours: EnvConfig.jwtExpirationHours),
    );
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    const sql = '''
      SELECT u.id, u.full_name, u.email, u.password_hash, u.phone, 
             u.is_blocked, r.name AS role, bs.branch_id
      FROM users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN branch_staff bs ON u.id = bs.user_id
      WHERE LOWER(u.email) = LOWER(@email)
      LIMIT 1;
    ''';

    return await Database.queryOne(sql, parameters: {'email': email.trim()});
  }

  Future<Map<String, dynamic>?> findUserById(int id) async {
    const sql = '''
      SELECT u.id, u.full_name, u.email, u.phone, u.is_blocked, 
             r.name AS role, bs.branch_id, u.created_at
      FROM users u
      JOIN roles r ON u.role_id = r.id
      LEFT JOIN branch_staff bs ON u.id = bs.user_id
      WHERE u.id = @id
      LIMIT 1;
    ''';

    final user = await Database.queryOne(sql, parameters: {'id': id});
    if (user != null) {
      user.remove('password_hash');
    }
    return user;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final user = await findUserByEmail(email);
    if (user == null) {
      throw const AuthException('Email yoki parol noto‘g‘ri', 401);
    }

    final passwordHash = user['password_hash'] as String;
    if (!PasswordHasher.verify(password, passwordHash)) {
      throw const AuthException('Email yoki parol noto‘g‘ri', 401);
    }

    if (user['is_blocked'] == true) {
      throw const AuthException('Foydalanuvchi hisobi bloklangan. Administratorga murojaat qiling', 403);
    }

    final userId = user['id'] as int;
    final userRole = user['role'] as String;
    final branchId = user['branch_id'] as int?;

    final token = generateToken(
      userId: userId,
      email: user['email'] as String,
      role: userRole,
      branchId: branchId,
    );

    user.remove('password_hash');

    return {
      'token': token,
      'user': user,
    };
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final existing = await findUserByEmail(cleanEmail);
    if (existing != null) {
      throw const AuthException('Ushbu email allaqachon ro‘yxatdan o‘tgan', 409);
    }

    // Role 'user' id
    final roleRow = await Database.queryOne("SELECT id FROM roles WHERE name = 'user' LIMIT 1;");
    final roleId = roleRow?['id'] as int? ?? 3;

    final hashedPassword = PasswordHasher.hash(password);

    const insertSql = '''
      INSERT INTO users (full_name, email, password_hash, phone, role_id)
      VALUES (@full_name, @email, @password_hash, @phone, @role_id)
      RETURNING id, full_name, email, phone, role_id, created_at;
    ''';

    final inserted = await Database.queryOne(insertSql, parameters: {
      'full_name': fullName.trim(),
      'email': cleanEmail,
      'password_hash': hashedPassword,
      'phone': phone?.trim(),
      'role_id': roleId,
    });

    if (inserted == null) {
      throw const AuthException('Foydalanuvchini yaratib bo‘lmadi', 500);
    }

    final userId = inserted['id'] as int;
    final token = generateToken(
      userId: userId,
      email: cleanEmail,
      role: 'user',
      branchId: null,
    );

    return {
      'token': token,
      'user': {
        'id': userId,
        'full_name': inserted['full_name'],
        'email': inserted['email'],
        'phone': inserted['phone'],
        'role': 'user',
        'branch_id': null,
      },
    };
  }
}

class AuthException implements Exception {
  final String message;
  final int statusCode;
  const AuthException(this.message, [this.statusCode = 400]);

  @override
  String toString() => message;
}
