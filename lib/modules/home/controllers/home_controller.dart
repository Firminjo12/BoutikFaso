import 'package:get/get.dart';

import '../../clients/controllers/clients_controller.dart';
import '../../clients/models/client.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../products/controllers/products_controller.dart';
import '../../sales/controllers/sales_controller.dart';
import '../../sales/models/sale.dart';
import '../../stock/controllers/stock_controller.dart';

class HomeController extends GetxController {
  final message = 'Votre commerce, près de chez vous.'.obs;
  final revision = 0.obs;
  final showMore = false.obs;
  final List<Worker> _workers = [];

  @override
  void onInit() {
    super.onInit();
    _workers.addAll([
      ever(salesController.sales, (_) => _refreshDashboard()),
      ever(expensesController.expenses, (_) => _refreshDashboard()),
      ever(clientsController.clients, (_) => _refreshDashboard()),
      ever(clientsController.transactions, (_) => _refreshDashboard()),
      ever(productsController.products, (_) => _refreshDashboard()),
    ]);
  }

  void _refreshDashboard() => revision.value++;

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    super.onClose();
  }

  SalesController get salesController => Get.find<SalesController>();
  ExpensesController get expensesController => Get.find<ExpensesController>();
  ClientsController get clientsController => Get.find<ClientsController>();
  ProductsController get productsController => Get.find<ProductsController>();
  StockController get stockController => Get.find<StockController>();

  int get revenueToday =>
      salesForDay(DateTime.now()).fold(0, (sum, sale) => sum + sale.total);
  int get salesToday => salesForDay(DateTime.now()).length;
  int get expensesToday => expensesController.todayTotal;
  int get estimatedProfitToday =>
      salesForDay(DateTime.now()).fold(
        0,
        (sum, sale) =>
            sum +
            sale.lines.fold(
              0,
              (lineSum, line) => lineSum + line.estimatedMargin,
            ),
      ) -
      expensesToday;
  int get outstandingDebts => clientsController.totalOutstanding;
  int get stockAlertCount => stockController.alertProducts.length;

  List<int> get lastSevenDaysRevenue => List.generate(7, (index) {
    final date = DateTime.now().subtract(Duration(days: 6 - index));
    return salesForDay(date).fold(0, (sum, sale) => sum + sale.total);
  });

  List<String> get lastSevenDaysLabels => List.generate(7, (index) {
    final date = DateTime.now().subtract(Duration(days: 6 - index));
    const labels = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
    return labels[date.weekday - 1];
  });

  List<({String name, int quantity, int revenue})> get bestSellers {
    final totals = <String, ({int quantity, int revenue})>{};
    for (final sale in salesController.sales) {
      for (final line in sale.lines) {
        final current = totals[line.productName] ?? (quantity: 0, revenue: 0);
        totals[line.productName] = (
          quantity: current.quantity + line.quantity,
          revenue: current.revenue + line.total,
        );
      }
    }
    return totals.entries
        .map(
          (entry) => (
            name: entry.key,
            quantity: entry.value.quantity,
            revenue: entry.value.revenue,
          ),
        )
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
  }

  List<Sale> get latestSales => salesController.sales.take(5).toList();
  List<ClientTransaction> get latestRepayments =>
      clientsController.transactions
          .where((item) => item.type == ClientTransactionType.repayment)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Sale> salesForDay(DateTime day) => salesController.sales
      .where(
        (sale) =>
            sale.date.year == day.year &&
            sale.date.month == day.month &&
            sale.date.day == day.day,
      )
      .toList();
}
