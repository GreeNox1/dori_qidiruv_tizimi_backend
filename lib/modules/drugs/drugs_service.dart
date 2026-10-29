import '../../config/database.dart';

class DrugsService {
  Future<Map<String, dynamic>> searchDrugs({
    String? query,
    String? district,
    bool inStockOnly = false,
    String sortPrice = 'asc',
    int page = 1,
    int limit = 10,
    int? currentUserId,
  }) async {
    final offset = (page - 1) * limit;
    final isAsc = sortPrice.toLowerCase() == 'asc';
    final orderClause = isAsc ? 'min_price ASC NULLS LAST' : 'min_price DESC NULLS LAST';

    final qPattern = (query != null && query.trim().isNotEmpty) ? '%${query.trim()}%' : null;

    final sql = '''
      SELECT d.id, d.trade_name, d.inn_name, d.form, d.dosage, d.manufacturer, 
             d.prescription_required, d.description,
             MIN(bi.price) AS min_price, 
             MAX(bi.price) AS max_price, 
             COUNT(DISTINCT bi.branch_id) FILTER (WHERE bi.is_available = true AND bi.quantity > 0) AS pharmacy_count
             ${currentUserId != null ? ', EXISTS(SELECT 1 FROM saved_drugs sd WHERE sd.drug_id = d.id AND sd.user_id = @user_id) AS is_saved' : ', FALSE AS is_saved'}
      FROM drugs d
      LEFT JOIN branch_inventory bi ON d.id = bi.drug_id
      LEFT JOIN branches b ON bi.branch_id = b.id
      WHERE (@q::text IS NULL OR d.trade_name ILIKE @q OR d.inn_name ILIKE @q)
        AND (@district::text IS NULL OR b.district = @district)
        AND (@in_stock = false OR (bi.is_available = true AND bi.quantity > 0))
      GROUP BY d.id
      ORDER BY $orderClause
      LIMIT @limit OFFSET @offset;
    ''';

    final rows = await Database.query(sql, parameters: {
      'q': qPattern,
      'district': (district != null && district.trim().isNotEmpty) ? district.trim() : null,
      'in_stock': inStockOnly,
      'limit': limit + 1, // +1 to check has_more easily
      'offset': offset,
      'user_id': ?currentUserId,
    });

    final hasMore = rows.length > limit;
    final items = hasMore ? rows.sublist(0, limit) : rows;

    final formatted = items.map((row) {
      return {
        'id': row['id'],
        'trade_name': row['trade_name'],
        'inn_name': row['inn_name'],
        'form': row['form'],
        'dosage': row['dosage'],
        'manufacturer': row['manufacturer'],
        'prescription_required': row['prescription_required'] ?? false,
        'min_price': row['min_price'] != null ? double.tryParse(row['min_price'].toString()) : null,
        'max_price': row['max_price'] != null ? double.tryParse(row['max_price'].toString()) : null,
        'pharmacy_count': int.tryParse(row['pharmacy_count']?.toString() ?? '0') ?? 0,
        'is_saved': row['is_saved'] == true,
      };
    }).toList();

    return {
      'items': formatted,
      'pagination': {
        'current_page': page,
        'limit': limit,
        'has_more': hasMore,
      },
    };
  }

  Future<Map<String, dynamic>?> getDrugById(int id, {int? currentUserId}) async {
    final sql = '''
      SELECT d.*,
             MIN(bi.price) AS min_price, 
             MAX(bi.price) AS max_price, 
             COUNT(DISTINCT bi.branch_id) FILTER (WHERE bi.is_available = true AND bi.quantity > 0) AS pharmacy_count
             ${currentUserId != null ? ', EXISTS(SELECT 1 FROM saved_drugs sd WHERE sd.drug_id = d.id AND sd.user_id = @user_id) AS is_saved' : ', FALSE AS is_saved'}
      FROM drugs d
      LEFT JOIN branch_inventory bi ON d.id = bi.drug_id
      WHERE d.id = @id
      GROUP BY d.id
      LIMIT 1;
    ''';

    final row = await Database.queryOne(sql, parameters: {
      'id': id,
      'user_id': ?currentUserId,
    });

    if (row == null) return null;

    return {
      'id': row['id'],
      'trade_name': row['trade_name'],
      'inn_name': row['inn_name'],
      'form': row['form'],
      'dosage': row['dosage'],
      'manufacturer': row['manufacturer'],
      'prescription_required': row['prescription_required'] ?? false,
      'indications': row['indications'],
      'dosage_instructions': row['dosage_instructions'],
      'contraindications': row['contraindications'],
      'storage_conditions': row['storage_conditions'],
      'description': row['description'],
      'min_price': row['min_price'] != null ? double.tryParse(row['min_price'].toString()) : null,
      'max_price': row['max_price'] != null ? double.tryParse(row['max_price'].toString()) : null,
      'pharmacy_count': int.tryParse(row['pharmacy_count']?.toString() ?? '0') ?? 0,
      'is_saved': row['is_saved'] == true,
    };
  }

  Future<List<Map<String, dynamic>>> getDrugPrices(
    int drugId, {
    String? district,
    String sort = 'asc',
  }) async {
    final isAsc = sort.toLowerCase() == 'asc';
    final orderClause = isAsc ? 'bi.price ASC' : 'bi.price DESC';

    final sql = '''
      SELECT bi.id, bi.branch_id, bi.price, bi.quantity, bi.is_available,
             b.id AS b_id, b.name AS b_name, b.district, b.address, b.landmark, 
             b.phone AS b_phone, b.working_hours, p.name AS pharmacy_name
      FROM branch_inventory bi
      JOIN branches b ON bi.branch_id = b.id
      JOIN pharmacies p ON b.pharmacy_id = p.id
      WHERE bi.drug_id = @drug_id
        AND bi.is_available = true
        AND bi.quantity > 0
        AND b.is_active = true
        AND (@district::text IS NULL OR b.district = @district)
      ORDER BY $orderClause;
    ''';

    final rows = await Database.query(sql, parameters: {
      'drug_id': drugId,
      'district': (district != null && district.trim().isNotEmpty) ? district.trim() : null,
    });

    return rows.map((row) {
      return {
        'id': row['id'],
        'branch_id': row['branch_id'],
        'price': double.tryParse(row['price']?.toString() ?? '0') ?? 0.0,
        'quantity': row['quantity'],
        'is_available': row['is_available'] ?? true,
        'branch': {
          'id': row['b_id'],
          'pharmacy_name': row['pharmacy_name'],
          'name': row['b_name'],
          'district': row['district'],
          'address': row['address'],
          'landmark': row['landmark'],
          'phone': row['b_phone'],
          'working_hours': row['working_hours'],
        },
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDrugAnalogs(int drugId) async {
    const getInnSql = 'SELECT inn_name FROM drugs WHERE id = @id LIMIT 1;';
    final currentDrug = await Database.queryOne(getInnSql, parameters: {'id': drugId});
    if (currentDrug == null || currentDrug['inn_name'] == null) {
      return [];
    }

    final innName = currentDrug['inn_name'] as String;

    const sql = '''
      SELECT d.id, d.trade_name, d.inn_name, d.form, d.dosage, d.manufacturer,
             MIN(bi.price) AS min_price
      FROM drugs d
      LEFT JOIN branch_inventory bi ON d.id = bi.drug_id AND bi.is_available = true AND bi.quantity > 0
      WHERE LOWER(d.inn_name) = LOWER(@inn_name)
        AND d.id != @current_id
      GROUP BY d.id
      ORDER BY min_price ASC NULLS LAST;
    ''';

    final rows = await Database.query(sql, parameters: {
      'inn_name': innName,
      'current_id': drugId,
    });

    return rows.map((row) {
      return {
        'id': row['id'],
        'trade_name': row['trade_name'],
        'inn_name': row['inn_name'],
        'form': row['form'],
        'dosage': row['dosage'],
        'manufacturer': row['manufacturer'],
        'min_price': row['min_price'] != null ? double.tryParse(row['min_price'].toString()) : null,
      };
    }).toList();
  }
}
