import 'package:flutter/material.dart';

import '../../core/network/customer_portal_account_models.dart';
import '../../core/network/customer_portal_models.dart';
import '../../features/account/data/customer_account_repository.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/assistant/data/customer_assistant_api.dart';
import '../../features/assistant/presentation/customer_assistant_screen.dart';
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
    this.lifecycle,
    this.profile,
    this.orderingRepository,
    this.accountRepository,
    this.assistantApi,
    this.customerDisplayName,
    this.onSignOut,
  });

  final PortalLifecycleSnapshot? lifecycle;
  final CustomerProfile? profile;
  final CustomerOrderingRepository? orderingRepository;
  final CustomerAccountRepository? accountRepository;
  final CustomerAssistantApi? assistantApi;
  final String? customerDisplayName;
  final SignOutCallback? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;
  PortalLifecycleSnapshot? _lifecycle;
  CustomerProfile? _profile;

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

  @override
  void initState() {
    super.initState();
    _lifecycle = widget.lifecycle;
    _profile = widget.profile;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lifecycle, widget.lifecycle)) {
      _lifecycle = widget.lifecycle;
    }
    if (!identical(oldWidget.profile, widget.profile)) {
      _profile = widget.profile;
    }
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _destinations.length) return;
    setState(() => _index = index);
  }

  Future<void> _openCart() async {
    final repository = widget.orderingRepository;
    if (repository == null || !_orderingEnabled) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartScreen(repository: repository),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openAssistant() async {
    if (!_orderingEnabled) return;
    final api = widget.assistantApi;
    if (api == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hỏi Hưng Phát chưa sẵn sàng trên thiết bị này. Vui lòng thử lại sau.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerAssistantScreen(api: api),
      ),
    );
  }

  bool get _orderingEnabled =>
      _lifecycle?.isActiveCustomer == true && _profile != null;

  void _applyLifecycle(PortalLifecycleSnapshot lifecycle) {
    if (!mounted) return;
    setState(() {
      _lifecycle = lifecycle;
      if (!lifecycle.isActiveCustomer) _profile = null;
    });
  }

  void _applyPortalProfile(PortalProfile profile) {
    if (!mounted) return;
    setState(() {
      _profile = CustomerProfile(
        customerCode: profile.customerCode,
        displayName: profile.displayName,
        phone: profile.phone,
        outletName: profile.outletName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_index];
    final orderingRepository = widget.orderingRepository;
    final accountRepository = widget.accountRepository;
    final lifecycle = _lifecycle;

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.title),
        actions: [
          if (_orderingEnabled && orderingRepository != null)
            AnimatedBuilder(
              animation: orderingRepository,
              builder: (context, _) => Badge(
                isLabelVisible: orderingRepository.cartQuantity > 0,
                label: Text('${orderingRepository.cartQuantity}'),
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
        child:
            orderingRepository != null &&
                accountRepository != null &&
                lifecycle != null
            ? _buildPortalPage(
                orderingRepository,
                accountRepository,
                lifecycle,
              )
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

  Widget _buildPortalPage(
    CustomerOrderingRepository orderingRepository,
    CustomerAccountRepository accountRepository,
    PortalLifecycleSnapshot lifecycle,
  ) {
    if (_index == 4) {
      return AccountScreen(
        lifecycle: lifecycle,
        profile: _profile,
        repository: accountRepository,
        onLifecycleChanged: _applyLifecycle,
        onProfileChanged: _applyPortalProfile,
        onSignOut: widget.onSignOut,
      );
    }

    final profile = _profile;
    if (!lifecycle.isActiveCustomer || profile == null) {
      return _PortalAccessLockedPage(
        lifecycle: lifecycle,
        onOpenAccount: () => _selectTab(4),
      );
    }

    return switch (_index) {
      0 => HomeScreen(
        profile: profile,
        repository: orderingRepository,
        onSelectTab: _selectTab,
        onOpenAssistant: _openAssistant,
      ),
      1 => ProductCatalogScreen(repository: orderingRepository),
      2 => QuickOrderScreen(repository: orderingRepository),
      3 => OrdersScreen(repository: orderingRepository),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PortalAccessLockedPage extends StatelessWidget {
  const _PortalAccessLockedPage({
    required this.lifecycle,
    required this.onOpenAccount,
  });

  final PortalLifecycleSnapshot lifecycle;
  final VoidCallback onOpenAccount;

  String get _message => switch (lifecycle.state) {
    PortalLifecycleStates.unregistered =>
      'Điểm bán chưa đăng ký với Hưng Phát.',
    PortalLifecycleStates.submitted =>
      'Đăng ký điểm bán đã được gửi và đang chờ xử lý.',
    PortalLifecycleStates.underReview =>
      'Điểm bán đang được Hưng Phát xác minh.',
    PortalLifecycleStates.needMoreInfo =>
      'Đăng ký cần bổ sung thông tin trước khi được duyệt.',
    PortalLifecycleStates.approved ||
    PortalLifecycleStates.linkedExisting ||
    PortalLifecycleStates.activationPending =>
      'Điểm bán đã được duyệt và đang kích hoạt quyền đặt hàng.',
    PortalLifecycleStates.rejected => 'Đăng ký điểm bán chưa được chấp thuận.',
    PortalLifecycleStates.cancelled => 'Đăng ký điểm bán đã kết thúc.',
    PortalLifecycleStates.suspended => 'Liên kết điểm bán hiện đang tạm khóa.',
    _ => 'Điểm bán chưa được kích hoạt để đặt hàng.',
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 42),
                  const SizedBox(height: 16),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Danh mục, giỏ hàng và đặt hàng sẽ mở khi tài khoản điểm bán được kích hoạt. Anh/chị vẫn có thể xem và cập nhật trạng thái trong mục Tài khoản.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onOpenAccount,
                    child: const Text('Đăng ký / xem trạng thái điểm bán'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
