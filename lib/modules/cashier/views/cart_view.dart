import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../controllers/cart_controller.dart';
import 'cashier_view.dart';
import '../../sales/controllers/checkout_flow.dart';

class CartView extends GetView<CartController> {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Panier',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 740 ? constraints.maxWidth : 740.0;
          return Center(
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CartPanel(
                  controller: controller,
                  onCheckout: checkoutCart,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
