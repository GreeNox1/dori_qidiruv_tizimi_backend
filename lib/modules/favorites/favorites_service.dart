import '../../config/database.dart';

class FavoritesService {
  Future<List<Map<String, dynamic>>> getFavorites(int userId) async {
    const sql = '''
      SELECT sd.id AS saved_id, sd.drug_id, sd.saved_at,
             d.trade_name, d.inn_name, d.form, d.dosage, d.manufacturer,
             MIN(bi.price) AS min_price,
             COUNT(DISTINCT bi.branch_id) FILTER (WHERE bi.is_available = true AND bi.quantity > 0) AS pharmacy_count
      FROM saved_drugs sd
      JOIN drugs d ON sd.drug_id = d.id
      LEFT JOIN branch_inventory bi ON d.id = bi.drug_id
      WHERE sd.user_id = @user_id
      GROUP BY sd.id, sd.drug_id, sd.saved_at, d.id
      ORDER BY sd.saved_at DESC;
    ''';

    final rows = await Database.query(sql, parameters: {'user_id': userId});

    return rows.map((row) {
      return {
        'id': row['saved_id'],
        'drug_id': row['drug_id'],
        'saved_at': row['saved_at']?.toString(),
        'drug': {
          'id': row['drug_id'],
          'trade_name': row['trade_name'],
          'inn_name': row['inn_name'],
          'form': row['form'],
          'dosage': row['dosage'],
          'manufacturer': row['manufacturer'],
          'min_price': row['min_price'] != null ? double.tryParse(row['min_price'].toString()) : null,
          'pharmacy_count': int.tryParse(row['pharmacy_count']?.toString() ?? '0') ?? 0,
        },
      };
    }).toList();
  }

  Future<Map<String, dynamic>> toggleFavorite(int userId, int drugId) async {
    // Check if drug exists
    const checkDrugSql = 'SELECT id FROM drugs WHERE id = @drug_id LIMIT 1;';
    final drugExists = await Database.queryOne(checkDrugSql, parameters: {'drug_id': drugId});
    if (drugExists == null) {
      throw const FavoritesException('Dori vositasi topilmadi', 404);
    }

    const checkSql = '''
      SELECT id FROM saved_drugs 
      WHERE user_id = @user_id AND drug_id = @drug_id 
      LIMIT 1;
    ''';

    final existing = await Database.queryOne(checkSql, parameters: {
      'user_id': userId,
      'drug_id': drugId,
    });

    if (existing != null) {
      // Remove
      const deleteSql = 'DELETE FROM saved_drugs WHERE id = @id;';
      await Database.execute(deleteSql, parameters: {'id': existing['id']});
      return {
        'is_saved': false,
        'message': 'Dori sevimlilardan o‘chirildi',
      };
    } else {
      // Add
      const insertSql = '''
        INSERT INTO saved_drugs (user_id, drug_id)
        VALUES (@user_id, @drug_id);
      ''';
      await Database.execute(insertSql, parameters: {
        'user_id': userId,
        'drug_id': drugId,
      });
      return {
        'is_saved': true,
        'message': 'Dori sevimlilarga saqlandi',
      };
    }
  }
}

class FavoritesException implements Exception {
  final String message;
  final int statusCode;
  const FavoritesException(this.message, [this.statusCode = 400]);

  @override
  String toString() => message;
}
