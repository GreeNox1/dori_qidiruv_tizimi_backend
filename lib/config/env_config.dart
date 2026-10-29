import 'dart:io';
import 'package:dotenv/dotenv.dart';

class EnvConfig {
  static late final DotEnv _env;

  static void init() {
    _env = DotEnv(includePlatformEnvironment: true)..load();
  }

  static int get port =>
      int.tryParse(_env['PORT'] ?? Platform.environment['PORT'] ?? '8080') ?? 8080;

  static String get dbHost =>
      _env['DB_HOST'] ?? Platform.environment['DB_HOST'] ?? 'localhost';

  static int get dbPort =>
      int.tryParse(_env['DB_PORT'] ?? Platform.environment['DB_PORT'] ?? '5432') ?? 5432;

  static String get dbName =>
      _env['DB_NAME'] ?? Platform.environment['DB_NAME'] ?? 'pharmasearch_db';

  static String get dbUser =>
      _env['DB_USER'] ?? Platform.environment['DB_USER'] ?? 'pharma_user';

  static String get dbPassword =>
      _env['DB_PASSWORD'] ?? Platform.environment['DB_PASSWORD'] ?? 'pharma_password123';

  static String get jwtSecret =>
      _env['JWT_SECRET'] ?? Platform.environment['JWT_SECRET'] ?? 'super_secret_pharma_jwt_key_2026_xyz';

  static int get jwtExpirationHours =>
      int.tryParse(_env['JWT_EXPIRATION_HOURS'] ?? Platform.environment['JWT_EXPIRATION_HOURS'] ?? '24') ?? 24;
}
