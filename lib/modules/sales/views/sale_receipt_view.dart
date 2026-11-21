import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sale.dart';

class SaleReceiptView extends StatelessWidget {
  const SaleReceiptView({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments;
    final sale = arguments is Sale ? arguments : null;
    return AppShell(
      title: 'Reçu de vente',
      child: sale == null
          ? const Center(child: Text('Reçu introuvable.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 520
                    ? constraints.maxWidth
                    : 480.0;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.storefront_rounded,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Boutik Faso',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  Text('Reçu de vente',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                  const SizedBox(height: 18),
                                  const Divider(),
                                  const SizedBox(height: 10),
                                  _ReceiptDetail(
                                    label: 'Référence',
                                    value: sale.receiptNumber,
                                  ),
                                  const SizedBox(height: 7),
                                  _ReceiptDetail(
                                    label: 'Date',
                                    value: _formatDate(sale.date),
                                  ),
                                  const SizedBox(height: 7),
                                  _ReceiptDetail(
                                    label: 'Paiement',
                                    value: sale.paymentMethod.label,
                                  ),
                                  if (sale.clientName != null) ...[
                                    const SizedBox(height: 7),
                                    _ReceiptDetail(label: 'Client', value: sale.clientName!),
                                    const SizedBox(height: 7),
                                    _ReceiptDetail(label: 'À régler', value: _formatFcfa(sale.total)),
                                  ],
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  for (final line in sale.lines) ...[
                                    _ReceiptItem(line: line),
                                    const SizedBox(height: 10),
                                  ],
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('TOTAL',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                      ),
                                      Text(
                                        _formatFcfa(sale.total),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Text(sale.paymentMethod == PaymentMethod.credit
                                      ? 'Merci pour votre confiance.'
                                      : 'Merci pour votre achat !',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  Get.offNamed<void>(AppRoutes.sales),
                              icon: const Icon(Icons.point_of_sale_outlined),
                              label: const Text('Nouvelle vente'),
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reçu enregistré sur cet appareil. Aucun paiement mobile externe n’a été exécuté.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _ReceiptItem extends StatelessWidget {
  const _ReceiptItem({required this.line});

  final SaleLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text('${line.productName} × ${line.quantity}',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(_formatFcfa(line.total),
            style: Theme.of(context).textTheme.bodyLarge),
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
