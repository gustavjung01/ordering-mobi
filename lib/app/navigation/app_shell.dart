import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

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
      message: 'Chào mừng anh/chị đến hệ thống đặt hàng Hưng Phát.',
    ),
    _AppDestination(
      label: 'Sản phẩm',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      title: 'Sản phẩm',
      message: 'Danh mục sản phẩm sẽ hiển thị theo tài khoản khách hàng.',
    ),
    _AppDestination(
      label: 'Đặt nhanh',
      icon: Icons.add_shopping_cart_outlined,
      selectedIcon: Icons.add_shopping_cart_rounded,
      title: 'Đặt nhanh',
      message: 'Tạo đơn nhanh từ danh mục hàng được phép đặt.',
    ),
    _AppDestination(
      label: 'Đơn hàng',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      title: 'Đơn hàng',
      message: 'Theo dõi đơn hàng và trạng thái xử lý.',
    ),
    _AppDestination(
      label: 'Tài khoản',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      title: 'Tài khoản',
      message: 'Thông tin tài khoản và thiết lập sử dụng.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_index];
    return Scaffold(
      appBar: AppBar(title: Text(destination.title)),
      body: SafeArea(child: _SectionLanding(destination: destination)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
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
}

class _SectionLanding extends StatelessWidget {
  const _SectionLanding({required this.destination});
  final _AppDestination destination;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                destination.selectedIcon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                destination.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                destination.message,
                style: textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5E6675),
                  height: 1.45,
                ),
              ),
            ],
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
    required this.message,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String message;
}
