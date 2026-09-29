import 'package:flutter/material.dart';

import '../../../core/network/customer_portal_models.dart';
import '../domain/catalog_product_metadata.dart';

class CatalogProductVisual extends StatelessWidget {
  const CatalogProductVisual({
    super.key,
    required this.item,
    required this.metadata,
    this.size = 96,
    this.borderRadius = 16,
  });

  final CustomerCatalogItem item;
  final CatalogMetadataIndex metadata;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = metadata.imageUrlFor(item);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE4EAE5)),
      ),
      child: imageUrl == null
          ? _fallback(context)
          : Image.network(
              imageUrl,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => _fallback(context),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
    );
  }

  Widget _fallback(BuildContext context) {
    final brand = metadata.brandFor(item);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.purchaseMode == 'case'
                ? Icons.inventory_2_outlined
                : Icons.shopping_bag_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: size * .34,
          ),
          if (brand.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
