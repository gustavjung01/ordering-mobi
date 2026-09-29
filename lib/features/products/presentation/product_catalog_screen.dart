import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../../shared/formatters.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({
    super.key,
    required this.repository,
    this.quickOrder = false,
  });

  final CustomerOrderingRepository repository;
  final bool quickOrder;

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<CustomerCatalogItem> _items = const [];
  List<CustomerCategory> _categories = const [];
  String? _categoryId;
  String? _purchaseMode;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
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

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
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
      final page = await widget.repository.listCatalog(
        limit: 50,
        offset: reset ? 0 : _items.length,
        search: _searchController.text,
        categoryId: _categoryId,
        purchaseMode: _purchaseMode,
        includeCategories: reset,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _items = reset ? page.items : [..._items, ...page.items];
        if (reset && page.categories.isNotEmpty) _categories = page.categories;
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
        _error = 'Không tải được danh mục sản phẩm.';
      });
    }
  }

  Future<void> _add(CustomerCatalogItem item) async {
    try {
      await widget.repository.addProduct(item);
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: widget.quickOrder
                  ? 'Tìm sản phẩm đặt nhanh'
                  : 'Tìm sản phẩm',
              hintText: 'Tên, mã hàng hoặc nhãn hàng',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mode in const [
                  (value: null, label: 'Tất cả'),
                  (value: 'retail', label: 'Mua lẻ'),
                  (value: 'case', label: 'Mua thùng'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _purchaseMode == mode.value,
                      label: Text(mode.label),
                      onSelected: (_) {
                        setState(() => _purchaseMode = mode.value);
                        _load(reset: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _categoryId == null,
                      label: const Text('Tất cả nhóm'),
                      onSelected: (_) {
                        setState(() => _categoryId = null);
                        _load(reset: true);
                      },
                    ),
                  ),
                  for (final category in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _categoryId == category.id,
                        label: Text(category.shortName),
                        onSelected: (_) {
                          setState(() => _categoryId = category.id);
                          _load(reset: true);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _CatalogState(
              icon: Icons.error_outline_rounded,
              message: _error!,
              action: FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('Thử lại'),
              ),
            )
          else if (_items.isEmpty)
            const _CatalogState(
              icon: Icons.inventory_2_outlined,
              message: 'Không tìm thấy sản phẩm.',
            )
          else ...[
            for (final item in _items)
              _ProductCard(item: item, onAdd: () => _add(item)),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : () => _load(reset: false),
                  child: Text(
                    _loadingMore ? 'Đang tải...' : 'Xem thêm sản phẩm',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.onAdd});

  final CustomerCatalogItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final amount = item.price.status == 'available' ? item.price.amount : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Icon(
                item.purchaseMode == 'case'
                    ? Icons.inventory_2_outlined
                    : Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.brandName?.trim().isNotEmpty == true)
                    Text(
                      item.brandName!,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (item.variantName.trim().isNotEmpty) item.variantName,
                      item.purchaseMode == 'case' ? 'Mua thùng' : 'Mua lẻ',
                      item.unitLabel,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amount == null ? 'Chờ xác nhận giá' : formatVnd(amount),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: 'Thêm vào giỏ',
              onPressed: onAdd,
              icon: const Icon(Icons.add_shopping_cart_rounded),
            ),
          ],
        ),
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
