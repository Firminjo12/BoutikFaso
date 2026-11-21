import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/expenses_controller.dart';
import '../models/expense.dart';

class ExpensesView extends GetView<ExpensesController> {
  const ExpensesView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Dépenses',
    child: LayoutBuilder(
      builder: (context, constraints) => Obx(() {
        final compact = constraints.maxWidth < 680;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suivi des dépenses',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enregistrez les sorties d’argent de la boutique.',
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => _addExpense(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une dépense'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  width: compact ? constraints.maxWidth - 40 : 210,
                  label: 'Dépenses du jour',
                  value: _money(controller.todayTotal),
                  icon: Icons.today_outlined,
                  color: AppColors.error,
                ),
                _MetricCard(
                  width: compact ? constraints.maxWidth - 40 : 210,
                  label: 'Ce mois-ci',
                  value: _money(controller.monthTotal),
                  icon: Icons.calendar_month_outlined,
                ),
                _MetricCard(
                  width: compact ? constraints.maxWidth - 40 : 210,
                  label: 'Nombre de dépenses',
                  value: '${controller.expenses.length}',
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in [
                  'Toutes',
                  ...ExpensesController.categories,
                ])
                  ChoiceChip(
                    label: Text(category),
                    selected: controller.selectedFilter.value == category,
                    onSelected: (_) =>
                        controller.selectedFilter.value = category,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            controller.filteredExpenses.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 36,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            controller.expenses.isEmpty
                                ? 'Aucune dépense enregistrée'
                                : 'Aucune dépense dans cette catégorie',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ajoutez une dépense pour suivre les sorties et estimer le bénéfice.',
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        if (!compact)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: Text('Description')),
                                Expanded(flex: 2, child: Text('Catégorie')),
                                Expanded(flex: 2, child: Text('Date')),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Montant',
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(width: 48),
                              ],
                            ),
                          ),
                        for (
                          var i = 0;
                          i < controller.filteredExpenses.length;
                          i++
                        ) ...[
                          if (i > 0) const Divider(height: 1),
                          _ExpenseRow(
                            expense: controller.filteredExpenses[i],
                            compact: compact,
                          ),
                        ],
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total affiché',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                _money(
                                  controller.filteredExpenses.fold(
                                    0,
                                    (sum, item) => sum + item.amount,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        );
      }),
    ),
  );

  Future<void> _addExpense(BuildContext context) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var category = ExpensesController.categories.first;
    var date = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter une dépense'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: description,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Ex. transport livraison',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Montant (F CFA)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: [
                      for (final item in ExpensesController.categories)
                        DropdownMenuItem(value: item, child: Text(item)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => category = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(_date(date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Note (facultatif)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(
                  amount.text.replaceAll(RegExp(r'\s'), ''),
                );
                if (description.text.trim().isEmpty ||
                    value == null ||
                    value <= 0) {
                  Get.snackbar(
                    'Informations incomplètes',
                    'Saisissez une description et un montant supérieur à zéro.',
                  );
                  return;
                }
                controller.addExpense(
                  description: description.text,
                  category: category,
                  amount: value,
                  date: date,
                  note: note.text,
                );
                Navigator.pop(context, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    description.dispose();
    amount.dispose();
    note.dispose();
    if (saved == true) {
      Get.snackbar(
        'Dépense enregistrée',
        'Elle est prise en compte dans l’estimation du bénéfice.',
      );
    }
  }
}

class _ExpenseRow extends GetView<ExpensesController> {
  const _ExpenseRow({required this.expense, required this.compact});
  final Expense expense;
  final bool compact;
  @override
  Widget build(BuildContext context) => compact
      ? ListTile(
          leading: const Icon(Icons.receipt_outlined, color: AppColors.muted),
          title: Text(expense.description),
          subtitle: Text('${expense.category} · ${_date(expense.date)}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(expense.amount),
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => controller.deleteExpense(expense.id),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        )
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.description),
                    if (expense.note.isNotEmpty)
                      Text(
                        expense.note,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Expanded(flex: 2, child: Text(expense.category)),
              Expanded(flex: 2, child: Text(_date(expense.date))),
              Expanded(
                flex: 2,
                child: Text(
                  _money(expense.amount),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => controller.deleteExpense(expense.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ],
          ),
        );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _money(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+$)'), (_) => ' ')} F';
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
