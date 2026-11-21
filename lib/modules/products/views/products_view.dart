import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/section_card.dart';
import '../controllers/products_controller.dart';
import '../models/product.dart';
import '../widgets/product_image.dart';
import 'category_manager_dialog.dart';
import 'product_form_dialog.dart';

class ProductsView extends GetView<ProductsController> {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Produits',
      child: Obx(() {
        final filteredProducts = controller.filteredProducts;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            return ListView(
              padding: EdgeInsets.all(isWide ? 28 : 18),
              children: [
                _PageHeader(
                  isWide: isWide,
                  onAddProduct: _addProduct,
                  onManageCategories: _manageCategories,
                ),
                const SizedBox(height: 22),
                _ProductStats(products: controller.products),
                const SizedBox(height: 20),
                SectionCard(
                  title: 'Catalogue des produits',
                  subtitle: '${filteredProducts.length} résultat(s)',
                  child: Column(
                    children: [
                      _ProductFilters(controller: controller),
                      const SizedBox(height: 16),
                      if (filteredProducts.isEmpty)
                        const _EmptyProducts()
                      else if (constraints.maxWidth >= 820)
                        _ProductTable(
                          products: filteredProducts,
                          onEdit: _editProduct,
                          onDelete: _deleteProduct,
                        )
                      else
                        Column(
                          children: [
                            for (final product in filteredProducts)
                              _ProductCard(
                                product: product,
                                onEdit: () => _editProduct(product),
                                onDelete: () => _deleteProduct(product),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }

  Future<void> _addProduct() async {
    final product = await Get.dialog<Product>(const ProductFormDialog());
    if (product == null) return;
    controller.saveProduct(product);
    Get.snackbar(
      'Produit ajouté',
      '${product.name} a été ajouté au catalogue.',
    );
  }

  Future<void> _editProduct(Product product) async {
    final updated = await Get.dialog<Product>(
      ProductFormDialog(product: product),
    );
    if (updated == null) return;
    controller.saveProduct(updated);
    Get.snackbar('Produit modifié', 'Les informations ont été mises à jour.');
  }

  Future<void> _deleteProduct(Product product) async {
    if (product.quantity > 0) {
      await Get.dialog<void>(
        AlertDialog(
          title: const Text('Stock restant'),
          content: Text(
            '« ${product.name} » a encore ${product.quantity} unité(s). '
            'Enregistrez une sortie ou une perte dans le stock avant de le supprimer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: const Text('Fermer'),
            ),
            FilledButton.icon(
              onPressed: () {
                Get.back<void>();
                Get.toNamed<void>(AppRoutes.stock);
              },
              icon: const Icon(Icons.warehouse_outlined),
              label: const Text('Ouvrir le stock'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text('« ${product.name} » sera retiré du catalogue.'),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (controller.deleteProduct(product.id)) {
        Get.snackbar(
          'Produit supprimé',
          '${product.name} a été retiré du catalogue.',
        );
      } else {
        Get.snackbar(
          'Suppression impossible',
          'Le produit a du stock restant ou a déjà été supprimé.',
        );
      }
    }
  }

  void _manageCategories() => Get.dialog<void>(const CategoryManagerDialog());
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.isWide,
    required this.onAddProduct,
    required this.onManageCategories,
  });

  final bool isWide;
  final VoidCallback onAddProduct;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onManageCategories,
          icon: const Icon(Icons.category_outlined, size: 18),
          label: const Text('Catégories'),
        ),
        AppButton(
          label: 'Ajouter un produit',
          icon: Icons.add,
          onPressed: onAddProduct,
        ),
      ],
    );

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestion des produits',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          actions,
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion des produits',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Gérez votre catalogue et vos catégories.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions,
      ],
    );
  }
}

class _ProductStats extends StatelessWidget {
  const _ProductStats({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final low = products
        .where((product) => product.stockStatus == ProductStockStatus.low)
        .length;
    final out = products
        .where(
          (product) => product.stockStatus == ProductStockStatus.outOfStock,
        )
        .length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatPill(
          label: 'Produits',
          value: '${products.length}',
          icon: Icons.inventory_2_outlined,
        ),
        _StatPill(
          label: 'Stock faible',
          value: '$low',
          icon: Icons.warning_amber_rounded,
          tint: const Color(0xFFFFF4D8),
        ),
        _StatPill(
          label: 'Rupture',
          value: '$out',
          icon: Icons.remove_shopping_cart_outlined,
          tint: const Color(0xFFFFE6E6),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.tint = AppColors.surfaceTint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: tint,
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ProductFilters extends StatelessWidget {
  const _ProductFilters({required this.controller});

  final ProductsController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final categoryWidth = constraints.maxWidth < 600
            ? constraints.maxWidth
            : 220.0;
        final statusWidth = constraints.maxWidth < 600
            ? constraints.maxWidth
            : 180.0;
        final fields = [
          TextField(
            onChanged: (value) => controller.searchQuery.value = value,
            decoration: const InputDecoration(
              hintText: 'Rechercher un nom ou un code…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          Obx(
            () => DropdownButtonFormField<String>(
              key: ValueKey(controller.selectedCategory.value),
              initialValue: controller.selectedCategory.value,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                const DropdownMenuItem(
                  value: 'Toutes les catégories',
                  child: Text('Toutes les catégories'),
                ),
                for (final category in controller.categories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                if (value != null) controller.selectedCategory.value = value;
              },
            ),
          ),
          Obx(
            () => DropdownButtonFormField<ProductStatusFilter>(
              key: ValueKey(controller.selectedStatus.value),
              initialValue: controller.selectedStatus.value,
              decoration: const InputDecoration(labelText: 'État du stock'),
              items: const [
                DropdownMenuItem(
                  value: ProductStatusFilter.all,
                  child: Text('Tous les stocks'),
                ),
                DropdownMenuItem(
                  value: ProductStatusFilter.available,
                  child: Text('En stock'),
                ),
                DropdownMenuItem(
                  value: ProductStatusFilter.low,
                  child: Text('Stock faible'),
                ),
                DropdownMenuItem(
                  value: ProductStatusFilter.outOfStock,
                  child: Text('Rupture'),
                ),
              ],
              onChanged: (value) {
                if (value != null) controller.selectedStatus.value = value;
              },
            ),
          ),
        ];

        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              fields[0],
              const SizedBox(height: 10),
              SizedBox(width: categoryWidth, child: fields[1]),
              const SizedBox(height: 10),
              SizedBox(width: statusWidth, child: fields[2]),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 10),
            SizedBox(width: categoryWidth, child: fields[1]),
            const SizedBox(width: 10),
            SizedBox(width: statusWidth, child: fields[2]),
          ],
        );
      },
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Produit')),
          DataColumn(label: Text('Catégorie')),
          DataColumn(label: Text('Prix d’achat')),
          DataColumn(label: Text('Prix de vente')),
          DataColumn(label: Text('Stock'), numeric: true),
          DataColumn(label: Text('Seuil'), numeric: true),
          DataColumn(label: Text('État')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final product in products)
            DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ProductImage(
                              imagePath: product.imagePath,
                              placeholder: const ColoredBox(
                                color: Color(0xFFF0F4F1),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (product.sku.isNotEmpty)
                                Text(
                                  product.sku,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(product.category)),
                DataCell(Text(_formatPrice(product.purchasePrice))),
                DataCell(Text(_formatPrice(product.salePrice))),
                DataCell(Text('${product.quantity}')),
                DataCell(Text('${product.alertThreshold}')),
                DataCell(_StockBadge(status: product.stockStatus)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Modifier',
                        onPressed: () => onEdit(product),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        onPressed: () => onDelete(product),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: ProductImage(
                      imagePath: product.imagePath,
                      placeholder: Container(
                        color: AppColors.surfaceTint,
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        product.category,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _ProductValue(
                  label: 'Vente',
                  value: _formatPrice(product.salePrice),
                ),
                _ProductValue(
                  label: 'Achat',
                  value: _formatPrice(product.purchasePrice),
                ),
                _ProductValue(label: 'Stock', value: '${product.quantity}'),
                _StockBadge(status: product.stockStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductValue extends StatelessWidget {
  const _ProductValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.status});

  final ProductStockStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      ProductStockStatus.available => (
        'En stock',
        const Color(0xFFE5F6EB),
        AppColors.success,
      ),
      ProductStockStatus.low => (
        'Stock faible',
        const Color(0xFFFFF2D6),
        const Color(0xFF9B6700),
      ),
      ProductStockStatus.outOfStock => (
        'Rupture',
        const Color(0xFFFFE7E7),
        AppColors.error,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 38,
              color: AppColors.muted,
            ),
            const SizedBox(height: 10),
            Text(
              'Aucun produit trouvé',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Essayez un autre filtre ou ajoutez un produit.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(int value) {
  final digits = value.toString();
  final result = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) result.write(' ');
    result.write(digits[i]);
  }
  return '${result.toString()} F';
}
