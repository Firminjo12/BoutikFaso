import 'package:get/get.dart';

import '../../cashier/controllers/cart_controller.dart';
import '../../clients/controllers/clients_controller.dart';
import '../../products/controllers/products_controller.dart';
import '../../stock/controllers/stock_controller.dart';
import '../../stock/models/stock_movement.dart';
import '../models/sale.dart';

class SalesController extends GetxController {
  SalesController({
    required this.cartController,
    required this.productsController,
    required this.stockController,
    required this.clientsController,
  });

  final CartController cartController;
  final ProductsController productsController;
  final StockController stockController;
  final ClientsController clientsController;
  final sales = <Sale>[].obs;

  Sale? completeSale(CheckoutPayment payment) {
    final cartLines = cartController.lines;
    if (cartLines.isEmpty) return null;
    final client = payment.clientId == null
        ? null
        : clientsController.clientById(payment.clientId);
    if (payment.clientId != null && client == null) return null;
    if (payment.method == PaymentMethod.credit && client == null) return null;

    for (final line in cartLines) {
      final product = productsController.products.firstWhereOrNull(
        (item) => item.id == line.product.id,
      );
      if (product == null || line.quantity > product.quantity) return null;
    }

    final now = DateTime.now();
    final suffix = now.microsecondsSinceEpoch.toString().substring(8);
    final receiptNumber =
        'BF${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}-$suffix';
    final lines = cartLines
        .map(
          (line) => SaleLine(
            productId: line.product.id,
            productName: line.product.name,
            quantity: line.quantity,
            unitPrice: line.product.salePrice,
            purchasePrice: line.product.purchasePrice,
          ),
        )
        .toList(growable: false);
    final sale = Sale(
      receiptNumber: receiptNumber,
      date: now,
      paymentMethod: payment.method,
      lines: lines,
      total: lines.fold(0, (sum, line) => sum + line.total),
      clientId: client?.id,
      clientName: client?.name,
    );

    for (final line in lines) {
      final recorded = stockController.recordMovement(
        productId: line.productId,
        type: StockMovementType.exit,
        quantity: line.quantity,
        note: 'Vente $receiptNumber',
      );
      if (!recorded) return null;
    }

    if (client != null) {
      final recorded = payment.method == PaymentMethod.credit
          ? clientsController.registerCreditSale(client.id, sale)
          : clientsController.registerPaidSale(client.id, sale);
      if (!recorded) return null;
    }

    sales.insert(0, sale);
    cartController.clear();
    return sale;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
