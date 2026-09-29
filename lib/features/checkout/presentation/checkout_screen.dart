import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../orders/presentation/order_success_screen.dart';
import '../../../shared/formatters.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.repository});

  final CustomerOrderingRepository repository;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _noteController = TextEditingController();
  Map<String, CustomerCatalogItem?> _products = const {};
  List<DeliveryAddress> _addresses = const [];
  String? _addressId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cart = widget.repository.cart;
      final results = await Future.wait<Object>([
        widget.repository.productsForSkus(cart.lines.map((line) => line.sku)),
        widget.repository.listDeliveryAddresses(),
      ]);
      final products = results[0] as List<CustomerCatalogItem?>;
      final addresses = results[1] as List<DeliveryAddress>;
      final map = <String, CustomerCatalogItem?>{};
      for (var index = 0; index < cart.lines.length; index += 1) {
        map[cart.lines[index].sku] = products[index];
      }

      final draft = widget.repository.checkoutDraft;
      final draftExists = addresses.any((item) => item.id == draft.addressId);
      String? selected;
      if (draftExists) {
        selected = draft.addressId;
      } else {
        selected = addresses
            .where((item) => item.isDefault)
            .map((item) => item.id)
            .firstOrNull;
        selected ??= addresses.isEmpty ? null : addresses.first.id;
      }
      if (mounted) {
        _noteController.text = draft.orderNote;
        setState(() {
          _products = map;
          _addresses = addresses;
          _addressId = selected;
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
          _error = 'Không tải được thông tin xác nhận đơn.';
        });
      }
    }
  }

  Future<void> _chooseAddress(String? value) async {
    setState(() => _addressId = value);
    await widget.repository.saveCheckoutDraft(
      addressId: value,
      orderNote: _noteController.text,
    );
  }

  Future<void> _submit() async {
    if (_submitting || _addressId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.saveCheckoutDraft(
        addressId: _addressId,
        orderNote: _noteController.text,
      );
      final order = await widget.repository.submitOrder(
        addressId: _addressId!,
        orderNote: _noteController.text,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessScreen(
            order: order,
            repository: widget.repository,
          ),
        ),
      );
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) setState(() => _error = 'Không gửi được đơn hàng.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.repository.cart;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xác nhận đơn')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (cart.lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xác nhận đơn')),
        body: const Center(child: Text('Giỏ hàng đang trống.')),
      );
    }

    var subtotal = 0.0;
    var hasPendingPrice = false;
    for (final line in cart.lines) {
      final product = _products[line.sku];
      final amount = product?.price.status == 'available'
          ? product?.price.amount
          : null;
      if (amount == null) {
        hasPendingPrice = true;
      } else {
        subtotal += amount * line.quantity;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Địa chỉ nhận hàng',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_addresses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Tài khoản chưa có địa chỉ nhận hàng. '
                  'Vui lòng cập nhật thông tin khách hàng trước khi gửi đơn.',
                ),
              ),
            )
          else
            for (final address in _addresses)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _chooseAddress(address.id),
                  leading: Icon(
                    _addressId == address.id
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  title: Text(
                    '${address.label}${address.isDefault ? ' · Mặc định' : ''}',
                  ),
                  subtitle: Text(
                    '${address.recipientName} · ${address.phone}\n'
                    '${address.addressLine}',
                  ),
                ),
              ),
          const SizedBox(height: 14),
          Text(
            'Sản phẩm',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final line in cart.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${_products[line.sku]?.name ?? line.sku}\n'
                              '${line.quantity} ${_products[line.sku]?.unitCode ?? 'đơn vị'}'
                              '${line.note.isEmpty ? '' : ' · ${line.note}'}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(_lineAmount(line)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ghi chú toàn đơn',
              hintText: 'Ví dụ: giao buổi sáng, gọi trước khi giao...',
              border: OutlineInputBorder(),
            ),
            onTapOutside: (_) async {
              await widget.repository.saveCheckoutDraft(
                addressId: _addressId,
                orderNote: _noteController.text,
              );
              if (mounted) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
          ),
          Card(
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
                  if (hasPendingPrice) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Đơn có sản phẩm chưa có giá. Hưng Phát sẽ xác nhận '
                      'giá chính thức khi tiếp nhận.',
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting || _addressId == null
                        ? null
                        : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _submitting ? 'Đang gửi đơn...' : 'Gửi đơn hàng',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lineAmount(CartLine line) {
    final product = _products[line.sku];
    final amount = product?.price.status == 'available'
        ? product?.price.amount
        : null;
    return amount == null ? 'Chờ giá' : formatVnd(amount * line.quantity);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
