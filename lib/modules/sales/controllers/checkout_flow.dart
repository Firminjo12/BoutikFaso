import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../cashier/controllers/cart_controller.dart';
import '../models/sale.dart';
import '../views/payment_method_dialog.dart';
import 'sales_controller.dart';

Future<void> checkoutCart() async {
  final cartController = Get.find<CartController>();
  if (cartController.itemCount == 0) return;

  final payment = await Get.dialog<CheckoutPayment>(
    PaymentMethodDialog(total: cartController.total),
  );
  if (payment == null) return;

  final sale = Get.find<SalesController>().completeSale(payment);
  if (sale == null) {
    Get.snackbar(
      'Vente non enregistrée',
      'Vérifiez le client choisi et les quantités du panier avant de réessayer.',
    );
    return;
  }

  Get.offNamed<void>(AppRoutes.saleConfirmation, arguments: sale);
}
