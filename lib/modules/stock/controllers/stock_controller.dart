import 'package:get/get.dart';

import '../../products/controllers/products_controller.dart';
import '../../products/models/product.dart';
import '../models/stock_movement.dart';

enum StockMovementFilter { all, entries, exits, losses }

class StockController extends GetxController {
  StockController({required this.productsController});

  final ProductsController productsController;
  final movements = <StockMovement>[].obs;
  final selectedFilter = StockMovementFilter.all.obs;

  int get totalUnits =>
      productsController.products.fold(0, (total, product) => total + product.quantity);

  int get entryUnits => movements
      .where((movement) => movement.type == StockMovementType.entry)
      .fold(0, (total, movement) => total + movement.quantity);

  int get exitUnits => movements
      .where((movement) => movement.type == StockMovementType.exit)
      .fold(0, (total, movement) => total + movement.quantity);

  int get lossUnits => movements
      .where((movement) => movement.type == StockMovementType.loss)
      .fold(0, (total, movement) => total + movement.quantity);

  int get lowStockProducts => productsController.products
      .where((product) => product.stockStatus == ProductStockStatus.low)
      .length;

  int get outOfStockProducts => productsController.products
      .where((product) => product.stockStatus == ProductStockStatus.outOfStock)
      .length;

  List<Product> get alertProducts => productsController.products
      .where((product) => product.stockStatus != ProductStockStatus.available)
      .toList()
    ..sort((a, b) => a.quantity.compareTo(b.quantity));

  List<StockMovement> get filteredMovements => movements.where((movement) {
        return switch (selectedFilter.value) {
          StockMovementFilter.all => true,
          StockMovementFilter.entries => movement.type == StockMovementType.entry,
          StockMovementFilter.exits => movement.type == StockMovementType.exit,
          StockMovementFilter.losses => movement.type == StockMovementType.loss,
        };
      }).toList();

  bool recordMovement({
    required String productId,
    required StockMovementType type,
    required int quantity,
    required String note,
  }) {
    if (quantity < 1) return false;
    final index = productsController.products.indexWhere(
      (product) => product.id == productId,
    );
    if (index == -1) return false;
    final product = productsController.products[index];
    final delta = switch (type) {
      StockMovementType.entry => quantity,
      StockMovementType.exit || StockMovementType.loss => -quantity,
    };
    if (!productsController.adjustProductStock(productId, delta)) return false;

    movements.insert(
      0,
      StockMovement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productId: productId,
        productName: product.name,
        type: type,
        quantity: quantity,
        date: DateTime.now(),
        note: note.trim(),
      ),
    );
    return true;
  }
}
