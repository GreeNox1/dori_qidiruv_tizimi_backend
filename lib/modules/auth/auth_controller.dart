import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../middleware/auth_middleware.dart';
import '../../utils/response_helper.dart';
import 'auth_service.dart';

class AuthController {
  final AuthService _authService = AuthService();

  Router get router {
    final router = Router();

    router.post('/login', _login);
    router.post('/register', _register);

    // Protected route
    final protectedRouter = Router();
    protectedRouter.get('/me', _me);

    final protectedHandler = const Pipeline()
        .addMiddleware(requireAuthMiddleware)
        .addHandler(protectedRouter.call);

    router.mount('/', protectedHandler);

    return router;
  }

  Future<Response> _login(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi (body) bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      final email = body['email']?.toString().trim() ?? '';
      final password = body['password']?.toString() ?? '';

      if (email.isEmpty || password.isEmpty) {
        return ResponseHelper.badRequest('Email va parol kiritilishi shart');
      }

      final result = await _authService.login(email, password);
      return ResponseHelper.success(
        data: result,
        message: 'Tizimga muvaffaqiyatli kirildi',
      );
    } on AuthException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Tizimga kirishda xatolik: $e');
    }
  }

  Future<Response> _register(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      final fullName = body['full_name']?.toString().trim() ?? '';
      final email = body['email']?.toString().trim() ?? '';
      final password = body['password']?.toString() ?? '';
      final phone = body['phone']?.toString().trim();

      if (fullName.isEmpty) {
        return ResponseHelper.badRequest('To‘liq ism (full_name) kiritilishi shart');
      }
      if (email.isEmpty || !email.contains('@')) {
        return ResponseHelper.badRequest('Yaroqli email manzilini kiriting');
      }
      if (password.length < 6) {
        return ResponseHelper.badRequest('Parol kamida 6 ta belgidan iborat bo‘lishi kerak');
      }

      final result = await _authService.register(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
      );

      return ResponseHelper.success(
        data: result,
        message: 'Ro‘yxatdan muvaffaqiyatli o‘tildi',
        statusCode: 201,
      );
    } on AuthException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Ro‘yxatdan o‘tishda xatolik: $e');
    }
  }

  Future<Response> _me(Request request) async {
    try {
      final userId = request.userId;
      if (userId == null) {
        return ResponseHelper.unauthorized();
      }

      final user = await _authService.findUserById(userId);
      if (user == null) {
        return ResponseHelper.notFound('Foydalanuvchi topilmadi');
      }

      return ResponseHelper.success(data: user);
    } catch (e) {
      return ResponseHelper.internalServerError('Profilni olishda xatolik: $e');
    }
  }
}
