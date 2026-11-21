import 'package:get/get.dart';

import '../../../core/workspace/merchant_workspace_controller.dart';
import '../../cashier/bindings/cashier_binding.dart';
import '../../expenses/bindings/expenses_binding.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    CashierBinding().dependencies();
    ExpensesBinding().dependencies();
    if (!Get.isRegistered<MerchantWorkspaceController>()) {
      Get.put<MerchantWorkspaceController>(
        MerchantWorkspaceController(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(HomeController(), permanent: true);
    }
  }
}
