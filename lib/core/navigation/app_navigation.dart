import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../workspace/merchant_workspace_controller.dart';
import 'navigation_item.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  static const _desktopItems = <NavigationItem>[
    NavigationItem('Tableau de bord', Icons.dashboard_outlined, '/'),
    NavigationItem('Ventes / Caisse', Icons.point_of_sale_outlined, '/sales'),
    NavigationItem('Produits', Icons.inventory_2_outlined, '/products'),
    NavigationItem('Stock', Icons.warehouse_outlined, '/stock'),
    NavigationItem('Clients', Icons.people_outline, '/clients'),
    NavigationItem('Dettes', Icons.account_balance_wallet_outlined, '/debts'),
    NavigationItem('Dépenses', Icons.receipt_long_outlined, '/expenses'),
    NavigationItem('Rapports', Icons.bar_chart_outlined, '/reports'),
    NavigationItem('Paramètres', Icons.settings_outlined, '/settings'),
  ];

  static const _mobileItems = <NavigationItem>[
    NavigationItem('Accueil', Icons.home_outlined, '/'),
    NavigationItem('Caisse', Icons.point_of_sale_outlined, '/sales'),
    NavigationItem('Stock', Icons.warehouse_outlined, '/stock'),
    NavigationItem('Panier', Icons.shopping_basket_outlined, '/basket'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final currentRoute = Get.currentRoute;

    if (isWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _DesktopNavigation(
                items: _desktopItems,
                currentRoute: currentRoute,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _DesktopHeader(title: title),
                    const Divider(height: 1),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedIndex = _mobileItems.indexWhere(
      (item) => item.route == currentRoute,
    );

    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: _MerchantMenu(),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (index) => _navigate(_mobileItems[index]),
        destinations: [
          for (final item in _mobileItems)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon, color: AppColors.primary),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.items, required this.currentRoute});

  final List<NavigationItem> items;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 246,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 22, 22, 28),
            child: _Brand(),
          ),
          for (final item in items)
            _NavigationTile(
              item: item,
              selected: item.route == currentRoute,
              onTap: () => _navigate(item),
            ),
          const Padding(padding: EdgeInsets.all(16), child: _StoreCard()),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(width: 12),
            const _MerchantMenu(),
          ],
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        leading: Icon(item.icon, size: 21),
        title: Text(item.label),
        selected: selected,
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        onTap: onTap,
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Boutik Faso',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _MerchantMenu extends StatelessWidget {
  const _MerchantMenu();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MerchantWorkspaceController>();
    return PopupMenuButton<String>(
      tooltip: 'Changer de commerçant',
      onSelected: (value) async {
        if (value == 'add') {
          final name = await Get.dialog<String>(const _AddWorkspaceDialog());
          if (name == null) return;
          final id = controller.addWorkspace(name);
          if (id == null) {
            Get.snackbar(
              'Nom déjà utilisé',
              'Choisissez un autre nom de boutique.',
            );
            return;
          }
          controller.switchTo(id);
          Get.offAllNamed<void>(AppRoutes.home);
          return;
        }
        final id = value.startsWith('switch:') ? value.substring(7) : '';
        if (controller.switchTo(id)) Get.offAllNamed<void>(AppRoutes.home);
      },
      itemBuilder: (context) => [
        for (final workspace in controller.workspaces)
          PopupMenuItem<String>(
            value: 'switch:${workspace.id}',
            child: Row(
              children: [
                Icon(
                  workspace.id == controller.activeWorkspaceId.value
                      ? Icons.check_circle
                      : Icons.store_outlined,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(workspace.name)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'add',
          child: Row(
            children: [
              Icon(Icons.add_business_outlined, size: 18),
              SizedBox(width: 10),
              Text('Ajouter un commerçant'),
            ],
          ),
        ),
      ],
      child: Obx(() {
        final name = controller.activeWorkspace.name;
        final initials = name
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();
        return CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.surfaceTint,
          foregroundColor: AppColors.primary,
          child: Text(
            initials.isEmpty ? 'BF' : initials,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      }),
    );
  }
}

class _AddWorkspaceDialog extends StatefulWidget {
  const _AddWorkspaceDialog();

  @override
  State<_AddWorkspaceDialog> createState() => _AddWorkspaceDialogState();
}

class _AddWorkspaceDialogState extends State<_AddWorkspaceDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajouter un commerçant'),
    content: TextField(
      controller: _nameController,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Nom de la boutique'),
      onSubmitted: (value) => Get.back<String>(result: value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Get.back<String>(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Get.back<String>(result: _nameController.text.trim()),
        child: const Text('Ajouter'),
      ),
    ],
  );
}

class _StoreCard extends StatelessWidget {
  const _StoreCard();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Mode sans backend',
      subtitle: 'Les fonctionnalités arrivent au fil du planning.',
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 17, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Backend désactivé'),
        ],
      ),
    );
  }
}

void _navigate(NavigationItem item) {
  if (Get.currentRoute != item.route) Get.offAllNamed<void>(item.route);
}
