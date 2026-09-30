import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/customer_portal_models.dart';
import '../../ordering/data/customer_ordering_repository.dart';

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
  static const _imageBase =
      'https://pub-7d2987fab97d4e3ebb2021a823973862.r2.dev/app-customer/image-system';
  static const _heroImageUrl = '$_imageBase/hero-app-customer.jpg';
  static const _categories = <_HomeCategoryShortcut>[
    _HomeCategoryShortcut(
      label: 'Trà sữa',
      imageUrl: '$_imageBase/icon-tra-sua.webp',
    ),
    _HomeCategoryShortcut(
      label: 'Mì cay',
      imageUrl: '$_imageBase/icon-mi-cay.webp',
    ),
    _HomeCategoryShortcut(
      label: 'Đông lạnh',
      imageUrl: '$_imageBase/icon-dong-lanh.webp',
    ),
    _HomeCategoryShortcut(
      label: 'Ăn vặt',
      imageUrl: '$_imageBase/icon-an-vat.webp',
    ),
    _HomeCategoryShortcut(
      label: 'Bao bì',
      imageUrl: '$_imageBase/icon-bao-bi.webp',
    ),
    _HomeCategoryShortcut(
      label: 'Gia vị',
      imageUrl: '$_imageBase/icon-gia-vi.webp',
    ),
  ];

  CustomerHomeContent? _homeContent;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHomeContent());
  }

  Future<void> _loadHomeContent() async {
    try {
      final content = await widget.repository.getHomeContent();
      if (!mounted) return;
      setState(() => _homeContent = content);
    } on Object {
      // Nội dung quản trị không được chặn Trang chủ khi mạng tạm thời gián đoạn.
    }
  }

  Future<void> _openEventDetails(CustomerHomeContent content) async {
    final programContent = content.programContent.trim();
    if (programContent.isEmpty || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
          ),
          child: SingleChildScrollView(
            key: const Key('event-detail-sheet'),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 3.6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF3EF),
                      ),
                      child: Image.network(
                        content.bannerUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  content.sectionTitle,
                  key: const Key('event-detail-title'),
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  programContent,
                  key: const Key('event-detail-content'),
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                    color: const Color(0xFF3F4A42),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('event-detail-close'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _homeContent;
    final showManagedBanner =
        content?.visible == true &&
        content?.bannerUrl?.trim().isNotEmpty == true;

    return RefreshIndicator(
      onRefresh: _loadHomeContent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          _SearchLauncher(onTap: () => widget.onSelectTab(1)),
          const SizedBox(height: 14),
          _HeroBanner(onProducts: () => widget.onSelectTab(1)),
          const SizedBox(height: 14),
          _QuickActions(
            onProducts: () => widget.onSelectTab(1),
            onOrders: () => widget.onSelectTab(3),
            onAssistant: widget.onOpenAssistant,
          ),
          const SizedBox(height: 20),
          _SectionHeading(
            title: 'Ngành hàng',
            actionLabel: 'Xem tất cả',
            onAction: () => widget.onSelectTab(1),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _CategoryCard(
                  category: category,
                  onTap: () => widget.onSelectTab(1),
                );
              },
            ),
          ),
          if (showManagedBanner) ...[
            const SizedBox(height: 20),
            _ManagedHomeBanner(
              content: content!,
              onTap: content.programContent.trim().isEmpty
                  ? null
                  : () => _openEventDetails(content),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeCategoryShortcut {
  const _HomeCategoryShortcut({
    required this.label,
    required this.imageUrl,
  });

  final String label;
  final String imageUrl;
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final _HomeCategoryShortcut category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          width: 88,
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
                Image.network(
                  category.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _CategoryFallback(),
                ),
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
                      category.label,
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

class _ManagedHomeBanner extends StatelessWidget {
  const _ManagedHomeBanner({
    required this.content,
    required this.onTap,
  });

  final CustomerHomeContent content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          content.sectionTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: onTap != null,
          label: onTap == null
              ? content.sectionTitle
              : '${content.sectionTitle}. Mở chi tiết chương trình',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('managed-event-banner'),
              onTap: onTap,
              child: AspectRatio(
                aspectRatio: 3.6,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFEEF3EF)),
                  child: Image.network(
                    content.bannerUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
