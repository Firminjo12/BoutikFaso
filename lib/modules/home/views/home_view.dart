import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../clients/controllers/clients_controller.dart';
import '../../clients/models/client.dart';
import '../../products/models/product.dart';
import '../../sales/models/sale.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Tableau de bord',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final homeController = controller;
        final wide = constraints.maxWidth >= 900;
        final contentWidth = constraints.maxWidth - (wide ? 52 : 32);
        final half = (contentWidth - (wide ? 12 : 0)) / (wide ? 2 : 1);
        return Obx(() {
          homeController.revision.value;
          return ListView(
            padding: EdgeInsets.all(wide ? 26 : 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour, bienvenue dans votre boutique',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Voici le résumé de votre activité commerciale.',
                        ),
                      ],
                    ),
                  ),
                  if (wide)
                    FilledButton.icon(
                      onPressed: () => Get.toNamed<void>(AppRoutes.sales),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle vente'),
                    ),
                ],
              ),
              if (!wide) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Get.toNamed<void>(AppRoutes.sales),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle vente'),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: _metricWidth(contentWidth),
                    label: 'Chiffre d’affaires aujourd’hui',
                    value: _money(homeController.revenueToday),
                    icon: Icons.trending_up,
                    accent: AppColors.primary,
                  ),
                  _Metric(
                    width: _metricWidth(contentWidth),
                    label: 'Nombre de ventes',
                    value: '${homeController.salesToday}',
                    icon: Icons.point_of_sale_outlined,
                    accent: AppColors.accent,
                  ),
                  _Metric(
                    width: _metricWidth(contentWidth),
                    label: 'Dettes clients',
                    value: _money(homeController.outstandingDebts),
                    icon: Icons.account_balance_wallet_outlined,
                    accent: AppColors.error,
                  ),
                  _Metric(
                    width: _metricWidth(contentWidth),
                    label: 'Alertes de stock',
                    value: '${homeController.stockAlertCount} produit(s)',
                    icon: Icons.warning_amber_rounded,
                    accent: homeController.stockAlertCount > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                  if (wide || homeController.showMore.value)
                    _Metric(
                      width: _metricWidth(contentWidth),
                      label: 'Bénéfice estimatif',
                      value: _money(homeController.estimatedProfitToday),
                      icon: Icons.savings_outlined,
                      accent: homeController.estimatedProfitToday < 0
                          ? AppColors.error
                          : AppColors.success,
                    ),
                ],
              ),
              if (!wide) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => homeController.showMore.toggle(),
                    icon: Icon(
                      homeController.showMore.value
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    label: Text(
                      homeController.showMore.value
                          ? 'Voir moins'
                          : 'Voir plus',
                    ),
                  ),
                ),
              ],
              if (wide || homeController.showMore.value) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    SizedBox(
                      width: half,
                      child: SectionCard(
                        title: 'Ventes des 7 derniers jours',
                        child: _SalesChart(
                          values: homeController.lastSevenDaysRevenue,
                          labels: homeController.lastSevenDaysLabels,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: half,
                      child: SectionCard(
                        title: 'Produits les plus vendus',
                        child: _BestSellers(
                          items: homeController.bestSellers.take(5).toList(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: half,
                      child: SectionCard(
                        title: 'Alertes de stock',
                        trailing: TextButton(
                          onPressed: () => Get.toNamed<void>(AppRoutes.stock),
                          child: const Text('Voir le stock'),
                        ),
                        child: _StockAlerts(
                          products: homeController.stockController.alertProducts
                              .take(4)
                              .toList(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: half,
                      child: SectionCard(
                        title: 'Dernières ventes',
                        trailing: TextButton(
                          onPressed: () => Get.toNamed<void>(AppRoutes.sales),
                          child: const Text('Ouvrir la caisse'),
                        ),
                        child: _LatestSales(items: homeController.latestSales),
                      ),
                    ),
                    SizedBox(
                      width: half,
                      child: SectionCard(
                        title: 'Derniers remboursements',
                        trailing: TextButton(
                          onPressed: () => Get.toNamed<void>(AppRoutes.debts),
                          child: const Text('Voir les dettes'),
                        ),
                        child: _Repayments(
                          items: homeController.latestRepayments
                              .take(4)
                              .toList(),
                          clients: homeController.clientsController,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: half,
                      child: SectionCard(
                        title: 'Dépenses du jour',
                        trailing: TextButton(
                          onPressed: () =>
                              Get.toNamed<void>(AppRoutes.expenses),
                          child: const Text('Gérer'),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_money(homeController.expensesToday)} enregistrés aujourd’hui',
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bénéfice estimatif = marge des articles vendus − dépenses enregistrées aujourd’hui. Les ventes et dépenses restent en mémoire pendant cette session.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ],
          );
        });
      },
    ),
  );

  double _metricWidth(double width) => width >= 1050
      ? (width - 36) / 4
      : width >= 600
      ? (width - 12) / 2
      : width;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: accent),
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

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.values, required this.labels});
  final List<int> values;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[index] == 0 ? '—' : _compactMoney(values[index]),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: maxValue == 0
                          ? 6
                          : 95 * values[index] / maxValue + 6,
                      decoration: BoxDecoration(
                        color: index == values.length - 1
                            ? AppColors.primary
                            : AppColors.surfaceTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BestSellers extends StatelessWidget {
  const _BestSellers({required this.items});
  final List<({String name, int quantity, int revenue})> items;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const _Empty('Les ventes apparaîtront ici.')
      : Column(
          children: [
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${item.quantity} vendu(s)'),
                trailing: Text(
                  _money(item.revenue),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
          ],
        );
}

class _StockAlerts extends StatelessWidget {
  const _StockAlerts({required this.products});
  final List<Product> products;
  @override
  Widget build(BuildContext context) => products.isEmpty
      ? const _Empty('Aucun produit en alerte.')
      : Column(
          children: [
            for (final product in products)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  product.quantity == 0
                      ? Icons.error_outline
                      : Icons.warning_amber_rounded,
                  color: product.quantity == 0
                      ? AppColors.error
                      : AppColors.warning,
                ),
                title: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  product.quantity == 0 ? 'Rupture de stock' : 'Stock faible',
                ),
                trailing: Text(
                  '${product.quantity} restant(s)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
}

class _LatestSales extends StatelessWidget {
  const _LatestSales({required this.items});
  final List<Sale> items;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const _Empty('Aucune vente pour le moment.')
      : Column(
          children: [
            for (final sale in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.receipt_outlined,
                  color: AppColors.primary,
                ),
                title: Text(sale.clientName ?? sale.receiptNumber),
                subtitle: Text(
                  '${sale.itemCount} article(s) · ${_time(sale.date)}',
                ),
                trailing: Text(
                  _money(sale.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        );
}

class _Repayments extends StatelessWidget {
  const _Repayments({required this.items, required this.clients});
  final List<ClientTransaction> items;
  final ClientsController clients;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const _Empty('Aucun remboursement enregistré.')
      : Column(
          children: [
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.call_received,
                  color: AppColors.success,
                ),
                title: Text(
                  clients.clientById(item.clientId)?.name ?? 'Client',
                ),
                subtitle: Text(_time(item.date)),
                trailing: Text(
                  _money(item.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
          ],
        );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(message, style: const TextStyle(color: AppColors.muted)),
    ),
  );
}

String _money(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+$)'), (_) => ' ')} F';
String _compactMoney(int value) => value >= 1000000
    ? '${(value / 1000000).toStringAsFixed(1)}M'
    : value >= 1000
    ? '${(value / 1000).toStringAsFixed(0)}k'
    : '$value';
String _time(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
