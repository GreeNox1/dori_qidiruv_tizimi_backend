import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import '../config/env_config.dart';
import '../utils/response_helper.dart';

extension RequestAuthExt on Request {
  Map<String, dynamic>? get user => context['user'] as Map<String, dynamic>?;
  int? get userId => user?['sub'] as int? ?? int.tryParse(user?['sub']?.toString() ?? '');
  String? get userRole => user?['role']?.toString();
  int? get userBranchId => user?['branch_id'] as int? ?? int.tryParse(user?['branch_id']?.toString() ?? '');
}

/// Tokenni o'qiydi va agar mavjud hamda to'g'ri bo'lsa, request.context['user'] ga biriktiradi.
/// Token bo'lmasa, so'rov davom etadi (Guest sifatida).
Middleware get parseUserMiddleware => (Handler innerHandler) {
      return (Request request) async {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return innerHandler(request);
        }

        final token = authHeader.substring(7).trim();
        try {
          final jwt = JWT.verify(token, SecretKey(EnvConfig.jwtSecret));
          final payload = Map<String, dynamic>.from(jwt.payload as Map);
          final updatedRequest = request.change(context: {'user': payload});
          return await innerHandler(updatedRequest);
        } catch (_) {
          return innerHandler(request);
        }
      };
    };

/// Tizimga kirganlikni (autentifikatsiyani) majburiy talab qiluvchi middleware
Middleware get requireAuthMiddleware => (Handler innerHandler) {
      return (Request request) async {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return ResponseHelper.unauthorized('Token taqdim etilmagan');
        }

        final token = authHeader.substring(7).trim();
        try {
          final jwt = JWT.verify(token, SecretKey(EnvConfig.jwtSecret));
          final payload = Map<String, dynamic>.from(jwt.payload as Map);
          final updatedRequest = request.change(context: {'user': payload});
          return await innerHandler(updatedRequest);
        } on JWTExpiredException {
          return ResponseHelper.unauthorized('Token muddati tugagan');
        } catch (e) {
          return ResponseHelper.unauthorized('Yaroqsiz token');
        }
      };
    };
