class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final String description;
  final String category;
  final int amount;
  final DateTime date;
  final String note;
}
