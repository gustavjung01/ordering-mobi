import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../../../shared/formatters.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.repository});

  final CustomerOrderingRepository repository;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, CustomerCatalogItem?> _products = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_repositoryChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_repositoryChanged);
    super.dispose();
  }

  void _repositoryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts() async {
    final skus = widget.repository.cart.lines.map((line) => line.sku).toList();
    if (skus.isEmpty) {
      if (mounted) {
        setState(() {
          _products = const {};
          _loading = false;
          _error = null;

        });
      }
      return;
    }

    try {
      final items = await widget.repository.productsForSkus(skus);
      final map = <String, CustomerCatalogItem?>{};
      for (var index = 0; index < skus.length; index += 1) {
        map[skus[index]] = items[index];
      }
      if (mounted) {
        setState(() {
          _products = map;
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
          _error = 'Không tải được thông tin sản phẩm trong giỏ.';

        });
      }
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa toàn bộ giỏ hàng?'),
        content: const Text(
          'Tất cả sản phẩm đang chọn sẽ bị xóa khỏi giỏ hàng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.clearCart();
      if (mounted) setState(() => _products = const {});
    }
  }

  Future<void> _openCheckout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CheckoutScreen(repository: widget.repository),
      ),
    );
    if (mounted) await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.repository.cart;
    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ hàng')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _loadProducts)
          : cart.lines.isEmpty
          ? const _EmptyCart()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${cart.lines.length} dòng · ${cart.totalQuantity} sản phẩm',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _confirmClear,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Xóa tất cả'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final line in cart.lines)
                  _CartLineCard(
                    line: line,
                    product: _products[line.sku],
                    repository: widget.repository,
                  ),
                const SizedBox(height: 12),
                _CartSummary(
                  cart: cart,
                  products: _products,
                  onCheckout: _openCheckout,
                ),
              ],
            ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.product,
    required this.repository,
  });

  final CartLine line;
  final CustomerCatalogItem? product;
  final CustomerOrderingRepository repository;

  @override
  Widget build(BuildContext context) {
    final amount = product?.price.status == 'available'
        ? product?.price.amount
        : null;
    final unit = product?.unitCode?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?.name ?? 'Sản phẩm không còn',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (product?.variantName.trim().isNotEmpty == true)
                            product!.variantName,
                          if (unit != null && unit.isNotEmpty) unit,
                          line.sku,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa sản phẩm',
                  onPressed: () => repository.removeCartLine(line.sku),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: line.quantity <= 1
                      ? null
                      : () => repository.updateCartLine(
                          line.sku,
                          quantity: line.quantity - 1,
                        ),
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 54,
                  child: Text(
                    '${line.quantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: line.quantity >= 999
                      ? null
                      : () => repository.updateCartLine(
                          line.sku,
                          quantity: line.quantity + 1,
                        ),
                  icon: const Icon(Icons.add_rounded),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount == null
                          ? 'Chờ xác nhận giá'
                          : formatVnd(amount * line.quantity),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (amount != null)
                      Text(
                        '${formatVnd(amount)} / ${unit?.isNotEmpty == true ? unit : 'đơn vị'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey(line.sku),
              initialValue: line.note,
              maxLength: 180,
              decoration: const InputDecoration(
                labelText: 'Ghi chú mặt hàng',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                repository.updateCartLine(line.sku, note: value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.cart,
    required this.products,
    required this.onCheckout,
  });

  final CustomerCart cart;
  final Map<String, CustomerCatalogItem?> products;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    var subtotal = 0.0;
    var pending = 0;
    for (final line in cart.lines) {
      final product = products[line.sku];
      final amount = product?.price.status == 'available'
          ? product?.price.amount
          : null;
      if (amount == null) {
        pending += 1;
      } else {
        subtotal += amount * line.quantity;
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tạm tính các dòng có giá')),
                Text(
                  formatVnd(subtotal),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (pending > 0) ...[
              const SizedBox(height: 8),
              Text('$pending dòng đang chờ xác nhận giá.'),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCheckout,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Xác nhận đơn'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 44),
            SizedBox(height: 12),
            Text('Giỏ hàng đang trống'),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
