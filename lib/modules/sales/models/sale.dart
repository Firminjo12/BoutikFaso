enum PaymentMethod { cash, orangeMoney, moovMoney, credit }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Espèces',
        PaymentMethod.orangeMoney => 'Orange Money',
        PaymentMethod.moovMoney => 'Moov Money',
        PaymentMethod.credit => 'Crédit client',
      };
}

class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.purchasePrice = 0,
  });

  final String productId;
  final String productName;
  final int quantity;
  final int unitPrice;
  final int purchasePrice;

  int get total => quantity * unitPrice;
  int get estimatedMargin => quantity * (unitPrice - purchasePrice);
}

class Sale {
  const Sale({
    required this.receiptNumber,
    required this.date,
    required this.paymentMethod,
    required this.lines,
    required this.total,
    this.clientId,
    this.clientName,
  });

  final String receiptNumber;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final List<SaleLine> lines;
  final int total;
  final String? clientId;
  final String? clientName;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
}

class CheckoutPayment {
  const CheckoutPayment({required this.method, this.clientId});

  final PaymentMethod method;
  final String? clientId;
}
