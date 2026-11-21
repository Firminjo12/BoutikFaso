import 'package:get/get.dart';

import '../models/product.dart';

enum ProductStatusFilter { all, available, low, outOfStock }

class ProductsController extends GetxController {
  final categories = <String>['Vivres', 'Hygiène', 'Boissons'].obs;
  final searchQuery = ''.obs;
  final selectedCategory = 'Toutes les catégories'.obs;
  final selectedStatus = ProductStatusFilter.all.obs;

  final products = <Product>[
    const Product(
      id: 'p-1',
      name: 'Riz parfumé 5 kg',
      category: 'Vivres',
      purchasePrice: 2800,
      salePrice: 3200,
      quantity: 14,
      alertThreshold: 5,
      sku: 'BF-RIZ-005',
    ),
    const Product(
      id: 'p-2',
      name: 'Huile Dinor 1 L',
      category: 'Vivres',
      purchasePrice: 950,
      salePrice: 1150,
      quantity: 9,
      alertThreshold: 4,
      sku: 'BF-HUI-001',
    ),
    const Product(
      id: 'p-3',
      name: 'Sucre en poudre 1 kg',
      category: 'Vivres',
      purchasePrice: 600,
      salePrice: 750,
      quantity: 3,
      alertThreshold: 5,
      sku: 'BF-SUC-001',
    ),
    const Product(
      id: 'p-4',
      name: 'Savon Citec',
      category: 'Hygiène',
      purchasePrice: 300,
      salePrice: 400,
      quantity: 22,
      alertThreshold: 6,
      sku: 'BF-SAV-001',
    ),
    const Product(
      id: 'p-5',
      name: 'Eau minérale 1,5 L',
      category: 'Boissons',
      purchasePrice: 300,
      salePrice: 500,
      quantity: 0,
      alertThreshold: 4,
      sku: 'BF-EAU-015',
    ),
  ].obs;

  List<Product> get filteredProducts {
    final query = searchQuery.value.trim().toLowerCase();
    return products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
      final matchesCategory =
          selectedCategory.value == 'Toutes les catégories' ||
          product.category == selectedCategory.value;
      final matchesStatus = switch (selectedStatus.value) {
        ProductStatusFilter.all => true,
        ProductStatusFilter.available =>
          product.stockStatus == ProductStockStatus.available,
        ProductStatusFilter.low =>
          product.stockStatus == ProductStockStatus.low,
        ProductStatusFilter.outOfStock =>
          product.stockStatus == ProductStockStatus.outOfStock,
      };
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();
  }

  void saveProduct(Product product) {
    final index = products.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      products.insert(0, product);
    } else {
      products[index] = product;
    }
  }

  bool deleteProduct(String id) {
    final product = products.firstWhereOrNull((item) => item.id == id);
    if (product == null || product.quantity > 0) return false;
    products.remove(product);
    return true;
  }

  bool adjustProductStock(String id, int quantityDelta) {
    final index = products.indexWhere((product) => product.id == id);
    if (index == -1) return false;
    final product = products[index];
    final updatedQuantity = product.quantity + quantityDelta;
    if (updatedQuantity < 0) return false;
    products[index] = product.copyWith(quantity: updatedQuantity);
    return true;
  }

  bool addCategory(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty ||
        categories.any(
          (item) => item.toLowerCase() == normalized.toLowerCase(),
        )) {
      return false;
    }
    categories.add(normalized);
    return true;
  }

  bool renameCategory(String currentName, String newName) {
    final normalized = newName.trim();
    if (normalized.isEmpty ||
        categories.any(
          (item) =>
              item != currentName &&
              item.toLowerCase() == normalized.toLowerCase(),
        )) {
      return false;
    }
    final index = categories.indexOf(currentName);
    if (index == -1) return false;
    categories[index] = normalized;
    for (var i = 0; i < products.length; i++) {
      if (products[i].category == currentName) {
        products[i] = products[i].copyWith(category: normalized);
      }
    }
    if (selectedCategory.value == currentName) {
      selectedCategory.value = normalized;
    }
    return true;
  }

  bool deleteCategory(String name) {
    if (categories.length <= 1 ||
        products.any((product) => product.category == name)) {
      return false;
    }
    final removed = categories.remove(name);
    if (selectedCategory.value == name) {
      selectedCategory.value = 'Toutes les catégories';
    }
    return removed;
  }
}
