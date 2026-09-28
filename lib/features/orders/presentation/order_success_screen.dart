import 'package:flutter/material.dart';

import '../../../core/network/customer_portal_models.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import 'orders_screen.dart';
import '../../../shared/formatters.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({
    super.key,
    required this.order,
    required this.repository,
  });

  final CustomerOrder order;
  final CustomerOrderingRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Đặt hàng thành công'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 64,
          ),
          const SizedBox(height: 14),
          Text(
            'Hưng Phát đã nhận yêu cầu',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yêu cầu đặt hàng đã được ghi nhận. '
            'Trạng thái tiếp nhận và xác nhận sẽ được cập nhật trong đơn hàng.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mã đơn'),
                  Text(
                    order.code,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(formatDateTime(order.submittedAt)),
                  const Divider(height: 28),
                  Text('${order.lines.length} dòng · ${order.totalQuantity} sản phẩm'),
                  const SizedBox(height: 4),
                  Text('Tạm tính: ${formatVnd(order.pricedSubtotal)}'),
                  if (order.hasPendingPrice)
                    const Text('Có sản phẩm chờ Hưng Phát xác nhận giá.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(order.address.label),
              subtitle: Text(
                '${order.address.recipientName} · ${order.address.phone}\n'
                '${order.address.addressLine}',
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Về trang chủ'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Đơn hàng')),
                  body: OrdersScreen(repository: repository),
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Xem đơn hàng'),
          ),
        ],
      ),
    );
  }
}
