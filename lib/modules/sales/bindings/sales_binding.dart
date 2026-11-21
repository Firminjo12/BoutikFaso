import 'package:get/get.dart';

import '../../cashier/bindings/cashier_binding.dart';

class SalesBinding extends Bindings {
  @override
  void dependencies() {
    CashierBinding().dependencies();
  }
}
