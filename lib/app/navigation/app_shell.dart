import 'package:flutter/material.dart';

import '../../core/network/customer_portal_models.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/ordering/data/customer_ordering_repository.dart';
import '../../features/products/presentation/product_catalog_screen.dart';
import '../../features/quick_order/presentation/quick_order_screen.dart';

typedef SignOutCallback = Future<void> Function();

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.profile,
    this.repository,
    this.customerDisplayName,
    this.onSignOut,
  });

  final CustomerProfile? profile;
  final CustomerOrderingRepository? repository;
  final String? customerDisplayName;
  final SignOutCallback? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  static const _destinations = <_AppDestination>[
    _AppDestination(
      label: 'Trang chủ',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      title: 'Hưng Phát Đặt Hàng',
    ),
    _AppDestination(
      label: 'Sản phẩm',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      title: 'Sản phẩm',
    ),
    _AppDestination(
      label: 'Đặt nhanh',
      icon: Icons.add_shopping_cart_outlined,
      selectedIcon: Icons.add_shopping_cart_rounded,
      title: 'Đặt nhanh',
    ),
    _AppDestination(
      label: 'Đơn hàng',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      title: 'Đơn hàng',
    ),
    _AppDestination(
      label: 'Tài khoản',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      title: 'Tài khoản',
    ),
  ];

  void _selectTab(int index) {
    if (index < 0 || index >= _destinations.length) return;
    setState(() => _index = index);
  }

  Future<void> _openCart() async {
    final repository = widget.repository;
    if (repository == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartScreen(repository: repository),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_index];
    final repository = widget.repository;
    final profile = widget.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.title),
        actions: [
          if (repository != null)
            AnimatedBuilder(
              animation: repository,
              builder: (context, _) => Badge(
                isLabelVisible: repository.cartQuantity > 0,
                label: Text('${repository.cartQuantity}'),
                child: IconButton(
                  tooltip: 'Giỏ hàng',
                  onPressed: _openCart,
                  icon: const Icon(Icons.shopping_basket_outlined),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: repository != null && profile != null
            ? _buildBusinessPage(repository, profile)
            : _PlaceholderPage(
                destination: destination,
                customerDisplayName: widget.customerDisplayName,
                onSignOut: widget.onSignOut,
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: [
          for (final item in _destinations)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessPage(
    CustomerOrderingRepository repository,
    CustomerProfile profile,
  ) {
    return switch (_index) {
      0 => HomeScreen(
          profile: profile,
          repository: repository,
          onSelectTab: _selectTab,
        ),
      1 => ProductCatalogScreen(repository: repository),
      2 => QuickOrderScreen(repository: repository),
      3 => OrdersScreen(repository: repository),
      _ => AccountScreen(profile: profile, onSignOut: widget.onSignOut),
    };
  }
}

class _PlaceholderPage extends StatefulWidget {
  const _PlaceholderPage({
    required this.destination,
    required this.customerDisplayName,
    required this.onSignOut,
  });

  final _AppDestination destination;
  final String? customerDisplayName;
  final SignOutCallback? onSignOut;

  @override
  State<_PlaceholderPage> createState() => _PlaceholderPageState();
}

class _PlaceholderPageState extends State<_PlaceholderPage> {
  var _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut || widget.onSignOut == null) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut!();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.customerDisplayName?.trim();
    final message =
        widget.destination.label == 'Trang chủ' &&
            displayName != null &&
            displayName.isNotEmpty
        ? 'Chào mừng $displayName đến hệ thống đặt hàng Hưng Phát.'
        : switch (widget.destination.label) {
            'Sản phẩm' =>
              'Danh mục sản phẩm sẽ hiển thị theo tài khoản khách hàng.',
            'Đặt nhanh' => 'Tạo đơn nhanh từ danh mục hàng được phép đặt.',
            'Đơn hàng' => 'Theo dõi đơn hàng và trạng thái xử lý.',
            'Tài khoản' => 'Thông tin tài khoản và thiết lập sử dụng.',
            _ => 'Chào mừng anh/chị đến hệ thống đặt hàng Hưng Phát.',
          };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.destination.selectedIcon,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  widget.destination.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(message),
                if (widget.destination.label == 'Tài khoản' &&
                    widget.onSignOut != null) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _signingOut ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      _signingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.title,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String title;
}
