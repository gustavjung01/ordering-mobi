import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../network/customer_portal_models.dart';

class CatalogLocalSnapshot {
  const CatalogLocalSnapshot({
    required this.cursor,
    required this.items,
    required this.categories,
  });

  const CatalogLocalSnapshot.empty()
    : cursor = null,
      items = const [],
      categories = const [];

  final String? cursor;
  final List<CustomerCatalogItem> items;
  final List<CustomerCategory> categories;
}

abstract class CustomerCatalogStore {
  Future<CatalogLocalSnapshot> read(String userScope);

  Future<void> applySync(String userScope, CustomerCatalogSync sync);

  Future<void> updatePrices(
    String userScope,
    Map<String, CustomerProductPrice> prices,
  );

  Future<void> clear(String userScope);

  Future<void> close();
}

class MemoryCustomerCatalogStore implements CustomerCatalogStore {
  final Map<String, CatalogLocalSnapshot> _snapshots = {};

  @override
  Future<CatalogLocalSnapshot> read(String userScope) async {
    final snapshot = _snapshots[userScope];
    if (snapshot == null) return const CatalogLocalSnapshot.empty();
    return CatalogLocalSnapshot(
      cursor: snapshot.cursor,
      items: List.unmodifiable(snapshot.items),
      categories: List.unmodifiable(snapshot.categories),
    );
  }

  @override
  Future<void> applySync(String userScope, CustomerCatalogSync sync) async {
    final current = sync.full
        ? const CatalogLocalSnapshot.empty()
        : (_snapshots[userScope] ?? const CatalogLocalSnapshot.empty());
    final byVariant = <String, CustomerCatalogItem>{
      for (final item in current.items)
        if (item.variantId?.trim().isNotEmpty == true)
          item.variantId!.trim(): item,
    };
    for (final variantId in sync.removeVariantIds) {
      byVariant.remove(variantId.trim());
    }
    for (final item in sync.upserts) {
      final variantId = item.variantId?.trim() ?? '';
      if (variantId.isNotEmpty) byVariant[variantId] = item;
    }
    _snapshots[userScope] = CatalogLocalSnapshot(
      cursor: sync.cursor,
      items: List.unmodifiable(byVariant.values),
      categories: List.unmodifiable(sync.categories),
    );
  }

  @override
  Future<void> updatePrices(
    String userScope,
    Map<String, CustomerProductPrice> prices,
  ) async {
    final current = _snapshots[userScope];
    if (current == null || prices.isEmpty) return;
    _snapshots[userScope] = CatalogLocalSnapshot(
      cursor: current.cursor,
      categories: current.categories,
      items: [
        for (final item in current.items)
          if (item.variantId != null && prices.containsKey(item.variantId))
            item.copyWithPrice(prices[item.variantId]!)
          else
            item,
      ],
    );
  }

  @override
  Future<void> clear(String userScope) async {
    _snapshots.remove(userScope);
  }

  @override
  Future<void> close() async {}
}

class SqliteCustomerCatalogStore implements CustomerCatalogStore {
  Database? _database;

  Future<Database> _db() async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    final root = await getDatabasesPath();
    final database = await openDatabase(
      '$root/ordering_customer_catalog_v1.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE catalog_items (
            user_scope TEXT NOT NULL,
            variant_id TEXT NOT NULL,
            sku TEXT NOT NULL,
            payload TEXT NOT NULL,
            PRIMARY KEY (user_scope, variant_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_catalog_items_user_sku '
          'ON catalog_items(user_scope, sku)',
        );
        await db.execute('''
          CREATE TABLE catalog_meta (
            user_scope TEXT PRIMARY KEY,
            cursor TEXT,
            categories_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<CatalogLocalSnapshot> read(String userScope) async {
    final db = await _db();
    final rows = await db.query(
      'catalog_items',
      columns: ['payload'],
      where: 'user_scope = ?',
      whereArgs: [userScope],
      orderBy: 'sku ASC',
    );
    final metaRows = await db.query(
      'catalog_meta',
      where: 'user_scope = ?',
      whereArgs: [userScope],
      limit: 1,
    );

    final items = <CustomerCatalogItem>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row['payload'] as String);
        if (decoded is Map) {
          items.add(
            CustomerCatalogItem.fromJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      } on Object {
        // One corrupt row must not invalidate the complete local catalog.
      }
    }

    String? cursor;
    final categories = <CustomerCategory>[];
    if (metaRows.isNotEmpty) {
      cursor = metaRows.first['cursor'] as String?;
      try {
        final decoded = jsonDecode(
          metaRows.first['categories_json'] as String? ?? '[]',
        );
        if (decoded is List) {
          for (final raw in decoded) {
            if (raw is Map) {
              categories.add(
                CustomerCategory.fromJson(
                  raw.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      } on Object {
        // The next catalog sync restores category metadata.
      }
    }

    return CatalogLocalSnapshot(
      cursor: cursor,
      items: List.unmodifiable(items),
      categories: List.unmodifiable(categories),
    );
  }

  @override
  Future<void> applySync(String userScope, CustomerCatalogSync sync) async {
    final db = await _db();
    await db.transaction((txn) async {
      if (sync.full) {
        await txn.delete(
          'catalog_items',
          where: 'user_scope = ?',
          whereArgs: [userScope],
        );
      }
      for (final variantId in sync.removeVariantIds) {
        await txn.delete(
          'catalog_items',
          where: 'user_scope = ? AND variant_id = ?',
          whereArgs: [userScope, variantId.trim()],
        );
      }
      for (final item in sync.upserts) {
        final variantId = item.variantId?.trim() ?? '';
        if (variantId.isEmpty) continue;
        await txn.insert(
          'catalog_items',
          {
            'user_scope': userScope,
            'variant_id': variantId,
            'sku': item.sku.trim().toUpperCase(),
            'payload': jsonEncode(item.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'catalog_meta',
        {
          'user_scope': userScope,
          'cursor': sync.cursor,
          'categories_json': jsonEncode(
            sync.categories.map((category) => category.toJson()).toList(),
          ),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> updatePrices(
    String userScope,
    Map<String, CustomerProductPrice> prices,
  ) async {
    if (prices.isEmpty) return;
    final db = await _db();
    await db.transaction((txn) async {
      for (final entry in prices.entries) {
        final rows = await txn.query(
          'catalog_items',
          columns: ['payload'],
          where: 'user_scope = ? AND variant_id = ?',
          whereArgs: [userScope, entry.key],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        try {
          final decoded = jsonDecode(rows.first['payload'] as String);
          if (decoded is! Map) continue;
          final item = CustomerCatalogItem.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          ).copyWithPrice(entry.value);
          await txn.update(
            'catalog_items',
            {'payload': jsonEncode(item.toJson())},
            where: 'user_scope = ? AND variant_id = ?',
            whereArgs: [userScope, entry.key],
          );
        } on Object {
          // The next catalog sync repairs malformed cached rows.
        }
      }
    });
  }

  @override
  Future<void> clear(String userScope) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete(
        'catalog_items',
        where: 'user_scope = ?',
        whereArgs: [userScope],
      );
      await txn.delete(
        'catalog_meta',
        where: 'user_scope = ?',
        whereArgs: [userScope],
      );
    });
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) await db.close();
  }
}
