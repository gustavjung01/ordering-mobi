import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../../shared/formatters.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.repository,
  });

  final String orderId;
  final CustomerOrderingRepository repository;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  CustomerOrder? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await widget.repository.getOrderById(widget.orderId);
      if (mounted) setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() {
        _loading = false;
        _error = error.message;
      });
    } on Object {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Không tải được chi tiết đơn hàng.';
      });
    }
  }

  Future<void> _cancel() async {
    final order = _order;
    if (order == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text(
          'Sau khi xác nhận, hệ thống sẽ gửi yêu cầu hủy đơn này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ đơn'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final cancelled = await widget.repository.cancelOrder(order.id);
      if (mounted) setState(() {
        _order = cancelled;
        _notice = 'Đơn hàng đã được hủy.';
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) setState(() => _error = 'Không hủy được đơn lúc này.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder() async {
    final order = _order;
    if (order == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.repository.reorderOrder(order.id);
      if (!mounted) return;
      if (result.skippedLineCount > 0) {
        setState(() {
          _notice =
              'Đã thêm ${result.addedLineCount} mặt hàng vào giỏ. '
              '${result.skippedLineCount} mặt hàng hiện không khả dụng.';
        });
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CartScreen(repository: widget.repository),
          ),
        );
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) setState(() => _error = 'Không thể đặt lại đơn lúc này.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: AppBar(title: Text('Chi tiết đơn')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đơn')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error ?? 'Không tìm thấy đơn hàng.'),
          ),
        ),
      );
    }

    final order = _order!;
    return Scaffold(
      appBar: AppBar(title: Text(order.code)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.code,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(formatDateTime(order.submittedAt)),
                  const SizedBox(height: 10),
                  Chip(label: Text(orderStatusLabel(order.status))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Sản phẩm đã đặt',
            child: Column(
              children: [
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${line.productName}\n'
                            '${line.quantity} ${line.unit}'
                            '${line.note.isEmpty ? '' : ' · ${line.note}'}',
                          ),
                        ),
                        Text(
                          line.unitPrice == null
                              ? 'Chờ giá'
                              : formatVnd(line.unitPrice! * line.quantity),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(child: Text('Tạm tính các dòng có giá')),
                    Text(
                      formatVnd(order.pricedSubtotal),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (order.hasPendingPrice)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Tổng chưa gồm các mặt hàng chờ xác nhận giá.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Nhận hàng',
            child: Text(
              '${order.address.label}\n'
              '${order.address.recipientName} · ${order.address.phone}\n'
              '${order.address.addressLine}'
              '${order.orderNote.isEmpty ? '' : '\nGhi chú đơn: ${order.orderNote}'}',
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Tiến trình đơn hàng',
            child: Column(
              children: [
                for (final event in order.statusTimeline)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline_rounded),
                    title: Text(orderStatusLabel(event.status)),
                    subtitle: Text(
                      '${formatDateTime(event.at)}'
                      '${event.note.isEmpty ? '' : '\n${event.note}'}',
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_notice!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _reorder,
            icon: const Icon(Icons.replay_rounded),
            label: Text(_busy ? 'Đang xử lý...' : 'Đặt lại đơn này'),
          ),
          if (order.isCancellable) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Hủy đơn'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
