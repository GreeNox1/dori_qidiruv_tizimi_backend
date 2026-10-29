import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../middleware/auth_middleware.dart';
import '../../utils/response_helper.dart';
import 'favorites_service.dart';

class FavoritesController {
  final FavoritesService _favoritesService = FavoritesService();

  Router get router {
    final router = Router();

    final protectedRouter = Router();
    protectedRouter.get('/', _getFavorites);
    protectedRouter.post('/toggle', _toggleFavorite);

    final protectedHandler = const Pipeline()
        .addMiddleware(requireAuthMiddleware)
        .addHandler(protectedRouter.call);

    router.mount('/', protectedHandler);

    return router;
  }

  Future<Response> _getFavorites(Request request) async {
    try {
      final userId = request.userId;
      if (userId == null) {
        return ResponseHelper.unauthorized();
      }

      final favorites = await _favoritesService.getFavorites(userId);
      return ResponseHelper.success(data: favorites);
    } catch (e) {
      return ResponseHelper.internalServerError('Sevimlilar ro‘yxatini olishda xatolik: $e');
    }
  }

  Future<Response> _toggleFavorite(Request request) async {
    try {
      final userId = request.userId;
      if (userId == null) {
        return ResponseHelper.unauthorized();
      }

      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic> || body['drug_id'] == null) {
        return ResponseHelper.badRequest('drug_id kiritilishi shart');
      }

      final drugId = int.tryParse(body['drug_id'].toString());
      if (drugId == null) {
        return ResponseHelper.badRequest('Yaroqsiz drug_id');
      }

      final result = await _favoritesService.toggleFavorite(userId, drugId);
      return ResponseHelper.success(
        message: result['message'] as String,
        extra: {'is_saved': result['is_saved']},
      );
    } on FavoritesException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Sevimliga o‘zgartirishda xatolik: $e');
    }
  }
}
