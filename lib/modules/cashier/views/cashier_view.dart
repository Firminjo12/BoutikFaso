import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/models/product.dart';
import '../../products/widgets/product_image.dart';
import '../controllers/cart_controller.dart';
import '../../sales/controllers/checkout_flow.dart';

class CashierView extends GetView<CartController> {
  const CashierView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Caisse',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ProductCatalog(controller: controller)),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 370,
                    child: CartPanel(
                      controller: controller,
                      onCheckout: checkoutCart,
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(child: _ProductCatalog(controller: controller)),
              Obx(
                () => _MobileCartSummary(
                  itemCount: controller.itemCount,
                  total: controller.total,
                  onOpen: () => Get.toNamed<void>(AppRoutes.basket),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCatalog extends StatelessWidget {
  const _ProductCatalog({required this.controller});

  final CartController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Caisse / Nouvelle vente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => controller.searchQuery.value = value,
            decoration: const InputDecoration(
              hintText: 'Rechercher un produit…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'Toutes',
                    selected: controller.selectedCategory.value == 'Toutes',
                    onSelected: () =>
                        controller.selectedCategory.value = 'Toutes',
                  ),
                  for (final category
                      in controller.productsController.categories)
                    _CategoryChip(
                      label: category,
                      selected: controller.selectedCategory.value == category,
                      onSelected: () =>
                          controller.selectedCategory.value = category,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Obx(() {
              final products = controller.filteredProducts;
              if (products.isEmpty) {
                return const Center(child: Text('Aucun produit trouvé.'));
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 680 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: constraints.maxWidth >= 680
                          ? 1.02
                          : 0.94,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) => _CashierProductCard(
                      product: products[index],
                      quantityInCart:
                          controller.quantities[products[index].id] ?? 0,
                      onAdd: () => _addProduct(products[index]),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _addProduct(Product product) {
    if (controller.addProduct(product)) return;
    Get.snackbar(
      'Stock insuffisant',
      product.quantity == 0
          ? '${product.name} est en rupture de stock.'
          : 'La quantité disponible pour ${product.name} est déjà dans le panier.',
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _CashierProductCard extends StatelessWidget {
  const _CashierProductCard({
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
  });

  final Product product;
  final int quantityInCart;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final unavailable = product.quantity == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: unavailable ? null : onAdd,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ProductImage(
                          imagePath: product.imagePath,
                          placeholder: Container(
                            color: const Color(0xFFF4F5F2),
                            alignment: Alignment.center,
                            child: Icon(
                              _productIcon(product.category),
                              size: 38,
                              color: AppColors.primary.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (quantityInCart > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          child: Text(
                            '$quantityInCart',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatFcfa(product.salePrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    unavailable ? 'Rupture' : 'Stock ${product.quantity}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: unavailable ? AppColors.error : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.add_circle,
                    size: 20,
                    color: unavailable ? AppColors.muted : AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileCartSummary extends StatelessWidget {
  const _MobileCartSummary({
    required this.itemCount,
    required this.total,
    required this.onOpen,
  });

  final int itemCount;
  final int total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$itemCount article(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _formatFcfa(total),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.shopping_basket_outlined, size: 18),
            label: const Text('Voir le panier'),
          ),
        ],
      ),
    );
  }
}

class CartPanel extends StatelessWidget {
  const CartPanel({
    required this.controller,
    required this.onCheckout,
    super.key,
  });

  final CartController controller;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final lines = controller.lines;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Panier de vente',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${controller.itemCount} article(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (lines.isNotEmpty)
                    IconButton(
                      tooltip: 'Vider le panier',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: lines.isEmpty
                    ? const _EmptyCart()
                    : ListView.separated(
                        itemCount: lines.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) => _CartLineTile(
                          line: lines[index],
                          controller: controller,
                        ),
                      ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total à payer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    _formatFcfa(controller.total),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.itemCount == 0 ? null : onCheckout,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Finaliser la vente'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Le stock sera mis à jour après confirmation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line, required this.controller});

  final CartLine line;
  final CartController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${_formatFcfa(line.product.salePrice)} / unité',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Retirer du panier',
                visualDensity: VisualDensity.compact,
                onPressed: () => controller.remove(line.product.id),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Réduire la quantité',
                visualDensity: VisualDensity.compact,
                onPressed: () => controller.decrease(line.product.id),
                icon: const Icon(Icons.remove, size: 17),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${line.quantity}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Augmenter la quantité',
                visualDensity: VisualDensity.compact,
                onPressed: line.quantity < line.product.quantity
                    ? () => controller.increase(line.product.id)
                    : null,
                icon: const Icon(Icons.add, size: 17),
              ),
              const Spacer(),
              Text(
                _formatFcfa(line.total),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            'Le panier est vide',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Ajoutez des produits depuis la caisse.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

IconData _productIcon(String category) => switch (category.toLowerCase()) {
  'vivres' => Icons.grain_outlined,
  'boissons' => Icons.local_drink_outlined,
  'hygiène' || 'hygiene' => Icons.soap_outlined,
  _ => Icons.inventory_2_outlined,
};

String _formatFcfa(int value) {
  final digits = value.toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write(' ');
    result.write(digits[index]);
  }
  return '${result.toString()} F';
}
