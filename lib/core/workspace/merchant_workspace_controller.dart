import 'package:get/get.dart';

import '../../modules/cashier/controllers/cart_controller.dart';
import '../../modules/clients/controllers/clients_controller.dart';
import '../../modules/clients/models/client.dart';
import '../../modules/expenses/controllers/expenses_controller.dart';
import '../../modules/expenses/models/expense.dart';
import '../../modules/products/controllers/products_controller.dart';
import '../../modules/products/models/product.dart';
import '../../modules/sales/controllers/sales_controller.dart';
import '../../modules/sales/models/sale.dart';
import '../../modules/stock/controllers/stock_controller.dart';
import '../../modules/stock/models/stock_movement.dart';

class MerchantWorkspace {
  const MerchantWorkspace({
    required this.id,
    required this.name,
    required this.categories,
    required this.products,
    required this.clients,
    required this.transactions,
    required this.movements,
    required this.sales,
    required this.expenses,
  });

  final String id;
  final String name;
  final List<String> categories;
  final List<Product> products;
  final List<Client> clients;
  final List<ClientTransaction> transactions;
  final List<StockMovement> movements;
  final List<Sale> sales;
  final List<Expense> expenses;

  MerchantWorkspace copyWith({
    String? name,
    List<String>? categories,
    List<Product>? products,
    List<Client>? clients,
    List<ClientTransaction>? transactions,
    List<StockMovement>? movements,
    List<Sale>? sales,
    List<Expense>? expenses,
  }) => MerchantWorkspace(
    id: id,
    name: name ?? this.name,
    categories: categories ?? this.categories,
    products: products ?? this.products,
    clients: clients ?? this.clients,
    transactions: transactions ?? this.transactions,
    movements: movements ?? this.movements,
    sales: sales ?? this.sales,
    expenses: expenses ?? this.expenses,
  );
}

class MerchantWorkspaceController extends GetxController {
  late final RxList<MerchantWorkspace> workspaces;
  final activeWorkspaceId = ''.obs;

  MerchantWorkspace get activeWorkspace => workspaces.firstWhere(
    (workspace) => workspace.id == activeWorkspaceId.value,
  );

  @override
  void onInit() {
    super.onInit();
    final initial = _capture('merchant-default', 'Ma boutique');
    workspaces = <MerchantWorkspace>[initial].obs;
    activeWorkspaceId.value = initial.id;
  }

  String? addWorkspace(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty ||
        workspaces.any(
          (workspace) =>
              workspace.name.toLowerCase() == cleanName.toLowerCase(),
        )) {
      return null;
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    workspaces.add(
      MerchantWorkspace(
        id: id,
        name: cleanName,
        categories: const ['Vivres', 'Hygiène', 'Boissons'],
        products: const [],
        clients: const [],
        transactions: const [],
        movements: const [],
        sales: const [],
        expenses: const [],
      ),
    );
    return id;
  }

  bool switchTo(String id) {
    if (id == activeWorkspaceId.value ||
        !workspaces.any((workspace) => workspace.id == id)) {
      return false;
    }
    _saveCurrent();
    final target = workspaces.firstWhere((workspace) => workspace.id == id);
    Get.find<ProductsController>()
      ..categories.assignAll(target.categories)
      ..products.assignAll(target.products)
      ..selectedCategory.value = 'Toutes les catégories'
      ..selectedStatus.value = ProductStatusFilter.all
      ..searchQuery.value = '';
    Get.find<ClientsController>()
      ..clients.assignAll(target.clients)
      ..transactions.assignAll(target.transactions)
      ..selectedClientId.value = target.clients.firstOrNull?.id ?? ''
      ..searchQuery.value = '';
    Get.find<StockController>().movements.assignAll(target.movements);
    Get.find<SalesController>().sales.assignAll(target.sales);
    Get.find<ExpensesController>()
      ..expenses.assignAll(target.expenses)
      ..selectedFilter.value = 'Toutes';
    Get.find<CartController>()
      ..clear()
      ..searchQuery.value = ''
      ..selectedCategory.value = 'Toutes';
    activeWorkspaceId.value = id;
    return true;
  }

  void _saveCurrent() {
    final index = workspaces.indexWhere(
      (item) => item.id == activeWorkspaceId.value,
    );
    if (index == -1) return;
    workspaces[index] = _capture(activeWorkspaceId.value, activeWorkspace.name);
  }

  MerchantWorkspace _capture(String id, String name) => MerchantWorkspace(
    id: id,
    name: name,
    categories: Get.find<ProductsController>().categories.toList(),
    products: Get.find<ProductsController>().products.toList(),
    clients: Get.find<ClientsController>().clients.toList(),
    transactions: Get.find<ClientsController>().transactions.toList(),
    movements: Get.find<StockController>().movements.toList(),
    sales: Get.find<SalesController>().sales.toList(),
    expenses: Get.find<ExpensesController>().expenses.toList(),
  );
}
