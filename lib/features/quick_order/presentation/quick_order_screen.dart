import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
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
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  String? _addingSku;
  int _requestVersion = 0;
  final Set<String> _requestedPriceVariants = {};

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
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _metadata = metadata;
        _items = reset
            ? dedupeCatalogItems(page.items)
            : dedupeCatalogItems([..._items, ...page.items]);
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      unawaited(_hydratePrices(page.items));
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

  Future<void> _hydratePrices(Iterable<CustomerCatalogItem> source) async {
    final pending = source
        .where((item) => item.variantId?.trim().isNotEmpty == true)
        .where((item) => _requestedPriceVariants.add(item.variantId!.trim()))
        .toList(growable: false);
    if (pending.isEmpty) return;

    try {
      final resolved = await widget.repository.refreshCatalogPrices(pending);
      if (!mounted) return;
      final bySku = {for (final item in resolved) item.sku: item};
      setState(() {
        _items = [for (final item in _items) bySku[item.sku] ?? item];
      });
    } on Object {
      for (final item in pending) {
        final variantId = item.variantId?.trim();
        if (variantId != null) _requestedPriceVariants.remove(variantId);
      }
    }
  }

  Future<void> _add(CustomerCatalogItem item) async {
    if (_addingSku != null) return;
    setState(() => _addingSku = item.sku);
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
    } finally {
      if (mounted) setState(() => _addingSku = null);
    }
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
              child: Text(
                loadingMore ? 'Đang tải thêm...' : 'Xem thêm sản phẩm',
              ),
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
    final hasPrice = item.price.isAvailable && item.price.amount != null;

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
                          ? AppTheme.accent.withAlpha(48)
                          : AppTheme.brandSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.purchaseMode == 'case' ? 'THÙNG' : 'LẺ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: item.purchaseMode == 'case'
                            ? const Color(0xFF7A5A00)
                            : AppTheme.brandDark,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: hasPrice
                          ? AppTheme.brandDark
                          : const Color(0xFF9A6B00),
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
              child: IconButton.filled(
                tooltip: 'Thêm vào giỏ',
                onPressed: busy ? null : onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.brand,
                  disabledForegroundColor: Colors.white70,
                ),
                icon: adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
