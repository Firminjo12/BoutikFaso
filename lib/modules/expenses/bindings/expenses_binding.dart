import 'package:get/get.dart';

import '../controllers/expenses_controller.dart';

class ExpensesBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ExpensesController>()) {
      Get.put<ExpensesController>(ExpensesController(), permanent: true);
    }
  }
}
