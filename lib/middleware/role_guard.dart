import 'package:shelf/shelf.dart';
import 'auth_middleware.dart';
import '../utils/response_helper.dart';

/// Foydalanuvchi roli ruxsat etilgan rollar ro'yxatida borligini tekshiradi
Middleware roleGuard(List<String> allowedRoles) {
  return (Handler innerHandler) {
    return (Request request) async {
      final user = request.user;
      if (user == null) {
        return ResponseHelper.unauthorized('Foydalanuvchi aniqlanmadi');
      }

      final role = request.userRole;
      if (role == null || !allowedRoles.contains(role)) {
        return ResponseHelper.forbidden('Ushbu amalni bajarish uchun sizda yetarli huquq yo‘q');
      }

      return innerHandler(request);
    };
  };
}

/// Faqat Admin uchun guard
Middleware get adminOnlyGuard => roleGuard(['admin']);

/// Farmatsevt va Admin uchun guard
Middleware get pharmacistGuard => roleGuard(['pharmacist', 'admin']);
