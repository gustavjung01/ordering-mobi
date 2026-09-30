import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../shared/formatters.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../products/domain/catalog_product_metadata.dart';
import '../../products/presentation/catalog_product_visual.dart';
import 'order_detail_screen.dart';

enum _OrdersView { orders, purchasedProducts }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.repository});

  final CustomerOrderingRepository repository;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  List<CustomerOrder> _orders = const [];
  List<_PurchasedProduct> _purchasedProducts = const [];
  CatalogMetadataIndex? _metadata;
  _OrdersView _view = _OrdersView.orders;
  String _status = 'ALL';
  bool _loading = true;
  String? _error;

  static const _statuses = <String>[
    'ALL',
    'SUBMITTED',
    'RECEIVED',
    'CONFIRMED',
    'PROCESSING',
    'DELIVERING',
    'COMPLETED',
    'REJECTED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_searchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_searchChanged)
      ..dispose();
    super.dispose();
  }

  void _searchChanged() => setState(() {});

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final orders = await widget.repository.listOrders();
      orders.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      CatalogMetadataIndex? metadata;
      try {
        metadata = await CatalogMetadataIndex.shared();
      } on Object {
        metadata = null;
      }

      var purchased = const <_PurchasedProduct>[];
      try {
        purchased = await _buildPurchasedProducts(orders);
      } on Object {
        purchased = _buildPurchasedProductsWithoutCatalog(orders);
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _purchasedProducts = purchased;
          _metadata = metadata;
          _loading = false;
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không tải được danh sách đơn hàng.';
        });
      }
    }
  }

  Future<List<_PurchasedProduct>> _buildPurchasedProducts(
    List<CustomerOrder> orders,
  ) async {
    final history = _purchasedHistory(orders);
    if (history.isEmpty) return const [];

    final products = await widget.repository.productsForSkus(history.keys);
    final available = products.whereType<CustomerCatalogItem>().toList();

    List<CustomerCatalogItem> priced = available;
    if (available.isNotEmpty) {
      try {
        priced = await widget.repository.refreshCatalogPrices(available);
      } on Object {
        priced = available;
      }
    }

    final catalogBySku = <String, CustomerCatalogItem>{
      for (final item in priced) item.sku.trim().toUpperCase(): item,
    };

    return [
      for (final entry in history.entries)
        _PurchasedProduct(
          sku: entry.key,
          latestLine: entry.value.latestLine,
          latestAt: entry.value.latestAt,
          product: catalogBySku[entry.key],
        ),
    ];
  }

  List<_PurchasedProduct> _buildPurchasedProductsWithoutCatalog(
    List<CustomerOrder> orders,
  ) {
    return [
      for (final entry in _purchasedHistory(orders).entries)
        _PurchasedProduct(
          sku: entry.key,
          latestLine: entry.value.latestLine,
          latestAt: entry.value.latestAt,
          product: null,
        ),
    ];
  }

  Map<String, _PurchasedHistory> _purchasedHistory(
    List<CustomerOrder> orders,
  ) {
    final history = <String, _PurchasedHistory>{};
    for (final order in orders) {
      for (final line in order.lines) {
        final sku = line.sku.trim().toUpperCase();
        if (sku.isEmpty || history.containsKey(sku)) continue;
        history[sku] = _PurchasedHistory(
          latestLine: line,
          latestAt: order.submittedAt,
        );
      }
    }
    return history;
  }

  List<CustomerOrder> get _visibleOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _orders
        .where((order) {
          if (_status != 'ALL' && order.status != _status) return false;
          if (query.isEmpty) return true;
          final text = [
            order.code,
            order.address.label,
            order.address.recipientName,
            for (final line in order.lines) line.sku,
            for (final line in order.lines) line.productName,
          ].join(' ').toLowerCase();
          return text.contains(query);
        })
        .toList(growable: false);
  }

  List<_PurchasedProduct> get _visiblePurchasedProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _purchasedProducts;

    return _purchasedProducts.where((item) {
      final product = item.product;
      return [
        item.sku,
        item.latestLine.productName,
        item.latestLine.packaging,
        item.latestLine.unit,
        product?.name ?? '',
        product?.variantName ?? '',
        product?.brandName ?? '',
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> _openOrder(CustomerOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(
          orderId: order.id,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _reorderProduct(_PurchasedProduct purchased) async {
    final product = purchased.product;
    if (product == null) return;

    try {
      await widget.repository.addProduct(
        product,
        quantity: purchased.latestLine.quantity,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm ${purchased.latestLine.quantity} ${product.unitLabel} vào giỏ.',
          ),
        ),
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final visibleOrders = _visibleOrders;
    final visiblePurchased = _visiblePurchasedProducts;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_OrdersView>(
            key: const Key('orders-sub-tabs'),
            segments: const [
              ButtonSegment(
                value: _OrdersView.orders,
                icon: Icon(Icons.receipt_long_outlined),
                label: Text('Đơn hàng'),
              ),
              ButtonSegment(
                value: _OrdersView.purchasedProducts,
                icon: Icon(Icons.history_rounded),
                label: Text('Sản phẩm đã mua'),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _view = selection.first);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: _view == _OrdersView.orders
                  ? 'Tìm mã đơn hoặc sản phẩm'
                  : 'Tìm sản phẩm đã mua',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_view == _OrdersView.orders) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in _statuses)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _status == status,
                        label: Text(
                          status == 'ALL' ? 'Tất cả' : orderStatusLabel(status),
                        ),
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_orders.isEmpty)
              const _EmptyOrders()
            else if (visibleOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Không có đơn phù hợp.')),
              )
            else
              for (final order in visibleOrders)
                _OrderCard(order: order, onTap: () => _openOrder(order)),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'Đặt lại nhanh theo số lượng của lần mua gần nhất.',
              style: TextStyle(color: Color(0xFF6C757D), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_purchasedProducts.isEmpty)
              const _EmptyPurchasedProducts()
            else if (visiblePurchased.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Không có sản phẩm phù hợp.')),
              )
            else
              for (final purchased in visiblePurchased)
                _PurchasedProductCard(
                  purchased: purchased,
                  metadata: _metadata,
                  onReorder: purchased.product == null
                      ? null
                      : () => _reorderProduct(purchased),
                ),
          ],
        ],
      ),
    );
  }
}

class _PurchasedHistory {
  const _PurchasedHistory({
    required this.latestLine,
    required this.latestAt,
  });

  final CustomerOrderLine latestLine;
  final DateTime latestAt;
}

class _PurchasedProduct {
  const _PurchasedProduct({
    required this.sku,
    required this.latestLine,
    required this.latestAt,
    required this.product,
  });

  final String sku;
  final CustomerOrderLine latestLine;
  final DateTime latestAt;
  final CustomerCatalogItem? product;
}

class _PurchasedProductCard extends StatelessWidget {
  const _PurchasedProductCard({
    required this.purchased,
    required this.metadata,
    required this.onReorder,
  });

  final _PurchasedProduct purchased;
  final CatalogMetadataIndex? metadata;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final product = purchased.product;
    final displayName = product?.name.trim().isNotEmpty == true
        ? product!.name.trim()
        : purchased.latestLine.productName;
    final metadataVariant = product == null
        ? ''
        : metadata?.variantFor(product).trim() ?? '';
    final variant = metadataVariant.isNotEmpty
        ? metadataVariant
        : product?.variantName.trim().isNotEmpty == true
        ? product!.variantName.trim()
        : purchased.latestLine.packaging;
    final unit = product?.unitLabel ?? purchased.latestLine.unit;
    final price = product?.price;
    final priceText = price?.isAvailable == true
        ? formatVnd(price!.amount!)
        : purchased.latestLine.unitPrice == null
        ? 'Chờ xác nhận giá'
        : 'Giá lần gần nhất ${formatVnd(purchased.latestLine.unitPrice!)}';

    return Card(
      key: ValueKey('purchased-product-${purchased.sku}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product != null && metadata != null)
              CatalogProductVisual(
                item: product,
                metadata: metadata!,
                size: 70,
                borderRadius: 14,
              )
            else
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4EAE5)),
                ),
                child: const Icon(Icons.shopping_bag_outlined, size: 28),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (variant.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      variant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: Color(0xFF0F6B3D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lần gần nhất: ${purchased.latestLine.quantity} $unit · ${formatDateTime(purchased.latestAt)}',
                    style: const TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      key: ValueKey('reorder-product-${purchased.sku}'),
                      onPressed: onReorder,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: Text(
                        product == null ? 'Tạm ngừng bán' : 'Đặt lại',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final CustomerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.code,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(label: Text(orderStatusLabel(order.status))),
                ],
              ),
              Text(formatDateTime(order.submittedAt)),
              const SizedBox(height: 10),
              Text(
                '${order.lines.length} mặt hàng · ${order.totalQuantity} đơn vị',
              ),
              const SizedBox(height: 4),
              Text(
                formatVnd(order.pricedSubtotal),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (order.hasPendingPrice)
                const Text('Có mặt hàng chờ xác nhận giá.'),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 44),
            SizedBox(height: 12),
            Text('Chưa có đơn hàng'),
          ],
        ),
      ),
    );
  }
}

class _EmptyPurchasedProducts extends StatelessWidget {
  const _EmptyPurchasedProducts();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 44),
            SizedBox(height: 12),
            Text('Chưa có sản phẩm đã mua'),
          ],
        ),
      ),
    );
  }
}
