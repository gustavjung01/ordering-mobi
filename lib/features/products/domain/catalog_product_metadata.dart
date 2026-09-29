import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/network/customer_portal_models.dart';

const _canonicalMapAsset = 'assets/catalog/canonical-product-map.json';
const _productImageSkusAsset = 'assets/catalog/r2-product-image-skus.json';
const _productImageBase =
    'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/products';

const _categoryIdByIndustryKey = <String, String>{
  'tra-sua': 'milk-tea',
  'mi-cay': 'spicy-noodle',
  'dong-lanh': 'frozen',
  'an-vat': 'snacks',
  'bao-bi': 'packaging',
  'gia-vi-sot': 'sauce-seasoning',
};

String _clean(Object? value) =>
    value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';

String _normalize(String value) {
  var result = value.toLowerCase();
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };
  replacements.forEach((from, to) => result = result.replaceAll(from, to));
  return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _seriesName(String productType, String brand) {
  final group = _clean(productType);
  final line = _clean(brand);
  if (group.isEmpty) return line.isEmpty ? 'Sản phẩm' : line;
  if (line.isEmpty) return group;
  final groupKey = _normalize(group);
  final brandKey = _normalize(line);
  if (brandKey == groupKey || brandKey.startsWith('$groupKey ')) return line;
  if (groupKey.startsWith('$brandKey ')) return group;
  return '$group $line'.trim();
}

class CanonicalProductMetadata {
  const CanonicalProductMetadata({
    required this.familySku,
    required this.industryKey,
    required this.industryName,
    required this.productType,
    required this.productCardKey,
    required this.brand,
    required this.variant,
    required this.flavor,
    required this.size,
  });

  final String familySku;
  final String industryKey;
  final String industryName;
  final String productType;
  final String productCardKey;
  final String brand;
  final String variant;
  final String flavor;
  final String size;

  String get categoryId => _categoryIdByIndustryKey[industryKey] ?? industryKey;

  String get seriesName => _seriesName(productType, brand);

  String get variantLabel {
    if (variant.isNotEmpty) return variant;
    return flavor;
  }
}

class CatalogMetadataIndex {
  CatalogMetadataIndex({
    required Map<String, CanonicalProductMetadata> families,
    required Set<String> imageFamilies,
  }) : _families = Map.unmodifiable(families),
       _imageFamilies = Set.unmodifiable(
         imageFamilies.map((value) => value.trim().toUpperCase()),
       );

  static Future<CatalogMetadataIndex>? _shared;

  final Map<String, CanonicalProductMetadata> _families;
  final Set<String> _imageFamilies;

  static Future<CatalogMetadataIndex> shared() {
    return _shared ??= load();
  }

  static Future<CatalogMetadataIndex> load([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final values = await Future.wait([
      assets.loadString(_canonicalMapAsset),
      assets.loadString(_productImageSkusAsset),
    ]);
    final decodedMap = jsonDecode(values[0]);
    final decodedImages = jsonDecode(values[1]);
    if (decodedMap is! Map || decodedImages is! List) {
      throw const FormatException('Dữ liệu danh mục chuẩn chưa hợp lệ.');
    }

    final families = <String, CanonicalProductMetadata>{};
    for (final entry in decodedMap.entries) {
      final familySku = _clean(entry.key).toUpperCase();
      final row = entry.value;
      if (familySku.isEmpty || row is! List || row.length < 8) continue;
      families[familySku] = CanonicalProductMetadata(
        familySku: familySku,
        industryKey: _clean(row[0]),
        industryName: _clean(row[1]),
        productType: _clean(row[2]),
        productCardKey: _clean(row[3]),
        brand: _clean(row[4]),
        variant: _clean(row[5]),
        flavor: _clean(row[6]),
        size: _clean(row[7]),
      );
    }
    final images = decodedImages
        .map((value) => _clean(value).toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    return CatalogMetadataIndex(families: families, imageFamilies: images);
  }

  String familySkuFor(CustomerCatalogItem item) {
    final productCode = item.productCode?.trim().toUpperCase() ?? '';
    return productCode.isNotEmpty ? productCode : item.sku.trim().toUpperCase();
  }

  CanonicalProductMetadata? metadataFor(CustomerCatalogItem item) {
    return _families[familySkuFor(item)];
  }

  String groupKeyFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null && meta.productCardKey.isNotEmpty) {
      return 'canonical:${meta.productCardKey}';
    }
    return 'family:${familySkuFor(item)}';
  }

  String groupNameFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null) return meta.seriesName;
    final brand = item.brandName?.trim() ?? '';
    if (brand.isNotEmpty) return brand;
    return item.name.trim().isNotEmpty ? item.name.trim() : item.sku;
  }

  String brandFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null && meta.brand.isNotEmpty) return meta.brand;
    return item.brandName?.trim() ?? '';
  }

  String variantFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null && meta.variantLabel.isNotEmpty) {
      return meta.variantLabel;
    }
    return item.variantName.trim();
  }

  String sizeFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null && meta.size.isNotEmpty) return meta.size;
    return item.variantName.trim();
  }

  String productTypeFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null && meta.productType.isNotEmpty) {
      return meta.productType;
    }
    return item.categoryName?.trim() ?? '';
  }

  String categoryIdFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null) return meta.categoryId;
    return item.parentCategoryId?.trim().isNotEmpty == true
        ? item.parentCategoryId!.trim()
        : item.categoryId?.trim() ?? '';
  }

  String categoryLabelFor(CustomerCatalogItem item) {
    final meta = metadataFor(item);
    if (meta != null && meta.industryName.isNotEmpty) {
      return meta.industryName;
    }
    if (item.parentCategoryName?.trim().isNotEmpty == true) {
      return item.parentCategoryName!.trim();
    }
    return item.categoryName?.trim() ?? '';
  }

  String searchableTextFor(CustomerCatalogItem item) {
    return _normalize(
      [
        item.sku,
        item.productCode ?? '',
        item.name,
        item.variantName,
        brandFor(item),
        variantFor(item),
        sizeFor(item),
        productTypeFor(item),
        categoryLabelFor(item),
      ].join(' '),
    );
  }

  String normalizeQuery(String value) => _normalize(value);

  String? imageUrlFor(CustomerCatalogItem item) {
    final family = familySkuFor(item);
    if (!_imageFamilies.contains(family)) return null;
    return '$_productImageBase/${Uri.encodeComponent(family)}.webp';
  }
}

class CatalogProductGroup {
  const CatalogProductGroup({
    required this.key,
    required this.name,
    required this.products,
  });

  final String key;
  final String name;
  final List<CustomerCatalogItem> products;

  CustomerCatalogItem preferred({
    String? selectedSku,
    String? purchaseMode,
  }) {
    for (final item in products) {
      if (item.sku == selectedSku &&
          (purchaseMode == null || item.purchaseMode == purchaseMode)) {
        return item;
      }
    }
    if (purchaseMode != null) {
      for (final item in products) {
        if (item.purchaseMode == purchaseMode) return item;
      }
    }
    for (final item in products) {
      if (item.purchaseMode == 'retail') return item;
    }
    return products.first;
  }

  List<String> variantLabels(CatalogMetadataIndex metadata) {
    final values =
        products
            .map(metadata.variantFor)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> sizeLabels(CatalogMetadataIndex metadata) {
    final values =
        products
            .map(metadata.sizeFor)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<CustomerCatalogItem> productsForVariant(
    CatalogMetadataIndex metadata,
    String variant,
  ) {
    return products
        .where((item) => metadata.variantFor(item) == variant)
        .toList(growable: false);
  }
}

List<CustomerCatalogItem> dedupeCatalogItems(
  Iterable<CustomerCatalogItem> items,
) {
  final bySku = <String, CustomerCatalogItem>{};
  for (final item in items) {
    final sku = item.sku.trim().toUpperCase();
    if (sku.isEmpty) continue;
    bySku[sku] = item;
  }
  return bySku.values.toList(growable: false);
}

List<CatalogProductGroup> buildCatalogProductGroups(
  Iterable<CustomerCatalogItem> source,
  CatalogMetadataIndex metadata,
) {
  final groups = <String, List<CustomerCatalogItem>>{};
  for (final item in dedupeCatalogItems(source)) {
    groups.putIfAbsent(metadata.groupKeyFor(item), () => []).add(item);
  }

  final result =
      groups.entries
          .map((entry) {
            final products = [...entry.value]
              ..sort((left, right) {
                final variant = metadata
                    .variantFor(left)
                    .compareTo(metadata.variantFor(right));
                if (variant != 0) return variant;
                final size = metadata
                    .sizeFor(left)
                    .compareTo(metadata.sizeFor(right));
                if (size != 0) return size;
                if (left.purchaseMode != right.purchaseMode) {
                  return left.purchaseMode == 'retail' ? -1 : 1;
                }
                return left.sku.compareTo(right.sku);
              });
            return CatalogProductGroup(
              key: entry.key,
              name: metadata.groupNameFor(products.first),
              products: List.unmodifiable(products),
            );
          })
          .toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));
  return result;
}
