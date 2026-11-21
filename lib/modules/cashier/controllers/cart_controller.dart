import 'package:get/get.dart';

import '../../products/controllers/products_controller.dart';
import '../../products/models/product.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  int get total => product.salePrice * quantity;
}

class CartController extends GetxController {
  CartController({required this.productsController});

  final ProductsController productsController;
  final quantities = <String, int>{}.obs;
  final searchQuery = ''.obs;
  final selectedCategory = 'Toutes'.obs;
  Worker? _productsWorker;

  @override
  void onInit() {
    super.onInit();
    _productsWorker = ever<List<Product>>(
      productsController.products,
      _reconcileWithCatalogue,
    );
  }

  @override
  void onClose() {
    _productsWorker?.dispose();
    super.onClose();
  }

  List<Product> get filteredProducts {
    final query = searchQuery.value.trim().toLowerCase();
    return productsController.products.where((product) {
      final matchesQuery = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
      final matchesCategory = selectedCategory.value == 'Toutes' ||
          product.category == selectedCategory.value;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<CartLine> get lines {
    final result = <CartLine>[];
    for (final product in productsController.products) {
      final quantity = quantities[product.id] ?? 0;
      if (quantity > 0) result.add(CartLine(product: product, quantity: quantity));
    }
    return result;
  }

  int get itemCount => quantities.values.fold(0, (sum, quantity) => sum + quantity);
  int get total => lines.fold(0, (sum, line) => sum + line.total);

  bool addProduct(Product product) {
    final current = quantities[product.id] ?? 0;
    if (current >= product.quantity) return false;
    quantities[product.id] = current + 1;
    return true;
  }

  bool increase(String productId) {
    final product = productsController.products
        .firstWhereOrNull((item) => item.id == productId);
    if (product == null) return false;
    final current = quantities[productId] ?? 0;
    if (current >= product.quantity) return false;
    quantities[productId] = current + 1;
    return true;
  }

  void decrease(String productId) {
    final current = quantities[productId] ?? 0;
    if (current <= 1) {
      quantities.remove(productId);
    } else {
      quantities[productId] = current - 1;
    }
  }

  void remove(String productId) => quantities.remove(productId);

  void clear() => quantities.clear();

  void _reconcileWithCatalogue(List<Product> products) {
    final byId = {for (final product in products) product.id: product};
    for (final productId in quantities.keys.toList()) {
      final product = byId[productId];
      if (product == null || product.quantity == 0) {
        quantities.remove(productId);
      } else if (quantities[productId]! > product.quantity) {
        quantities[productId] = product.quantity;
      }
    }
    if (selectedCategory.value != 'Toutes' &&
        !productsController.categories.contains(selectedCategory.value)) {
      selectedCategory.value = 'Toutes';
    }
  }
}
