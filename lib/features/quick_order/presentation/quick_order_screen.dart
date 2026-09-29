import 'package:flutter/material.dart';

import '../../ordering/data/customer_ordering_repository.dart';
import '../../products/presentation/product_catalog_screen.dart';

class QuickOrderScreen extends StatelessWidget {
  const QuickOrderScreen({super.key, required this.repository});

  final CustomerOrderingRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProductCatalogScreen(repository: repository, quickOrder: true);
  }
}
