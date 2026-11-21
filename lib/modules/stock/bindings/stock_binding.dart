import 'package:get/get.dart';

import '../../products/controllers/products_controller.dart';
import '../controllers/stock_controller.dart';

class StockBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProductsController>()) {
      Get.put<ProductsController>(ProductsController(), permanent: true);
    }
    if (!Get.isRegistered<StockController>()) {
      Get.put<StockController>(
        StockController(productsController: Get.find<ProductsController>()),
        permanent: true,
      );
    }
  }
}
