import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import 'order_detail_screen.dart';
import '../../../shared/formatters.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.repository});

  final CustomerOrderingRepository repository;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  List<CustomerOrder> _orders = const [];
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
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await widget.repository.listOrders();
      orders.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      if (mounted) setState(() {
        _orders = orders;
        _loading = false;
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() {
        _loading = false;
        _error = error.message;
      });
    } on Object {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Không tải được danh sách đơn hàng.';
      });
    }
  }

  List<CustomerOrder> get _visibleOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _orders.where((order) {
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

    final visible = _visibleOrders;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Tìm mã đơn hoặc sản phẩm',
              border: OutlineInputBorder(),
            ),
          ),
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
                        status == 'ALL'
                            ? 'Tất cả'
                            : orderStatusLabel(status),
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
          else if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Không có đơn phù hợp.')),
            )
          else
            for (final order in visible)
              _OrderCard(order: order, onTap: () => _openOrder(order)),
        ],
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
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Chip(label: Text(orderStatusLabel(order.status))),
                ],
              ),
              Text(formatDateTime(order.submittedAt)),
              const SizedBox(height: 10),
              Text('${order.lines.length} mặt hàng · ${order.totalQuantity} đơn vị'),
              const SizedBox(height: 4),
              Text(
                formatVnd(order.pricedSubtotal),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
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
