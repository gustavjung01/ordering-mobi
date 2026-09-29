import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_models.dart';
import '../../../shared/formatters.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../ordering/data/customer_ordering_repository.dart';
import '../../products/domain/catalog_product_metadata.dart';
import '../../products/presentation/catalog_product_visual.dart';

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
  static const _heroImageUrl =
      'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system/hero-app-customer.jpg';

  static const _categoryImages = <String, String>{
    'milk-tea': 'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system/icon-tra-sua.webp',
    'spicy-noodle': 'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system/icon-mi-cay.webp',
    'frozen': 'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system/icon-dong-lanh.webp',
    'snacks': 'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system/icon-an-vat.webp',
    'packaging': 'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system/icon-bao-bi.webp',
    'sauce-seasoning': 'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system/icon-gia-vi.webp',
  };

  List<CustomerOrder> _orders = const [];
  List<CustomerCatalogItem> _products = const [];
  List<CustomerCategory> _categories = const [];
  CatalogMetadataIndex? _metadata;
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
        widget.repository.listCatalog(limit: 40, includeCategories: true),
        CatalogMetadataIndex.shared(),
      ]);
      final orders = [...results[0] as List<CustomerOrder>]
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      final catalog = results[1] as CustomerCatalogPage;
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _products = catalog.items;
        _categories = catalog.categories;
        _metadata = results[2] as CatalogMetadataIndex;
        _loading = false;
        _error = null;
      });
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được dữ liệu trang chủ.';
      });
    }
  }

  Future<void> _openCart() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CartScreen(repository: widget.repository),
    ),
  );

  Future<void> _addProduct(CustomerCatalogItem item) async {
    try {
      await widget.repository.addProduct(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm ${item.name} vào giỏ hàng.')),
      );
      setState(() {});
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _orders.isEmpty ? null : _orders.first;
    final metadata = _metadata;
    final groups = metadata == null
        ? const <CatalogProductGroup>[]
        : buildCatalogProductGroups(
            _products,
            metadata,
          ).take(6).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          _IdentityCard(
            profile: widget.profile,
            cartQuantity: widget.repository.cartQuantity,
            onQuickOrder: () => widget.onSelectTab(2),
            onCart: _openCart,
          ),
          const SizedBox(height: 14),
          _SearchLauncher(onTap: () => widget.onSelectTab(1)),
          const SizedBox(height: 14),
          _HeroBanner(onProducts: () => widget.onSelectTab(1)),
          const SizedBox(height: 14),
          _QuickActions(
            onProducts: () => widget.onSelectTab(1),
            onOrders: () => widget.onSelectTab(3),
            onAssistant: widget.onOpenAssistant,
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _StateCard(
              icon: Icons.cloud_off_rounded,
              message: _error!,
              onRetry: _load,
            )
          else ...[
            if (latest != null) ...[
              _SectionHeading(
                title: 'Đơn hàng gần nhất',
                actionLabel: 'Xem tất cả',
                onAction: () => widget.onSelectTab(3),
              ),
              const SizedBox(height: 8),
              _LatestOrderCard(
                order: latest,
                onTap: () => widget.onSelectTab(3),
              ),
              const SizedBox(height: 18),
            ],
            if (_categories.isNotEmpty) ...[
              _SectionHeading(
                title: 'Ngành hàng',
                actionLabel: 'Xem tất cả',
                onAction: () => widget.onSelectTab(1),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _CategoryCard(
                      category: category,
                      imageUrl: _categoryImages[category.id],
                      onTap: () => widget.onSelectTab(1),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (groups.isNotEmpty && metadata != null) ...[
              _SectionHeading(
                title: 'Sản phẩm',
                actionLabel: 'Xem tất cả',
                onAction: () => widget.onSelectTab(1),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 238,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final item = group.preferred(purchaseMode: 'retail');
                    return _ProductPreviewCard(
                      group: group,
                      item: item,
                      metadata: metadata,
                      onOpen: () => widget.onSelectTab(1),
                      onAdd: () => _addProduct(item),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.cartQuantity,
    required this.onQuickOrder,
    required this.onCart,
  });

  final CustomerProfile profile;
  final int cartQuantity;
  final VoidCallback onQuickOrder;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    const greenDark = Color(0xFF0F6B3D);
    const green = Color(0xFF198754);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [greenDark, green, Color(0xFF3DA16F)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E0F6B3D),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.eco_rounded, color: Color(0xFFFFC107), size: 30),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'HƯNG PHÁT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x4DFFFFFF)),
                ),
                child: const Text(
                  'Đang hoạt động',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Xin chào, ${profile.displayName}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            profile.outletName.isEmpty
                ? 'Mã khách: ${profile.customerCode}'
                : '${profile.outletName}\nMã khách: ${profile.customerCode}',
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onQuickOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: greenDark,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Đặt nhanh'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xB3FFFFFF)),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(
                    cartQuantity > 0 ? 'Giỏ hàng ($cartQuantity)' : 'Giỏ hàng',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD8E1DA)),
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F163A23),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tìm sản phẩm theo tên hoặc nhãn',
                  style: TextStyle(color: Color(0xFF6C757D)),
                ),
              ),
              const Icon(
                Icons.tune_rounded,
                color: Color(0xFF6C757D),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onProducts});

  final VoidCallback onProducts;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 174,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF0F6B3D),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300F6B3D),
            blurRadius: 34,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _HomeScreenState._heroImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F6B3D),
                    Color(0xFF198754),
                    Color(0xFF3DA16F),
                  ],
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xD90B4D2C),
                  Color(0x8C0F6B3D),
                  Color(0x0D0F6B3D),
                ],
                stops: [0, .58, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 21, 150, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nguyên liệu chất lượng',
                  style: TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cho món ngon\ntrọn vị',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onProducts,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F6B3D),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 38),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: const Text('Xem sản phẩm'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onProducts,
    required this.onOrders,
    required this.onAssistant,
  });

  final VoidCallback onProducts;
  final VoidCallback onOrders;
  final VoidCallback? onAssistant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.inventory_2_outlined,
            label: 'Sản phẩm',
            onTap: onProducts,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.receipt_long_outlined,
            label: 'Đơn hàng',
            onTap: onOrders,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.auto_awesome_rounded,
            label: 'Hỏi Hưng Phát',
            onTap: onAssistant,
            emphasized: true,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final foreground = emphasized ? Colors.white : const Color(0xFF0F6B3D);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
          decoration: BoxDecoration(
            gradient: emphasized
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F6B3D),
                      Color(0xFF198754),
                      Color(0xFF2C9F67),
                    ],
                  )
                : null,
            color: emphasized ? null : Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: emphasized
                  ? const Color(0x52198754)
                  : const Color(0xFFDDE6DF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12163A23),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: emphasized
                      ? const Color(0x26FFFFFF)
                      : const Color(0xFFEBF5E9),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: foreground, size: 23),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  height: 1.05,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right_rounded, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _LatestOrderCard extends StatelessWidget {
  const _LatestOrderCard({required this.order, required this.onTap});

  final CustomerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.code,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    formatDateTime(order.submittedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6C757D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      orderStatusLabel(order.status),
                      style: const TextStyle(
                        color: Color(0xFF7A5700),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${order.lines.length} mặt hàng · ${order.totalQuantity} sản phẩm',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    formatVnd(order.pricedSubtotal),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF17221A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.imageUrl,
    required this.onTap,
  });

  final CustomerCategory category;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          width: 86,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3EF),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFDBE3DC)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _CategoryFallback(),
                  )
                else
                  const _CategoryFallback(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x260C1C12),
                        Color(0xD90C1C12),
                      ],
                      stops: [.2, .52, 1],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 24, 5, 7),
                    child: Text(
                      category.shortName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Color(0x80000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFallback extends StatelessWidget {
  const _CategoryFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2C9F67),
      child: Center(
        child: Icon(Icons.category_outlined, color: Colors.white, size: 30),
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({
    required this.group,
    required this.item,
    required this.metadata,
    required this.onOpen,
    required this.onAdd,
  });

  final CatalogProductGroup group;
  final CustomerCatalogItem item;
  final CatalogMetadataIndex metadata;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final brand = metadata.brandFor(item);
    final detail = [
      metadata.variantFor(item),
      metadata.sizeFor(item),
    ].where((value) => value.isNotEmpty).join(' · ');
    final price = item.price.isAvailable && item.price.amount != null
        ? formatVnd(item.price.amount!)
        : 'Chờ giá';

    return SizedBox(
      width: 158,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CatalogProductVisual(
                    item: item,
                    metadata: metadata,
                    size: 104,
                    borderRadius: 15,
                  ),
                ),
                const SizedBox(height: 8),
                if (brand.isNotEmpty)
                  Text(
                    brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  group.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17221A),
                    fontSize: 13,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 10.5,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F6B3D),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Thêm vào giỏ',
                      onPressed: onAdd,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: const Color(0xFF17221A),
                        minimumSize: const Size(34, 34),
                        maximumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 38),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
