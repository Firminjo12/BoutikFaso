class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalPurchases,
    required this.outstandingBalance,
    this.address = '',
    this.lastActivity,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final int totalPurchases;
  final int outstandingBalance;
  final DateTime? lastActivity;

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    int? totalPurchases,
    int? outstandingBalance,
    DateTime? lastActivity,
  }) =>
      Client(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        totalPurchases: totalPurchases ?? this.totalPurchases,
        outstandingBalance: outstandingBalance ?? this.outstandingBalance,
        lastActivity: lastActivity ?? this.lastActivity,
      );
}

enum ClientTransactionType { creditSale, repayment, paidSale }

class ClientTransaction {
  const ClientTransaction({
    required this.id,
    required this.clientId,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.saleReference,
  });

  final String id;
  final String clientId;
  final ClientTransactionType type;
  final int amount;
  final DateTime date;
  final String description;
  final String? saleReference;
}
