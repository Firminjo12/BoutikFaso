import 'package:get/get.dart';

import '../../products/controllers/products_controller.dart';
import '../../clients/controllers/clients_controller.dart';
import '../../sales/controllers/sales_controller.dart';
import '../../stock/controllers/stock_controller.dart';
import '../controllers/cart_controller.dart';

class CashierBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProductsController>()) {
      Get.put<ProductsController>(ProductsController(), permanent: true);
    }
    if (!Get.isRegistered<CartController>()) {
      Get.put<CartController>(
        CartController(productsController: Get.find<ProductsController>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<StockController>()) {
      Get.put<StockController>(
        StockController(productsController: Get.find<ProductsController>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ClientsController>()) {
      Get.put<ClientsController>(ClientsController(), permanent: true);
    }
    if (!Get.isRegistered<SalesController>()) {
      Get.put<SalesController>(
        SalesController(
          cartController: Get.find<CartController>(),
          productsController: Get.find<ProductsController>(),
          stockController: Get.find<StockController>(),
          clientsController: Get.find<ClientsController>(),
        ),
        permanent: true,
      );
    }
  }
}
