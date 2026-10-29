import '../../config/database.dart';

class PharmacistService {
  Future<int?> getBranchIdForUser(int userId) async {
    const sql = '''
      SELECT branch_id FROM branch_staff WHERE user_id = @user_id LIMIT 1;
    ''';
    final row = await Database.queryOne(sql, parameters: {'user_id': userId});
    return row?['branch_id'] as int?;
  }

  Future<Map<String, dynamic>> getBranchInfo(int userId) async {
    final branchId = await getBranchIdForUser(userId);
    if (branchId == null) {
      throw const PharmacistException('Siz hech qanday filialga biriktirilmagansiz', 404);
    }

    const sql = '''
      SELECT b.id, b.name, b.district, b.address, b.landmark, 
             b.phone, b.working_hours, b.is_active, p.name AS pharmacy_name
      FROM branches b
      JOIN pharmacies p ON b.pharmacy_id = p.id
      WHERE b.id = @branch_id
      LIMIT 1;
    ''';

    final branch = await Database.queryOne(sql, parameters: {'branch_id': branchId});
    if (branch == null) {
      throw const PharmacistException('Filial topilmadi', 404);
    }

    return branch;
  }

  Future<Map<String, dynamic>> updateBranchInfo({
    required int userId,
    String? address,
    String? landmark,
    String? phone,
    String? workingHours,
  }) async {
    final branchId = await getBranchIdForUser(userId);
    if (branchId == null) {
      throw const PharmacistException('Siz filialga biriktirilmagansiz', 403);
    }

    const sql = '''
      UPDATE branches
      SET address = COALESCE(@address, address),
          landmark = COALESCE(@landmark, landmark),
          phone = COALESCE(@phone, phone),
          working_hours = COALESCE(@working_hours, working_hours)
      WHERE id = @branch_id
      RETURNING id, name, district, address, landmark, phone, working_hours, is_active;
    ''';

    final updated = await Database.queryOne(sql, parameters: {
      'branch_id': branchId,
      'address': address?.trim(),
      'landmark': landmark?.trim(),
      'phone': phone?.trim(),
      'working_hours': workingHours?.trim(),
    });

    if (updated == null) {
      throw const PharmacistException('Filial ma’lumotini yangilab bo‘lmadi', 400);
    }

    return updated;
  }

  Future<List<Map<String, dynamic>>> getInventory({
    required int userId,
    String? query,
    String status = 'all',
  }) async {
    final branchId = await getBranchIdForUser(userId);
    if (branchId == null) {
      throw const PharmacistException('Siz filialga biriktirilmagansiz', 403);
    }

    final qPattern = (query != null && query.trim().isNotEmpty) ? '%${query.trim()}%' : null;

    String statusFilter = '';
    if (status == 'in_stock') {
      statusFilter = 'AND bi.is_available = true AND bi.quantity > 0';
    } else if (status == 'out_of_stock') {
      statusFilter = 'AND (bi.is_available = false OR bi.quantity <= 0)';
    }

    final sql = '''
      SELECT bi.id, bi.branch_id, bi.drug_id, bi.price, bi.quantity, 
             bi.is_available, bi.updated_at,
             d.trade_name, d.inn_name, d.form, d.dosage, d.manufacturer
      FROM branch_inventory bi
      JOIN drugs d ON bi.drug_id = d.id
      WHERE bi.branch_id = @branch_id
        $statusFilter
        AND (@q::text IS NULL OR d.trade_name ILIKE @q OR d.inn_name ILIKE @q)
      ORDER BY bi.updated_at DESC;
    ''';

    final rows = await Database.query(sql, parameters: {
      'branch_id': branchId,
      'q': qPattern,
    });

    return rows.map((row) {
      return {
        'id': row['id'],
        'branch_id': row['branch_id'],
        'drug_id': row['drug_id'],
        'price': double.tryParse(row['price']?.toString() ?? '0') ?? 0.0,
        'quantity': row['quantity'],
        'is_available': row['is_available'] ?? true,
        'updated_at': row['updated_at']?.toString(),
        'drug': {
          'id': row['drug_id'],
          'trade_name': row['trade_name'],
          'inn_name': row['inn_name'],
          'form': row['form'],
          'dosage': row['dosage'],
          'manufacturer': row['manufacturer'],
        },
      };
    }).toList();
  }

  Future<Map<String, dynamic>> addInventoryItem({
    required int userId,
    required int drugId,
    required double price,
    required int quantity,
  }) async {
    final branchId = await getBranchIdForUser(userId);
    if (branchId == null) {
      throw const PharmacistException('Siz filialga biriktirilmagansiz', 403);
    }

    // Check drug exists
    const checkDrugSql = 'SELECT id FROM drugs WHERE id = @id LIMIT 1;';
    final drug = await Database.queryOne(checkDrugSql, parameters: {'id': drugId});
    if (drug == null) {
      throw const PharmacistException('Katalogda bunday dori topilmadi', 404);
    }

    const sql = '''
      INSERT INTO branch_inventory (branch_id, drug_id, price, quantity, is_available, updated_at)
      VALUES (@branch_id, @drug_id, @price, @quantity, @is_available, CURRENT_TIMESTAMP)
      ON CONFLICT (branch_id, drug_id) 
      DO UPDATE SET price = EXCLUDED.price, 
                    quantity = EXCLUDED.quantity, 
                    is_available = EXCLUDED.is_available, 
                    updated_at = CURRENT_TIMESTAMP
      RETURNING id, branch_id, drug_id, price, quantity, is_available, updated_at;
    ''';

    final inserted = await Database.queryOne(sql, parameters: {
      'branch_id': branchId,
      'drug_id': drugId,
      'price': price,
      'quantity': quantity,
      'is_available': quantity > 0,
    });

    if (inserted == null) {
      throw const PharmacistException('Inventarga qo‘shib bo‘lmadi', 500);
    }

    return inserted;
  }

  Future<Map<String, dynamic>> updateInventoryItem({
    required int userId,
    required int inventoryId,
    double? price,
    int? quantity,
    bool? isAvailable,
  }) async {
    final branchId = await getBranchIdForUser(userId);
    if (branchId == null) {
      throw const PharmacistException('Siz filialga biriktirilmagansiz', 403);
    }

    // Verify ownership
    const checkSql = 'SELECT id FROM branch_inventory WHERE id = @id AND branch_id = @branch_id LIMIT 1;';
    final exists = await Database.queryOne(checkSql, parameters: {
      'id': inventoryId,
      'branch_id': branchId,
    });
    if (exists == null) {
      throw const PharmacistException('Omborda bunday yozuv topilmadi yoki bu sizning filialingizga tegishli emas', 404);
    }

    const sql = '''
      UPDATE branch_inventory
      SET price = COALESCE(@price, price),
          quantity = COALESCE(@quantity, quantity),
          is_available = COALESCE(@is_available, is_available),
          updated_at = CURRENT_TIMESTAMP
      WHERE id = @id AND branch_id = @branch_id
      RETURNING id, branch_id, drug_id, price, quantity, is_available, updated_at;
    ''';

    final updated = await Database.queryOne(sql, parameters: {
      'id': inventoryId,
      'branch_id': branchId,
      'price': price,
      'quantity': quantity,
      'is_available': isAvailable,
    });

    if (updated == null) {
      throw const PharmacistException('Inventarni yangilab bo‘lmadi', 400);
    }

    return updated;
  }

  Future<void> deleteInventoryItem({
    required int userId,
    required int inventoryId,
  }) async {
    final branchId = await getBranchIdForUser(userId);
    if (branchId == null) {
      throw const PharmacistException('Siz filialga biriktirilmagansiz', 403);
    }

    const sql = 'DELETE FROM branch_inventory WHERE id = @id AND branch_id = @branch_id;';
    final count = await Database.execute(sql, parameters: {
      'id': inventoryId,
      'branch_id': branchId,
    });

    if (count == 0) {
      throw const PharmacistException('Inventar yozuvi topilmadi yoki o‘chirib bo‘lmadi', 404);
    }
  }
}

class PharmacistException implements Exception {
  final String message;
  final int statusCode;
  const PharmacistException(this.message, [this.statusCode = 400]);

  @override
  String toString() => message;
}
