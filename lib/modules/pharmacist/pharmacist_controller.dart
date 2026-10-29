import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../middleware/auth_middleware.dart';
import '../../middleware/role_guard.dart';
import '../../utils/response_helper.dart';
import 'pharmacist_service.dart';

class PharmacistController {
  final PharmacistService _service = PharmacistService();

  Router get router {
    final router = Router();

    final protectedRouter = Router();
    protectedRouter.get('/branch', _getBranch);
    protectedRouter.put('/branch', _updateBranch);
    protectedRouter.get('/inventory', _getInventory);
    protectedRouter.post('/inventory', _addInventory);
    protectedRouter.put('/inventory/<id|[0-9]+>', _updateInventory);
    protectedRouter.delete('/inventory/<id|[0-9]+>', _deleteInventory);

    final handler = const Pipeline()
        .addMiddleware(requireAuthMiddleware)
        .addMiddleware(pharmacistGuard)
        .addHandler(protectedRouter.call);

    router.mount('/', handler);

    return router;
  }

  Future<Response> _getBranch(Request request) async {
    try {
      final userId = request.userId;
      if (userId == null) return ResponseHelper.unauthorized();

      final branch = await _service.getBranchInfo(userId);
      return ResponseHelper.success(data: branch);
    } on PharmacistException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Filial ma’lumotini olishda xatolik: $e');
    }
  }

  Future<Response> _updateBranch(Request request) async {
    try {
      final userId = request.userId;
      if (userId == null) return ResponseHelper.unauthorized();

      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      final updated = await _service.updateBranchInfo(
        userId: userId,
        address: body['address']?.toString(),
        landmark: body['landmark']?.toString(),
        phone: body['phone']?.toString(),
        workingHours: body['working_hours']?.toString(),
      );

      return ResponseHelper.success(
        data: updated,
        message: 'Filial ma’lumotlari muvaffaqiyatli yangilandi',
      );
    } on PharmacistException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Filial ma’lumotlarini yangilashda xatolik: $e');
    }
  }

  Future<Response> _getInventory(Request request) async {
    try {
      final userId = request.userId;
      if (userId == null) return ResponseHelper.unauthorized();

      final params = request.url.queryParameters;
      final q = params['q'];
      final status = params['status'] ?? 'all';

      final inventory = await _service.getInventory(
        userId: userId,
        query: q,
        status: status,
      );

      return ResponseHelper.success(data: inventory);
    } on PharmacistException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Ombor qoldiqlarini olishda xatolik: $e');
    }
  }

  Future<Response> _addInventory(Request request) async {
    try {
      final userId = request.userId;
      if (userId == null) return ResponseHelper.unauthorized();

      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      final drugId = int.tryParse(body['drug_id']?.toString() ?? '');
      final price = double.tryParse(body['price']?.toString() ?? '');
      final quantity = int.tryParse(body['quantity']?.toString() ?? '0') ?? 0;

      if (drugId == null) {
        return ResponseHelper.badRequest('drug_id kiritilishi shart');
      }
      if (price == null || price <= 0) {
        return ResponseHelper.badRequest('Yaroqli narx (price > 0) kiritilishi shart');
      }
      if (quantity < 0) {
        return ResponseHelper.badRequest('Miqdor manfiy bo‘lishi mumkin emas');
      }

      final item = await _service.addInventoryItem(
        userId: userId,
        drugId: drugId,
        price: price,
        quantity: quantity,
      );

      return ResponseHelper.success(
        data: item,
        message: 'Dori omborga muvaffaqiyatli qo‘shildi',
        statusCode: 201,
      );
    } on PharmacistException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Dorini omborga qo‘shishda xatolik: $e');
    }
  }

  Future<Response> _updateInventory(Request request, String id) async {
    try {
      final userId = request.userId;
      if (userId == null) return ResponseHelper.unauthorized();

      final inventoryId = int.tryParse(id);
      if (inventoryId == null) {
        return ResponseHelper.badRequest('Yaroqsiz inventar identifikatori');
      }

      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      double? price;
      if (body.containsKey('price')) {
        price = double.tryParse(body['price']?.toString() ?? '');
        if (price == null || price <= 0) {
          return ResponseHelper.badRequest('Yaroqli narx kiritilishi lozim');
        }
      }

      int? quantity;
      if (body.containsKey('quantity')) {
        quantity = int.tryParse(body['quantity']?.toString() ?? '');
        if (quantity == null || quantity < 0) {
          return ResponseHelper.badRequest('Miqdor manfiy bo‘lishi mumkin emas');
        }
      }

      bool? isAvailable;
      if (body.containsKey('is_available')) {
        isAvailable = body['is_available'] == true;
      }

      final updated = await _service.updateInventoryItem(
        userId: userId,
        inventoryId: inventoryId,
        price: price,
        quantity: quantity,
        isAvailable: isAvailable,
      );

      return ResponseHelper.success(
        data: updated,
        message: 'Inventar ma’lumotlari muvaffaqiyatli yangilandi',
      );
    } on PharmacistException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Inventarni yangilashda xatolik: $e');
    }
  }

  Future<Response> _deleteInventory(Request request, String id) async {
    try {
      final userId = request.userId;
      if (userId == null) return ResponseHelper.unauthorized();

      final inventoryId = int.tryParse(id);
      if (inventoryId == null) {
        return ResponseHelper.badRequest('Yaroqsiz inventar identifikatori');
      }

      await _service.deleteInventoryItem(
        userId: userId,
        inventoryId: inventoryId,
      );

      return ResponseHelper.success(message: 'Dori filial omboridan chiqarildi');
    } on PharmacistException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Inventardan o‘chirishda xatolik: $e');
    }
  }
}
