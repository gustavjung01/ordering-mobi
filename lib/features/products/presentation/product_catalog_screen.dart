import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
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
  final Set<String> _requestedPriceVariants = {};
  bool _priceHydrationScheduled = false;

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
        widget.repository.listAllCatalog(),
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
      _scheduleVisiblePriceHydration();
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

  List<CatalogProductGroup> _visibleGroups(CatalogMetadataIndex metadata) {
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
    return groups;
  }

  void _scheduleVisiblePriceHydration() {
    if (_priceHydrationScheduled || !mounted) return;
    _priceHydrationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _priceHydrationScheduled = false;
      if (mounted) unawaited(_hydrateVisiblePrices());
    });
  }

  Future<void> _hydrateVisiblePrices() async {
    final metadata = _metadata;
    if (metadata == null || _items.isEmpty) return;
    final selected = _visibleGroups(metadata)
        .take(_visibleGroupCount)
        .map(
          (group) => group.preferred(
            selectedSku: _selectedSkuByGroup[group.key],
            purchaseMode: _purchaseMode,
          ),
        )
        .where((item) => item.variantId?.trim().isNotEmpty == true)
        .where((item) => _requestedPriceVariants.add(item.variantId!.trim()))
        .toList(growable: false);
    if (selected.isEmpty) return;

    try {
      final resolved = await widget.repository.refreshCatalogPrices(selected);
      if (!mounted) return;
      final bySku = {for (final item in resolved) item.sku: item};
      setState(() {
        _items = [for (final item in _items) bySku[item.sku] ?? item];
      });
    } on Object {
      for (final item in selected) {
        final variantId = item.variantId?.trim();
        if (variantId != null) _requestedPriceVariants.remove(variantId);
      }
    }
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
    _scheduleVisiblePriceHydration();
  }

  void _selectPurchaseMode(String? mode) {
    setState(() {
      _purchaseMode = mode;
      _visibleGroupCount = _initialVisibleGroups;
    });
    _scheduleVisiblePriceHydration();
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
    var activeGroup = group;
    var selected = initial;
    try {
      final resolved = await widget.repository.refreshCatalogPrices(
        group.products,
      );
      if (resolved.isNotEmpty) {
        final bySku = {for (final item in resolved) item.sku: item};
        activeGroup = CatalogProductGroup(
          key: group.key,
          name: group.name,
          products: [
            for (final item in group.products) bySku[item.sku] ?? item,
          ],
        );
        selected = bySku[initial.sku] ?? initial;
        if (mounted) {
          setState(() {
            _items = [for (final item in _items) bySku[item.sku] ?? item];
          });
        }
      }
    } on Object {
      // Cached prices remain usable if refresh is temporarily unavailable.
    }
    if (!mounted) return;
    var quantity = 1;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final variants = activeGroup.variantLabels(metadata);
            final selectedVariant = metadata.variantFor(selected);
            final variantProducts = selectedVariant.isEmpty
                ? activeGroup.products
                : activeGroup.productsForVariant(metadata, selectedVariant);
            final sizes =
                variantProducts
                    .map(metadata.sizeFor)
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList(growable: false)
                  ..sort();
            final retail = _modeItem(metadata, activeGroup, selected, 'retail');
            final caseItem = _modeItem(metadata, activeGroup, selected, 'case');

            void selectProduct(CustomerCatalogItem item) {
              setSheetState(() => selected = item);
              setState(() => _selectedSkuByGroup[group.key] = item.sku);
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .82,
              ),
              child: SingleChildScrollView(
                key: const Key('product-sheet-content'),
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CatalogProductVisual(
                          item: selected,
                          metadata: metadata,
                          size: 88,
                          borderRadius: 16,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              group.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (variants.length > 1) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Vị / loại',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final variant in variants)
                            Builder(
                              builder: (context) {
                                final option = _chooseVariant(
                                  metadata,
                                  activeGroup,
                                  variant,
                                  selected,
                                );
                                final active = variant == selectedVariant;
                                return OutlinedButton(
                                  onPressed: () => selectProduct(option),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: active
                                        ? AppTheme.brandDark
                                        : AppTheme.ink,
                                    backgroundColor: active
                                        ? AppTheme.brandSoft
                                        : Colors.white,
                                    side: BorderSide(
                                      color: active
                                          ? AppTheme.brand
                                          : AppTheme.border,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        variant,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _priceLabel(option),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: active
                                                  ? AppTheme.brandDark
                                                  : AppTheme.muted,
                                            ),
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
                      const SizedBox(height: 14),
                      Text(
                        'Dung tích / size',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final size in sizes)
                            ChoiceChip(
                              selected: metadata.sizeFor(selected) == size,
                              showCheckmark: false,
                              selectedColor: AppTheme.brandSoft,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: metadata.sizeFor(selected) == size
                                    ? AppTheme.brand
                                    : AppTheme.border,
                              ),
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
                    const SizedBox(height: 14),
                    Text(
                      'Giá bán',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
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
                        const SizedBox(width: 9),
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
                    const SizedBox(height: 14),
                    Row(
                      key: const Key('product-quantity-row'),
                      children: [
                        Expanded(
                          child: Text(
                            'Số lượng',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _QuantityStepper(
                          quantity: quantity,
                          onChanged: (value) {
                            setSheetState(() => quantity = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('product-add-button'),
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
                  ],
                ),
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
    final groups = _visibleGroups(metadata);
    final shownGroups = groups.take(_visibleGroupCount).toList(growable: false);
    _scheduleVisiblePriceHydration();
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
                mainAxisExtent: 188,
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
                  onOpen: () => _openGroup(group, selected),
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
    required this.onOpen,
  });

  final CatalogProductGroup group;
  final CustomerCatalogItem selected;
  final CatalogMetadataIndex metadata;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasPrice =
        selected.price.isAvailable && selected.price.amount != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CatalogProductVisual(
                  item: selected,
                  metadata: metadata,
                  size: 96,
                  borderRadius: 14,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                group.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                _priceLabel(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: hasPrice
                      ? AppTheme.brandDark
                      : const Color(0xFF9A6B00),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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
          color: selected ? AppTheme.brandSoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.brand : AppTheme.border,
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
                    : AppTheme.brandDark,
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
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Giảm số lượng',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            onPressed: quantity <= 1 ? null : () => onChanged(quantity - 1),
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            tooltip: 'Tăng số lượng',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
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
