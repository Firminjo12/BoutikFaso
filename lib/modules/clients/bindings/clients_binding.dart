import 'package:get/get.dart';

import '../controllers/clients_controller.dart';

class ClientsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ClientsController>()) {
      Get.put<ClientsController>(ClientsController(), permanent: true);
    }
  }
}
