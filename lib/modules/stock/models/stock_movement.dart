enum StockMovementType { entry, exit, loss }

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.date,
    required this.note,
  });

  final String id;
  final String productId;
  final String productName;
  final StockMovementType type;
  final int quantity;
  final DateTime date;
  final String note;
}
