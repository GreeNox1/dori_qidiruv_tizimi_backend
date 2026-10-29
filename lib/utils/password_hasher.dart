import 'package:bcrypt/bcrypt.dart';

class PasswordHasher {
  static String hash(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  static bool verify(String password, String hashed) {
    try {
      return BCrypt.checkpw(password, hashed);
    } catch (_) {
      return false;
    }
  }
}
