import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/section_card.dart';
import '../controllers/sales_controller.dart';
import '../models/sale.dart';

class SaleConfirmationView extends GetView<SalesController> {
  const SaleConfirmationView({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments;
    final sale = arguments is Sale ? arguments : controller.sales.firstOrNull;
    return AppShell(
      title: 'Vente enregistrée',
      child: sale == null
          ? const Center(child: Text('Aucune vente à afficher.'))
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTint,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              const CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.check,
                                    color: Colors.white, size: 30),
                              ),
                              const SizedBox(height: 12),
                              Text('Vente enregistrée avec succès',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge),
                              const SizedBox(height: 4),
                              Text('Reçu ${sale.receiptNumber}',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Détails du paiement',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: sale.paymentMethod == PaymentMethod.credit
                                    ? 'Montant à régler'
                                    : 'Total encaissé',
                                value: _formatFcfa(sale.total),
                                emphasize: true,
                              ),
                              const Divider(height: 20),
                              _DetailRow(
                                label: 'Mode de paiement',
                                value: sale.paymentMethod.label,
                              ),
                              if (sale.clientName != null) ...[
                                const SizedBox(height: 8),
                                _DetailRow(label: 'Client', value: sale.clientName!),
                                const SizedBox(height: 8),
                                _DetailRow(label: 'Solde ajouté aux dettes', value: _formatFcfa(sale.total)),
                              ],
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: 'Date',
                                value: _formatDate(sale.date),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Articles vendus (${sale.lines.length})',
                          child: Column(
                            children: [
                              for (var index = 0;
                                  index < sale.lines.length;
                                  index++) ...[
                                if (index > 0) const Divider(height: 18),
                                _SaleLineRow(line: sale.lines[index]),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (constraints.maxWidth > 500)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Get.toNamed<void>(
                                    AppRoutes.saleReceipt,
                                    arguments: sale,
                                  ),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('Voir le reçu'),
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppButton(
                                  label: 'Nouvelle vente',
                                  icon: Icons.add_shopping_cart,
                                  expanded: true,
                                  onPressed: () =>
                                      Get.offNamed<void>(AppRoutes.sales),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              AppButton(
                                label: 'Nouvelle vente',
                                icon: Icons.add_shopping_cart,
                                expanded: true,
                                onPressed: () =>
                                    Get.offNamed<void>(AppRoutes.sales),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Get.toNamed<void>(
                                    AppRoutes.saleReceipt,
                                    arguments: sale,
                                  ),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('Voir le reçu'),
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48)),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: emphasize
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                  )
              : Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _SaleLineRow extends StatelessWidget {
  const _SaleLineRow({required this.line});

  final SaleLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('${line.productName} × ${line.quantity}',
              style: Theme.of(context).textTheme.bodyLarge),
        ),
        Text(_formatFcfa(line.total),
            style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

String _formatFcfa(int value) {
  final digits = value.toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write(' ');
    result.write(digits[index]);
  }
  return '${result.toString()} F';
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
