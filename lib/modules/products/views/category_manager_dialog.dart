import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/products_controller.dart';

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final _nameController = TextEditingController();
  final _productsController = Get.find<ProductsController>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: screenWidth < 520 ? screenWidth - 40 : 440,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Gérer les catégories',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: Get.back<void>,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nouvelle catégorie',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      onSubmitted: (_) => _addCategory(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Ajouter la catégorie',
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Obx(
                  () => ListView.separated(
                    shrinkWrap: true,
                    itemCount: _productsController.categories.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category = _productsController.categories[index];
                      final productCount = _productsController.products
                          .where((product) => product.category == category)
                          .length;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_outlined,
                            color: AppColors.primary),
                        title: Text(category),
                        subtitle: Text('$productCount produit(s)'),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'Renommer',
                              onPressed: () => _renameCategory(category),
                              icon: const Icon(Icons.edit_outlined, size: 19),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _deleteCategory(category),
                              icon: const Icon(Icons.delete_outline,
                                  size: 19, color: AppColors.error),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addCategory() {
    if (!_productsController.addCategory(_nameController.text)) {
      Get.snackbar('Catégorie non ajoutée', 'Vérifiez le nom ou choisissez-en un autre.');
      return;
    }
    _nameController.clear();
  }

  Future<void> _renameCategory(String category) async {
    final textController = TextEditingController(text: category);
    final newName = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Renommer la catégorie'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Get.back<String>(result: textController.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (newName == null) return;
    if (!_productsController.renameCategory(category, newName)) {
      Get.snackbar('Nom non modifié', 'Ce nom de catégorie est vide ou déjà utilisé.');
    }
  }

  Future<void> _deleteCategory(String category) async {
    if (_productsController.categories.length <= 1) {
      Get.snackbar('Suppression impossible', 'Gardez au moins une catégorie.');
      return;
    }
    final inUse = _productsController.products
        .any((product) => product.category == category);
    if (inUse) {
      Get.snackbar(
        'Catégorie utilisée',
        'Réaffectez d’abord les produits de cette catégorie.',
      );
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text('La catégorie « $category » sera supprimée.'),
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
    if (confirmed == true) _productsController.deleteCategory(category);
  }
}
