import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../middleware/auth_middleware.dart';
import '../../utils/response_helper.dart';
import 'drugs_service.dart';

class DrugsController {
  final DrugsService _drugsService = DrugsService();

  Router get router {
    final router = Router();

    router.get('/search', _search);
    router.get('/<id|[0-9]+>', _getById);
    router.get('/<id|[0-9]+>/prices', _getPrices);
    router.get('/<id|[0-9]+>/analogs', _getAnalogs);

    return router;
  }

  Future<Response> _search(Request request) async {
    try {
      final params = request.url.queryParameters;
      final q = params['q'];
      final district = params['district'];
      final inStock = params['in_stock']?.toLowerCase() == 'true';
      final sortPrice = params['sort_price'] ?? 'asc';
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '10') ?? 10;

      final result = await _drugsService.searchDrugs(
        query: q,
        district: district,
        inStockOnly: inStock,
        sortPrice: sortPrice,
        page: page,
        limit: limit,
        currentUserId: request.userId,
      );

      return ResponseHelper.success(
        data: result['items'],
        pagination: result['pagination'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return ResponseHelper.internalServerError('Dori qidirishda xatolik: $e');
    }
  }

  Future<Response> _getById(Request request, String id) async {
    try {
      final drugId = int.tryParse(id);
      if (drugId == null) {
        return ResponseHelper.badRequest('Yaroqsiz dori identifikatori');
      }

      final drug = await _drugsService.getDrugById(
        drugId,
        currentUserId: request.userId,
      );

      if (drug == null) {
        return ResponseHelper.notFound('Dori vositasi topilmadi');
      }

      return ResponseHelper.success(data: drug);
    } catch (e) {
      return ResponseHelper.internalServerError('Dori ma’lumotini olishda xatolik: $e');
    }
  }

  Future<Response> _getPrices(Request request, String id) async {
    try {
      final drugId = int.tryParse(id);
      if (drugId == null) {
        return ResponseHelper.badRequest('Yaroqsiz dori identifikatori');
      }

      final params = request.url.queryParameters;
      final district = params['district'];
      final sort = params['sort'] ?? 'asc';

      final prices = await _drugsService.getDrugPrices(
        drugId,
        district: district,
        sort: sort,
      );

      return ResponseHelper.success(data: prices);
    } catch (e) {
      return ResponseHelper.internalServerError('Narxlar jadvalini olishda xatolik: $e');
    }
  }

  Future<Response> _getAnalogs(Request request, String id) async {
    try {
      final drugId = int.tryParse(id);
      if (drugId == null) {
        return ResponseHelper.badRequest('Yaroqsiz dori identifikatori');
      }

      final analogs = await _drugsService.getDrugAnalogs(drugId);
      return ResponseHelper.success(data: analogs);
    } catch (e) {
      return ResponseHelper.internalServerError('Dori analoglarini olishda xatolik: $e');
    }
  }
}
