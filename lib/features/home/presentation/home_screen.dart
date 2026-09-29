import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../../shared/formatters.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.repository,
    required this.onSelectTab,
    this.onOpenAssistant,
  });

  final CustomerProfile profile;
  final CustomerOrderingRepository repository;
  final ValueChanged<int> onSelectTab;
  final VoidCallback? onOpenAssistant;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CustomerOrder> _orders = const [];
  List<CustomerCatalogItem> _products = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.repository.listOrders(),
        widget.repository.listCatalog(limit: 6, includeCategories: false),
      ]);
      final orders = results[0] as List<CustomerOrder>;
      orders.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      if (mounted) {
        setState(() {
          _orders = orders;
          _products = (results[1] as CustomerCatalogPage).items;
          _loading = false;
          _error = null;
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
          _error = 'Không tải được dữ liệu trang chủ.';
        });
      }
    }
  }

  Future<void> _openCart() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CartScreen(repository: widget.repository),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final latest = _orders.isEmpty ? null : _orders.first;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, ${widget.profile.displayName}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.profile.outletName.isEmpty
                        ? widget.profile.customerCode
                        : '${widget.profile.outletName} · ${widget.profile.customerCode}',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => widget.onSelectTab(2),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('Đặt nhanh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openCart,
                        icon: const Icon(Icons.shopping_basket_outlined),
                        label: Text(
                          'Giỏ hàng (${widget.repository.cartQuantity})',
                        ),
                      ),
                      if (widget.onOpenAssistant != null)
                        OutlinedButton.icon(
                          onPressed: widget.onOpenAssistant,
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Hỏi Hưng Phát'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _QuickActions(onSelectTab: widget.onSelectTab),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(_error!),
                    const SizedBox(height: 10),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                ),
              ),
            )
          else ...[
            if (latest != null)
              _HomeSection(
                title: 'Đơn gần nhất',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(latest.code),
                  subtitle: Text(
                    '${orderStatusLabel(latest.status)} · '
                    '${formatDateTime(latest.submittedAt)}',
                  ),
                  trailing: Text(formatVnd(latest.pricedSubtotal)),
                  onTap: () => widget.onSelectTab(3),
                ),
              ),
            if (_products.isNotEmpty) ...[
              const SizedBox(height: 14),
              _HomeSection(
                title: 'Sản phẩm',
                child: Column(
                  children: [
                    for (final item in _products.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        subtitle: Text(item.variantName),
                        trailing: Text(
                          item.price.amount == null
                              ? 'Chờ giá'
                              : formatVnd(item.price.amount!),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => widget.onSelectTab(1),
                        child: const Text('Xem tất cả sản phẩm'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.inventory_2_outlined,
            title: 'Sản phẩm',
            onTap: () => onSelectTab(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.receipt_long_outlined,
            title: 'Đơn hàng',
            onTap: () => onSelectTab(3),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
