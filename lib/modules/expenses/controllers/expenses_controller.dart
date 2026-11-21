import 'package:get/get.dart';

import '../models/expense.dart';

class ExpensesController extends GetxController {
  final expenses = <Expense>[].obs;
  final selectedFilter = 'Toutes'.obs;

  static const categories = <String>[
    'Approvisionnement',
    'Transport',
    'Électricité',
    'Loyer',
    'Emballage',
    'Autres',
  ];

  List<Expense> get filteredExpenses {
    final items = expenses.where((expense) => selectedFilter.value == 'Toutes' || expense.category == selectedFilter.value).toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  int get total => expenses.fold(0, (sum, item) => sum + item.amount);

  int get todayTotal {
    final now = DateTime.now();
    return expenses.where((item) => _sameDay(item.date, now)).fold(0, (sum, item) => sum + item.amount);
  }

  int get monthTotal {
    final now = DateTime.now();
    return expenses.where((item) => item.date.year == now.year && item.date.month == now.month).fold(0, (sum, item) => sum + item.amount);
  }

  void addExpense({required String description, required String category, required int amount, required DateTime date, String note = ''}) {
    expenses.insert(0, Expense(id: DateTime.now().microsecondsSinceEpoch.toString(), description: description.trim(), category: category, amount: amount, date: date, note: note.trim()));
  }

  void deleteExpense(String id) => expenses.removeWhere((item) => item.id == id);

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
