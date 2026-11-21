import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../products/models/product.dart';
import '../controllers/stock_controller.dart';
import '../models/stock_movement.dart';
import 'stock_movement_dialog.dart';

class StockView extends GetView<StockController> {
  const StockView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Stock',
      child: Obx(() {
        final movements = controller.filteredMovements;
        final alerts = controller.alertProducts;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            return ListView(
              padding: EdgeInsets.all(isWide ? 28 : 18),
              children: [
                _PageHeader(isWide: isWide, onAdd: _addMovement),
                const SizedBox(height: 20),
                _StockMetrics(
                  controller: controller,
                  availableWidth: constraints.maxWidth - (isWide ? 56 : 36),
                ),
                if (alerts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SectionCard(
                    title: 'Alertes de stock',
                    subtitle: 'Produits au seuil d’alerte ou en rupture',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final product in alerts)
                          _AlertProductCard(product: product),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SectionCard(
                  title: 'Historique des mouvements',
                  subtitle: '${movements.length} mouvement(s)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MovementFilters(controller: controller),
                      const SizedBox(height: 14),
                      if (movements.isEmpty)
                        const _EmptyMovements()
                      else if (constraints.maxWidth >= 820)
                        _MovementTable(movements: movements)
                      else
                        Column(
                          children: [
                            for (final movement in movements)
                              _MovementCard(movement: movement),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }

  Future<void> _addMovement() async {
    final recorded = await Get.dialog<bool>(const StockMovementDialog());
    if (recorded != true) return;
    Get.snackbar(
      'Mouvement enregistré',
      'Le stock du produit a été mis à jour.',
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.isWide, required this.onAdd});

  final bool isWide;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final action = AppButton(
      label: 'Ajouter un mouvement',
      icon: Icons.add,
      onPressed: onAdd,
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion du stock',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Suivez les entrées, sorties et pertes.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 14), action],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        action,
      ],
    );
  }
}

class _StockMetrics extends StatelessWidget {
  const _StockMetrics({required this.controller, required this.availableWidth});

  final StockController controller;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final isMobile = availableWidth < 600;
    final cardWidth = isMobile ? (availableWidth - 12) / 2 : 172.0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
          width: cardWidth,
          compact: isMobile,
          label: 'Stock disponible',
          value: '${controller.totalUnits} unités',
          icon: Icons.warehouse_outlined,
          color: AppColors.primary,
        ),
        _MetricCard(
          width: cardWidth,
          compact: isMobile,
          label: 'Entrées',
          value: '+${controller.entryUnits}',
          icon: Icons.call_received_rounded,
          color: AppColors.success,
        ),
        _MetricCard(
          width: cardWidth,
          compact: isMobile,
          label: 'Sorties',
          value: '−${controller.exitUnits}',
          icon: Icons.call_made_rounded,
          color: AppColors.primary,
        ),
        _MetricCard(
          width: cardWidth,
          compact: isMobile,
          label: 'Pertes',
          value: '−${controller.lossUnits}',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
        _MetricCard(
          width: cardWidth,
          compact: isMobile,
          label: 'En rupture',
          value: '${controller.outOfStockProducts} produit(s)',
          icon: Icons.remove_shopping_cart_outlined,
          color: AppColors.error,
          tint: const Color(0xFFFFE7E7),
        ),
        _MetricCard(
          width: cardWidth,
          compact: isMobile,
          label: 'Stock faible',
          value: '${controller.lowStockProducts} produit(s)',
          icon: Icons.notifications_active_outlined,
          color: AppColors.warning,
          tint: const Color(0xFFFFF2D6),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.compact,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.tint = AppColors.surfaceTint,
  });

  final double width;
  final bool compact;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: compact ? 15 : 18,
                backgroundColor: tint,
                child: Icon(icon, size: compact ? 16 : 18, color: color),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(value, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertProductCard extends StatelessWidget {
  const _AlertProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final isOut = product.stockStatus == ProductStockStatus.outOfStock;
    final tint = isOut ? const Color(0xFFFFE7E7) : const Color(0xFFFFF2D6);
    final color = isOut ? AppColors.error : AppColors.warning;
    return Container(
      width: 265,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: tint),
      ),
      child: Row(
        children: [
          Icon(
            isOut ? Icons.error_outline : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  isOut
                      ? 'Rupture de stock'
                      : '${product.quantity} restant(s) · seuil ${product.alertThreshold}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementFilters extends StatelessWidget {
  const _MovementFilters({required this.controller});

  final StockController controller;

  @override
  Widget build(BuildContext context) {
    const options = <(StockMovementFilter, String)>[
      (StockMovementFilter.all, 'Tous'),
      (StockMovementFilter.entries, 'Entrées'),
      (StockMovementFilter.exits, 'Sorties'),
      (StockMovementFilter.losses, 'Pertes'),
    ];
    return Obx(
      () => Wrap(
        spacing: 8,
        children: [
          for (final (filter, label) in options)
            ChoiceChip(
              label: Text(label),
              selected: controller.selectedFilter.value == filter,
              onSelected: (_) => controller.selectedFilter.value = filter,
            ),
        ],
      ),
    );
  }
}

class _MovementTable extends StatelessWidget {
  const _MovementTable({required this.movements});

  final List<StockMovement> movements;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Produit')),
          DataColumn(label: Text('Type de mouvement')),
          DataColumn(label: Text('Quantité'), numeric: true),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Motif / note')),
        ],
        rows: [
          for (final movement in movements)
            DataRow(
              cells: [
                DataCell(Text(movement.productName)),
                DataCell(_MovementBadge(type: movement.type)),
                DataCell(_SignedQuantity(movement: movement)),
                DataCell(Text(_formatDate(movement.date))),
                DataCell(Text(movement.note.isEmpty ? '—' : movement.note)),
              ],
            ),
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    movement.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _SignedQuantity(movement: movement),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MovementBadge(type: movement.type),
                Text(
                  _formatDate(movement.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (movement.note.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                movement.note,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.type});

  final StockMovementType type;

  @override
  Widget build(BuildContext context) {
    final (label, tint, foreground) = switch (type) {
      StockMovementType.entry => (
        'Entrée',
        const Color(0xFFE5F6EB),
        AppColors.success,
      ),
      StockMovementType.exit => (
        'Sortie',
        const Color(0xFFEAF0F8),
        AppColors.primary,
      ),
      StockMovementType.loss => (
        'Perte',
        const Color(0xFFFFF2D6),
        const Color(0xFF9B6700),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SignedQuantity extends StatelessWidget {
  const _SignedQuantity({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final positive = movement.type == StockMovementType.entry;
    return Text(
      '${positive ? '+' : '−'}${movement.quantity}',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: positive ? AppColors.success : AppColors.error,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyMovements extends StatelessWidget {
  const _EmptyMovements();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.swap_vert_circle_outlined,
              size: 38,
              color: AppColors.muted,
            ),
            const SizedBox(height: 10),
            Text(
              'Aucun mouvement enregistré',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Les entrées, sorties et pertes apparaîtront ici.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} · '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
