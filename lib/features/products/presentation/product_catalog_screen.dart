import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../shared/formatters.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../domain/catalog_product_metadata.dart';
import 'catalog_product_visual.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({
    super.key,
    required this.repository,
    this.quickOrder = false,
  });

  final CustomerOrderingRepository repository;

  @Deprecated('Dùng QuickOrderScreen cho nhánh Đặt nhanh.')
  final bool quickOrder;

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  static const _initialVisibleGroups = 20;
  static const _loadMoreGroups = 20;

  final _searchController = TextEditingController();
  Timer? _searchTimer;
  CatalogMetadataIndex? _metadata;
  List<CustomerCatalogItem> _items = const [];
  String? _categoryId;
  String? _productType;
  String? _purchaseMode;
  String _query = '';
  bool _loading = true;
  String? _error;
  int _requestVersion = 0;
  int _visibleGroupCount = _initialVisibleGroups;
  final Map<String, String> _selectedSkuByGroup = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final values = await Future.wait<Object>([
        CatalogMetadataIndex.shared(),
        widget.repository.listAllCatalog(refresh: true),
      ]);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _metadata = values[0] as CatalogMetadataIndex;
        _items = dedupeCatalogItems(
          values[1] as List<CustomerCatalogItem>,
        );
        _visibleGroupCount = _initialVisibleGroups;
        _loading = false;
        _error = null;
      });
    } on ApiFailure catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được danh mục sản phẩm.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _visibleGroupCount = _initialVisibleGroups;
      });
    });
  }

  Future<void> _add(CustomerCatalogItem item, {int quantity = 1}) async {
    try {
      await widget.repository.addProduct(item, quantity: quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm ${item.name} vào giỏ.')),
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  List<CustomerCatalogItem> _filteredItems(CatalogMetadataIndex metadata) {
    final normalizedQuery = metadata.normalizeQuery(_query);
    return _items
        .where((item) {
          if (_categoryId != null &&
              metadata.categoryIdFor(item) != _categoryId) {
            return false;
          }
          if (_productType != null &&
              metadata.productTypeFor(item) != _productType) {
            return false;
          }
          if (_purchaseMode != null && item.purchaseMode != _purchaseMode) {
            return false;
          }
          if (normalizedQuery.isNotEmpty &&
              !metadata.searchableTextFor(item).contains(normalizedQuery)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Map<String, String> _categoryOptions(CatalogMetadataIndex metadata) {
    final result = <String, String>{};
    for (final item in _items) {
      final id = metadata.categoryIdFor(item);
      final label = metadata.categoryLabelFor(item);
      if (id.isNotEmpty && label.isNotEmpty) result[id] = label;
    }
    return Map.fromEntries(
      result.entries.toList()
        ..sort((left, right) => left.value.compareTo(right.value)),
    );
  }

  List<String> _productTypeOptions(CatalogMetadataIndex metadata) {
    final values =
        _items
            .where(
              (item) =>
                  _categoryId == null ||
                  metadata.categoryIdFor(item) == _categoryId,
            )
            .map(metadata.productTypeFor)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  void _selectCategory(String? categoryId) {
    setState(() {
      _categoryId = categoryId;
      _productType = null;
      _visibleGroupCount = _initialVisibleGroups;
    });
  }

  void _selectPurchaseMode(String? mode) {
    setState(() {
      _purchaseMode = mode;
      _visibleGroupCount = _initialVisibleGroups;
    });
  }

  CustomerCatalogItem? _modeItem(
    CatalogMetadataIndex metadata,
    CatalogProductGroup group,
    CustomerCatalogItem selected,
    String mode,
  ) {
    final family = metadata.familySkuFor(selected);
    for (final item in group.products) {
      if (metadata.familySkuFor(item) == family && item.purchaseMode == mode) {
        return item;
      }
    }
    return null;
  }

  CustomerCatalogItem _chooseVariant(
    CatalogMetadataIndex metadata,
    CatalogProductGroup group,
    String variant,
    CustomerCatalogItem current,
  ) {
    final candidates = group.productsForVariant(metadata, variant);
    for (final item in candidates) {
      if (item.purchaseMode == current.purchaseMode) return item;
    }
    for (final item in candidates) {
      if (item.purchaseMode == 'retail') return item;
    }
    return candidates.first;
  }

  CustomerCatalogItem _chooseSize(
    CatalogMetadataIndex metadata,
    Iterable<CustomerCatalogItem> candidates,
    String size,
    CustomerCatalogItem current,
  ) {
    final sized = candidates
        .where((item) => metadata.sizeFor(item) == size)
        .toList(growable: false);
    for (final item in sized) {
      if (item.purchaseMode == current.purchaseMode) return item;
    }
    for (final item in sized) {
      if (item.purchaseMode == 'retail') return item;
    }
    return sized.first;
  }

  Future<void> _openGroup(
    CatalogProductGroup group,
    CustomerCatalogItem initial,
  ) async {
    final metadata = _metadata;
    if (metadata == null) return;
    var selected = initial;
    var quantity = 1;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final variants = group.variantLabels(metadata);
            final selectedVariant = metadata.variantFor(selected);
            final variantProducts = selectedVariant.isEmpty
                ? group.products
                : group.productsForVariant(metadata, selectedVariant);
            final sizes =
                variantProducts
                    .map(metadata.sizeFor)
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList(growable: false)
                  ..sort();
            final retail = _modeItem(metadata, group, selected, 'retail');
            final caseItem = _modeItem(metadata, group, selected, 'case');

            void selectProduct(CustomerCatalogItem item) {
              setSheetState(() => selected = item);
              setState(() => _selectedSkuByGroup[group.key] = item.sku);
            }

            return FractionallySizedBox(
              heightFactor: .9,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CatalogProductVisual(
                        item: selected,
                        metadata: metadata,
                        size: 116,
                        borderRadius: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (metadata.brandFor(selected).isNotEmpty)
                              Text(
                                metadata.brandFor(selected).toUpperCase(),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              selected.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (variants.length > 1) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Vị / loại',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final variant in variants)
                          Builder(
                            builder: (context) {
                              final option = _chooseVariant(
                                metadata,
                                group,
                                variant,
                                selected,
                              );
                              final active = variant == selectedVariant;
                              return OutlinedButton(
                                onPressed: () => selectProduct(option),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: active
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : null,
                                  side: BorderSide(
                                    color: active
                                        ? Theme.of(context).colorScheme.primary
                                        : const Color(0xFFDCE5DE),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 9,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      variant,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _priceLabel(option),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                  if (sizes.length > 1) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Dung tích / size',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final size in sizes)
                          ChoiceChip(
                            selected: metadata.sizeFor(selected) == size,
                            label: Text(size),
                            onSelected: (_) => selectProduct(
                              _chooseSize(
                                metadata,
                                variantProducts,
                                size,
                                selected,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Giá bán',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ModePriceBox(
                          label: 'Mua lẻ',
                          item: retail,
                          selected: selected.purchaseMode == 'retail',
                          onTap: retail == null
                              ? null
                              : () => selectProduct(retail),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModePriceBox(
                          label: 'Mua thùng',
                          item: caseItem,
                          selected: selected.purchaseMode == 'case',
                          onTap: caseItem == null
                              ? null
                              : () => selectProduct(caseItem),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _QuantityStepper(
                        quantity: quantity,
                        onChanged: (value) {
                          setSheetState(() => quantity = value);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await _add(selected, quantity: quantity);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: Text(
                            selected.purchaseMode == 'case'
                                ? 'Thêm thùng vào giỏ'
                                : 'Thêm lẻ vào giỏ',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata;
    if (_loading || metadata == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _CatalogState(
        icon: Icons.error_outline_rounded,
        message: _error!,
        action: FilledButton(
          onPressed: _load,
          child: const Text('Thử lại'),
        ),
      );
    }

    final filtered = _filteredItems(metadata);
    final visibleByKey = <String, List<CustomerCatalogItem>>{};
    for (final item in filtered) {
      visibleByKey.putIfAbsent(metadata.groupKeyFor(item), () => []).add(item);
    }
    final allGroups = <String, CatalogProductGroup>{
      for (final group in buildCatalogProductGroups(_items, metadata))
        group.key: group,
    };
    final groups =
        visibleByKey.keys
            .map((key) => allGroups[key])
            .whereType<CatalogProductGroup>()
            .toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name));
    final shownGroups = groups.take(_visibleGroupCount).toList(growable: false);
    final categories = _categoryOptions(metadata);
    final productTypes = _productTypeOptions(metadata);
    final columns = MediaQuery.sizeOf(context).width >= 720 ? 3 : 2;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Tên, nhãn, vị hoặc quy cách',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _visibleGroupCount = _initialVisibleGroups;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in const [
                  (value: null, label: 'Tất cả'),
                  (value: 'retail', label: 'Mua lẻ'),
                  (value: 'case', label: 'Mua thùng'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _purchaseMode == option.value,
                      showCheckmark: false,
                      label: Text(option.label),
                      onSelected: (_) => _selectPurchaseMode(option.value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _categoryId == null,
                    showCheckmark: false,
                    label: const Text('Tất cả ngành'),
                    onSelected: (_) => _selectCategory(null),
                  ),
                ),
                for (final entry in categories.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _categoryId == entry.key,
                      showCheckmark: false,
                      label: Text(entry.value),
                      onSelected: (_) => _selectCategory(entry.key),
                    ),
                  ),
              ],
            ),
          ),
          if (_categoryId != null && productTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nhóm hàng',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _productType == null,
                      showCheckmark: false,
                      label: const Text('Tất cả'),
                      onSelected: (_) => setState(() {
                        _productType = null;
                        _visibleGroupCount = _initialVisibleGroups;
                      }),
                    ),
                  ),
                  for (final productType in productTypes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _productType == productType,
                        showCheckmark: false,
                        label: Text(productType),
                        onSelected: (_) => setState(() {
                          _productType = productType;
                          _visibleGroupCount = _initialVisibleGroups;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const _CatalogState(
              icon: Icons.inventory_2_outlined,
              message: 'Không tìm thấy sản phẩm.',
            )
          else ...[
            GridView.builder(
              itemCount: shownGroups.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .57,
              ),
              itemBuilder: (context, index) {
                final group = shownGroups[index];
                final visibleProducts =
                    visibleByKey[group.key] ?? group.products;
                final visibleGroup = CatalogProductGroup(
                  key: group.key,
                  name: group.name,
                  products: visibleProducts,
                );
                final selected = visibleGroup.preferred(
                  selectedSku: _selectedSkuByGroup[group.key],
                  purchaseMode: _purchaseMode,
                );
                return _CatalogFamilyCard(
                  group: group,
                  selected: selected,
                  metadata: metadata,
                  retail: _modeItem(metadata, group, selected, 'retail'),
                  caseItem: _modeItem(metadata, group, selected, 'case'),
                  onOpen: () => _openGroup(group, selected),
                  onSelect: (item) {
                    setState(() => _selectedSkuByGroup[group.key] = item.sku);
                  },
                  onAdd: () => _add(selected),
                );
              },
            ),
            if (_visibleGroupCount < groups.length)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.tonal(
                  onPressed: () => setState(() {
                    _visibleGroupCount = (_visibleGroupCount + _loadMoreGroups)
                        .clamp(0, groups.length)
                        .toInt();
                  }),
                  child: Text(
                    'Xem thêm ${_loadMoreGroups.clamp(
                      0,
                      groups.length - _visibleGroupCount,
                    )} sản phẩm',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CatalogFamilyCard extends StatelessWidget {
  const _CatalogFamilyCard({
    required this.group,
    required this.selected,
    required this.metadata,
    required this.retail,
    required this.caseItem,
    required this.onOpen,
    required this.onSelect,
    required this.onAdd,
  });

  final CatalogProductGroup group;
  final CustomerCatalogItem selected;
  final CatalogMetadataIndex metadata;
  final CustomerCatalogItem? retail;
  final CustomerCatalogItem? caseItem;
  final VoidCallback onOpen;
  final ValueChanged<CustomerCatalogItem> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final variants = group.variantLabels(metadata);
    final sizes = group.sizeLabels(metadata);
    final subtitle = [
      metadata.productTypeFor(selected),
      variants.length > 1
          ? '${variants.length} vị / loại'
          : metadata.variantFor(selected),
      sizes.length > 1 ? '${sizes.length} size' : metadata.sizeFor(selected),
    ].where((value) => value.isNotEmpty).join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CatalogProductVisual(
                  item: selected,
                  metadata: metadata,
                  size: 108,
                  borderRadius: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (metadata.brandFor(selected).isNotEmpty)
                Text(
                  metadata.brandFor(selected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                group.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle.isEmpty ? selected.unitLabel : subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (metadata.variantFor(selected).isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    metadata.variantFor(selected),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                _priceLabel(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: 'Lẻ',
                      selected: selected.sku == retail?.sku,
                      enabled: retail != null,
                      onTap: retail == null ? null : () => onSelect(retail!),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _ModeButton(
                      label: 'Thùng',
                      selected: selected.sku == caseItem?.sku,
                      enabled: caseItem != null,
                      onTap: caseItem == null
                          ? null
                          : () => onSelect(caseItem!),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton.filled(
                    tooltip: 'Thêm vào giỏ',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFDCE5DE),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ModePriceBox extends StatelessWidget {
  const _ModePriceBox({
    required this.label,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final CustomerCatalogItem? item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFDDE5DE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              item == null ? '—' : _priceLabel(item!),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: item == null
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDCE5DE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Giảm số lượng',
            onPressed: quantity <= 1 ? null : () => onChanged(quantity - 1),
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Text(
            '$quantity',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            tooltip: 'Tăng số lượng',
            onPressed: quantity >= 99 ? null : () => onChanged(quantity + 1),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CatalogState extends StatelessWidget {
  const _CatalogState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

String _priceLabel(CustomerCatalogItem item) {
  final amount = item.price.isAvailable ? item.price.amount : null;
  return amount == null ? 'Chờ xác nhận giá' : formatVnd(amount);
}
