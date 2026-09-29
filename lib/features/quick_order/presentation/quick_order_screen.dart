import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../shared/formatters.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../products/domain/catalog_product_metadata.dart';
import '../../products/presentation/catalog_product_visual.dart';

class QuickOrderScreen extends StatefulWidget {
  const QuickOrderScreen({super.key, required this.repository});

  final CustomerOrderingRepository repository;

  @override
  State<QuickOrderScreen> createState() => _QuickOrderScreenState();
}

class _QuickOrderScreenState extends State<QuickOrderScreen> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  CatalogMetadataIndex? _metadata;
  List<CustomerCatalogItem> _items = const [];
  List<CustomerCategory> _categories = const [];
  String? _categoryId;
  String? _subcategoryId;
  String? _purchaseMode;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  String? _addingSku;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? get _selectedCategoryId => _subcategoryId ?? _categoryId;

  List<CustomerCategory> get _rootCategories {
    final ids = _categories.map((item) => item.id).toSet();
    return _categories
        .where(
          (item) =>
              item.parentCategoryId == null ||
              !ids.contains(item.parentCategoryId),
        )
        .toList(growable: false);
  }

  List<CustomerCategory> get _subcategories {
    if (_categoryId == null) return const [];
    return _categories
        .where((item) => item.parentCategoryId == _categoryId)
        .toList(growable: false);
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    final version = ++_requestVersion;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final metadata = _metadata ?? await CatalogMetadataIndex.shared();
      final page = await widget.repository.listCatalog(
        limit: 50,
        offset: reset ? 0 : _items.length,
        search: _searchController.text,
        categoryId: _selectedCategoryId,
        purchaseMode: _purchaseMode,
        includeCategories: reset && _categories.isEmpty,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _metadata = metadata;
        _items = reset
            ? dedupeCatalogItems(page.items)
            : dedupeCatalogItems([..._items, ...page.items]);
        if (page.categories.isNotEmpty) _categories = page.categories;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiFailure catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Không tải được danh sách đặt nhanh.';
      });
    }
  }

  Future<void> _add(CustomerCatalogItem item) async {
    if (_addingSku != null) return;
    setState(() => _addingSku = item.sku);
    try {
      await widget.repository.addProduct(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm \${item.name} vào giỏ.')),
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _addingSku = null);
    }
  }

  void _selectMode(String? mode) {
    setState(() => _purchaseMode = mode);
    _load(reset: true);
  }

  void _selectCategory(String? id) {
    setState(() {
      _categoryId = id;
      _subcategoryId = null;
    });
    _load(reset: true);
  }

  void _selectSubcategory(String? id) {
    setState(() => _subcategoryId = id);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Tìm tên, mã hàng, nhãn hàng, nhóm hàng',
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();
                        _load(reset: true);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: _QuickFilterRail(
                    purchaseMode: _purchaseMode,
                    categories: _rootCategories,
                    subcategories: _subcategories,
                    categoryId: _categoryId,
                    subcategoryId: _subcategoryId,
                    onSelectMode: _selectMode,
                    onSelectCategory: _selectCategory,
                    onSelectSubcategory: _selectSubcategory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickResults(
                    loading: _loading || metadata == null,
                    loadingMore: _loadingMore,
                    error: _error,
                    items: _items,
                    metadata: metadata,
                    hasMore: _hasMore,
                    addingSku: _addingSku,
                    onRetry: () => _load(reset: true),
                    onLoadMore: () => _load(reset: false),
                    onAdd: _add,
                    onRefresh: () => _load(reset: true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterRail extends StatelessWidget {
  const _QuickFilterRail({
    required this.purchaseMode,
    required this.categories,
    required this.subcategories,
    required this.categoryId,
    required this.subcategoryId,
    required this.onSelectMode,
    required this.onSelectCategory,
    required this.onSelectSubcategory,
  });

  final String? purchaseMode;
  final List<CustomerCategory> categories;
  final List<CustomerCategory> subcategories;
  final String? categoryId;
  final String? subcategoryId;
  final ValueChanged<String?> onSelectMode;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<String?> onSelectSubcategory;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7FAF7),
      borderRadius: BorderRadius.circular(16),
      child: ListView(
        padding: const EdgeInsets.all(6),
        children: [
          _RailLabel(
            icon: Icons.grid_view_rounded,
            label: 'Tất cả',
            selected: purchaseMode == null,
            onTap: () => onSelectMode(null),
          ),
          _RailLabel(
            icon: Icons.shopping_bag_outlined,
            label: 'Mua lẻ',
            selected: purchaseMode == 'retail',
            onTap: () => onSelectMode('retail'),
          ),
          _RailLabel(
            icon: Icons.inventory_2_outlined,
            label: 'Mua thùng',
            selected: purchaseMode == 'case',
            onTap: () => onSelectMode('case'),
          ),
          if (categories.isNotEmpty) ...[
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Nhóm sản phẩm',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            for (final category in categories)
              _RailLabel(
                icon: Icons.sell_outlined,
                label: category.shortName,
                selected: categoryId == category.id,
                onTap: () => onSelectCategory(
                  categoryId == category.id ? null : category.id,
                ),
              ),
          ],
          if (subcategories.isNotEmpty) ...[
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Nhóm hàng',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            _RailLabel(
              icon: Icons.layers_outlined,
              label: 'Tất cả',
              selected: subcategoryId == null,
              onTap: () => onSelectSubcategory(null),
            ),
            for (final category in subcategories)
              _RailLabel(
                icon: Icons.sell_outlined,
                label: category.shortName,
                selected: subcategoryId == category.id,
                onTap: () => onSelectSubcategory(category.id),
              ),
          ],
        ],
      ),
    );
  }
}

class _RailLabel extends StatelessWidget {
  const _RailLabel({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickResults extends StatelessWidget {
  const _QuickResults({
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.items,
    required this.metadata,
    required this.hasMore,
    required this.addingSku,
    required this.onRetry,
    required this.onLoadMore,
    required this.onAdd,
    required this.onRefresh,
  });

  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<CustomerCatalogItem> items;
  final CatalogMetadataIndex? metadata;
  final bool hasMore;
  final String? addingSku;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<CustomerCatalogItem> onAdd;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading || metadata == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return _QuickState(
        icon: Icons.error_outline_rounded,
        message: error!,
        action: FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
      );
    }
    if (items.isEmpty) {
      return const _QuickState(
        icon: Icons.inventory_2_outlined,
        message: 'Không tìm thấy sản phẩm.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: items.length + (hasMore ? 1 : 0) + (error != null ? 1 : 0),
        itemBuilder: (context, index) {
          var cursor = index;
          if (error != null) {
            if (cursor == 0) {
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  error!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            cursor -= 1;
          }
          if (cursor < items.length) {
            final item = items[cursor];
            return _QuickProductRow(
              item: item,
              metadata: metadata!,
              busy: addingSku != null,
              adding: addingSku == item.sku,
              onAdd: () => onAdd(item),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: FilledButton.tonal(
              onPressed: loadingMore ? null : onLoadMore,
              child: Text(loadingMore ? 'Đang tải thêm...' : 'Xem thêm sản phẩm'),
            ),
          );
        },
      ),
    );
  }
}

class _QuickProductRow extends StatelessWidget {
  const _QuickProductRow({
    required this.item,
    required this.metadata,
    required this.busy,
    required this.adding,
    required this.onAdd,
  });

  final CustomerCatalogItem item;
  final CatalogMetadataIndex metadata;
  final bool busy;
  final bool adding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final variant = metadata.variantFor(item);
    final size = metadata.sizeFor(item);
    final detail = [
      if (variant.isNotEmpty) variant,
      if (size.isNotEmpty && size != variant) size,
      item.unitLabel,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            CatalogProductVisual(
              item: item,
              metadata: metadata,
              size: 58,
              borderRadius: 12,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.purchaseMode == 'case'
                          ? const Color(0xFFFFF3D6)
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.purchaseMode == 'case' ? 'THÙNG' : 'LẺ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _quickPrice(item),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton.filledTonal(
                tooltip: 'Thêm vào giỏ',
                onPressed: busy ? null : onAdd,
                icon: adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickState extends StatelessWidget {
  const _QuickState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

String _quickPrice(CustomerCatalogItem item) {
  final amount = item.price.isAvailable ? item.price.amount : null;
  return amount == null ? 'Chờ xác nhận giá' : formatVnd(amount);
}
