import 'package:get/get.dart';

import '../../sales/models/sale.dart';
import '../models/client.dart';

class ClientsController extends GetxController {
  final clients = <Client>[].obs;
  final transactions = <ClientTransaction>[].obs;
  final searchQuery = ''.obs;
  final selectedClientId = 'client-1'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDemoData();
  }

  int get totalOutstanding =>
      clients.fold(0, (total, client) => total + client.outstandingBalance);

  int get clientsWithDebt =>
      clients.where((client) => client.outstandingBalance > 0).length;

  int get repaymentsToday {
    final now = DateTime.now();
    return transactions
        .where(
          (transaction) =>
              transaction.type == ClientTransactionType.repayment &&
              transaction.date.year == now.year &&
              transaction.date.month == now.month &&
              transaction.date.day == now.day,
        )
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  List<Client> get filteredClients {
    final query = searchQuery.value.trim().toLowerCase();
    return clients.where((client) {
      return query.isEmpty ||
          client.name.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query);
    }).toList();
  }

  Client? get selectedClient => clientById(selectedClientId.value);

  Client? clientById(String? id) =>
      clients.firstWhereOrNull((client) => client.id == id);

  List<ClientTransaction> transactionsFor(String clientId) =>
      transactions
          .where((transaction) => transaction.clientId == clientId)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  bool addClient({
    required String name,
    required String phone,
    String address = '',
  }) {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    if (cleanName.isEmpty || cleanPhone.isEmpty) return false;
    if (clients.any((client) => client.phone == cleanPhone)) return false;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    clients.insert(
      0,
      Client(
        id: id,
        name: cleanName,
        phone: cleanPhone,
        address: address.trim(),
        totalPurchases: 0,
        outstandingBalance: 0,
      ),
    );
    selectedClientId.value = id;
    return true;
  }

  bool updateClient({
    required String id,
    required String name,
    required String phone,
    required String address,
  }) {
    final index = clients.indexWhere((client) => client.id == id);
    if (index == -1 || name.trim().isEmpty || phone.trim().isEmpty) {
      return false;
    }
    if (clients.any(
      (client) => client.id != id && client.phone == phone.trim(),
    )) {
      return false;
    }
    clients[index] = clients[index].copyWith(
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
    );
    return true;
  }

  bool deleteClient(String id) {
    final client = clientById(id);
    if (client == null ||
        client.outstandingBalance > 0 ||
        client.totalPurchases > 0) {
      return false;
    }
    clients.removeWhere((item) => item.id == id);
    if (selectedClientId.value == id) {
      selectedClientId.value = clients.firstOrNull?.id ?? '';
    }
    return true;
  }

  bool registerCreditSale(String clientId, Sale sale) {
    final index = clients.indexWhere((client) => client.id == clientId);
    if (index == -1) return false;
    final client = clients[index];
    clients[index] = client.copyWith(
      totalPurchases: client.totalPurchases + sale.total,
      outstandingBalance: client.outstandingBalance + sale.total,
      lastActivity: sale.date,
    );
    transactions.insert(
      0,
      ClientTransaction(
        id: '${sale.receiptNumber}-credit',
        clientId: clientId,
        type: ClientTransactionType.creditSale,
        amount: sale.total,
        date: sale.date,
        description: 'Vente à crédit · ${sale.itemCount} article(s)',
        saleReference: sale.receiptNumber,
      ),
    );
    return true;
  }

  bool registerPaidSale(String clientId, Sale sale) {
    final index = clients.indexWhere((client) => client.id == clientId);
    if (index == -1 || sale.paymentMethod == PaymentMethod.credit) return false;
    final client = clients[index];
    clients[index] = client.copyWith(
      totalPurchases: client.totalPurchases + sale.total,
      lastActivity: sale.date,
    );
    transactions.insert(
      0,
      ClientTransaction(
        id: '${sale.receiptNumber}-paid',
        clientId: clientId,
        type: ClientTransactionType.paidSale,
        amount: sale.total,
        date: sale.date,
        description: 'Achat payé · ${sale.paymentMethod.label}',
        saleReference: sale.receiptNumber,
      ),
    );
    return true;
  }

  bool recordRepayment({
    required String clientId,
    required int amount,
    required String method,
    required String note,
  }) {
    final index = clients.indexWhere((client) => client.id == clientId);
    if (index == -1 || amount <= 0) return false;
    final client = clients[index];
    if (amount > client.outstandingBalance) return false;
    final now = DateTime.now();
    clients[index] = client.copyWith(
      outstandingBalance: client.outstandingBalance - amount,
      lastActivity: now,
    );
    transactions.insert(
      0,
      ClientTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        clientId: clientId,
        type: ClientTransactionType.repayment,
        amount: amount,
        date: now,
        description: note.trim().isEmpty
            ? 'Remboursement · $method'
            : '${note.trim()} · $method',
      ),
    );
    return true;
  }

  void _loadDemoData() {
    final now = DateTime.now();
    clients.assignAll([
      Client(
        id: 'client-1',
        name: 'Aminata Sawadogo',
        phone: '70 22 31 42',
        address: 'Ouagadougou',
        totalPurchases: 141350,
        outstandingBalance: 4250,
        lastActivity: now.subtract(const Duration(hours: 3)),
      ),
      Client(
        id: 'client-2',
        name: 'Issaka Kaboré',
        phone: '70 10 11 45',
        address: 'Ouagadougou',
        totalPurchases: 65000,
        outstandingBalance: 12000,
        lastActivity: now.subtract(const Duration(days: 1)),
      ),
      Client(
        id: 'client-3',
        name: 'Moussa Ouedraogo',
        phone: '70 45 32 29',
        address: 'Ouagadougou',
        totalPurchases: 48000,
        outstandingBalance: 7500,
        lastActivity: now.subtract(const Duration(days: 4)),
      ),
      Client(
        id: 'client-4',
        name: 'Boubou Zongo',
        phone: '61 25 71 34',
        address: 'Ouagadougou',
        totalPurchases: 33200,
        outstandingBalance: 0,
        lastActivity: now.subtract(const Duration(days: 8)),
      ),
    ]);
    transactions.assignAll([
      ClientTransaction(
        id: 'credit-aminata',
        clientId: 'client-1',
        type: ClientTransactionType.creditSale,
        amount: 4250,
        date: now.subtract(const Duration(hours: 3)),
        description: 'Achat à crédit',
      ),
      ClientTransaction(
        id: 'credit-issaka',
        clientId: 'client-2',
        type: ClientTransactionType.creditSale,
        amount: 15000,
        date: now.subtract(const Duration(days: 2)),
        description: 'Achat à crédit',
      ),
      ClientTransaction(
        id: 'repayment-issaka',
        clientId: 'client-2',
        type: ClientTransactionType.repayment,
        amount: 3000,
        date: now.subtract(const Duration(days: 1)),
        description: 'Remboursement partiel · Orange Money',
      ),
      ClientTransaction(
        id: 'credit-moussa',
        clientId: 'client-3',
        type: ClientTransactionType.creditSale,
        amount: 7500,
        date: now.subtract(const Duration(days: 4)),
        description: 'Achat à crédit',
      ),
    ]);
  }
}
