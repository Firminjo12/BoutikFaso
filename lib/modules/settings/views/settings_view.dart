import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/workspace/merchant_workspace_controller.dart';
import '../../auth/controllers/auth_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  static const _paymentMethods = ['Espèces', 'Orange Money', 'Moov Money'];
  final _workspaces = Get.find<MerchantWorkspaceController>();
  final _auth = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Paramètres',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 950;
        return ListView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          children: [
            Text(
              'Gérez votre boutique, vos préférences et votre compte.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _SettingsSection(
              number: '1',
              title: 'MA BOUTIQUE',
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _shopInformation(context)),
                        const SizedBox(width: 14),
                        Expanded(child: _shopList(context)),
                      ],
                    )
                  : Column(
                      children: [
                        _shopInformation(context),
                        const SizedBox(height: 12),
                        _shopList(context),
                      ],
                    ),
            ),
            _SettingsSection(
              number: '2',
              title: 'UTILISATEURS ET ACCÈS',
              child: _usersCard(context, wide),
            ),
            _SettingsSection(
              number: '3',
              title: 'PRÉFÉRENCES',
              child: _preferencesCard(context),
            ),
            _SettingsSection(
              number: '4',
              title: 'DONNÉES ET SAUVEGARDE',
              child: _dataCard(context),
            ),
            _SettingsSection(
              number: '5',
              title: 'MON COMPTE ET SÉCURITÉ',
              child: _accountCard(context),
            ),
          ],
        );
      },
    ),
  );

  Widget _shopInformation(BuildContext context) => Obx(() {
    final shop = _workspaces.activeWorkspace;
    return SectionCard(
      title: 'Informations de la boutique',
      subtitle: 'Identité affichée sur vos reçus.',
      trailing: const Icon(Icons.store_mall_directory_outlined),
      child: Column(
        children: [
          _InfoLine(label: 'Nom', value: shop.name),
          _InfoLine(label: 'Téléphone', value: shop.phone),
          _InfoLine(label: 'Ville / quartier', value: shop.location),
          _InfoLine(label: 'Devise', value: _currencyName(shop.currencyCode)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _editShop(context),
              child: const Text('Modifier les informations'),
            ),
          ),
        ],
      ),
    );
  });

  Widget _shopList(BuildContext context) => Obx(() {
    final shops = _workspaces.workspaces;
    final activeId = _workspaces.activeWorkspaceId.value;
    return SectionCard(
      title: 'Mes boutiques',
      subtitle: 'Données séparées pour chaque commerce.',
      child: Column(
        children: [
          for (final shop in shops) ...[
            _WorkspaceTile(
              name: shop.name,
              location: shop.location,
              active: shop.id == activeId,
              onTap: () {
                if (shop.id != activeId) _workspaces.switchTo(shop.id);
              },
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _addShop(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une boutique'),
            ),
          ),
        ],
      ),
    );
  });

  Widget _usersCard(BuildContext context, bool wide) => SectionCard(
    title: 'Utilisateurs de la boutique',
    subtitle: 'Ajoutez les personnes qui vous aident à tenir la caisse ou gérer le stock.',
    trailing: OutlinedButton(
      onPressed: _showAccessInfo,
      child: const Text('Gérer les utilisateurs'),
    ),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: const [
        _RoleCard(
          title: 'Propriétaire',
          permissions: 'Accès complet aux ventes, rapports et réglages.',
        ),
        _RoleCard(
          title: 'Gérant',
          permissions:
              'Gère les produits, le stock, les clients et les dépenses.',
        ),
        _RoleCard(
          title: 'Caissier',
          permissions:
              'Enregistre les ventes à la caisse et les remboursements.',
        ),
      ],
    ),
  );

  Widget _preferencesCard(BuildContext context) => Obx(() {
    final shop = _workspaces.activeWorkspace;
    return SectionCard(
      title: 'Réglages de vente et de stock',
      subtitle: 'Ces préférences s’appliquent à la boutique active.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _PreferenceDescription(
                  title: 'Seuil d’alerte de stock faible',
                  description: 'Alerter quand un produit passe sous ce seuil.',
                ),
              ),
              IconButton(
                tooltip: 'Diminuer le seuil',
                onPressed: shop.lowStockThreshold > 1
                    ? () => _workspaces.updateWorkspaceSettings(
                        lowStockThreshold: shop.lowStockThreshold - 1,
                      )
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${shop.lowStockThreshold} unités'),
              IconButton(
                tooltip: 'Augmenter le seuil',
                onPressed: () => _workspaces.updateWorkspaceSettings(
                  lowStockThreshold: shop.lowStockThreshold + 1,
                ),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Méthodes de paiement acceptées',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Choisissez les moyens proposés lors d’une vente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final method in _paymentMethods)
                FilterChip(
                  label: Text(method),
                  selected: shop.acceptedPaymentMethods.contains(method),
                  onSelected: (selected) {
                    final methods = shop.acceptedPaymentMethods.toSet();
                    if (selected) {
                      methods.add(method);
                    } else if (methods.length > 1) {
                      methods.remove(method);
                    }
                    _workspaces.updateWorkspaceSettings(
                      acceptedPaymentMethods: methods.toList(),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Moyens proposés à la caisse lors d’une vente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 20),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vente à crédit'),
            subtitle: const Text(
              'Autoriser l’enregistrement des dettes clients.',
            ),
            value: shop.creditSalesEnabled,
            onChanged: (value) =>
                _workspaces.updateWorkspaceSettings(creditSalesEnabled: value),
          ),
          const Divider(height: 20),
          _InfoLine(
            label: 'Devise affichée',
            value: _currencyName(shop.currencyCode),
          ),
        ],
      ),
    );
  });

  Widget _dataCard(BuildContext context) => SectionCard(
    title: 'État des données',
    subtitle: 'Vos ventes et votre stock sont gérés dans cette application.',
    trailing: const Chip(
      avatar: Icon(Icons.cloud_off_outlined, size: 15),
      label: Text('Local'),
      visualDensity: VisualDensity.compact,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'La sauvegarde en ligne et la synchronisation seront disponibles avec le service backend.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Get.snackbar(
            'Export non disponible',
            'L’export des données sera activé dans une prochaine étape.',
          ),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Exporter mes données'),
        ),
      ],
    ),
  );

  Widget _accountCard(BuildContext context) => Obx(() {
    final shop = _workspaces.activeWorkspace;
    return SectionCard(
      title: 'Compte commerçant',
      subtitle: 'Sécurité et accès à Boutik Faso.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.surfaceTint,
              foregroundColor: AppColors.primary,
              child: Text(_initials(shop.name)),
            ),
            title: const Text('Responsable de la boutique'),
            subtitle: Text(
              shop.phone.isEmpty ? 'Téléphone non renseigné' : shop.phone,
            ),
            trailing: OutlinedButton(
              onPressed: () => Get.snackbar(
                'Modification du PIN',
                'Le changement du code PIN nécessite une route backend dédiée.',
              ),
              child: const Text('Modifier mon code PIN'),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.error,
              backgroundColor: const Color(0xFFFFE8E8),
            ),
          ),
        ],
      ),
    );
  });

  Future<void> _editShop(BuildContext context) async {
    final current = _workspaces.activeWorkspace;
    final name = TextEditingController(text: current.name);
    final phone = TextEditingController(text: current.phone);
    final location = TextEditingController(text: current.location);
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Informations de la boutique'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'Ville / quartier',
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Devise : FCFA'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result == true) {
      final saved = _workspaces.updateWorkspaceSettings(
        name: name.text,
        phone: phone.text.trim(),
        location: location.text.trim(),
      );
      if (!saved) {
        Get.snackbar(
          'Nom déjà utilisé',
          'Une autre boutique porte déjà ce nom.',
        );
      }
    }
    name.dispose();
    phone.dispose();
    location.dispose();
  }

  Future<void> _addShop(BuildContext context) async {
    final name = await Get.dialog<String>(const _AddShopDialog());
    if (name == null || name.trim().isEmpty) return;
    final id = _workspaces.addWorkspace(name);
    if (id == null) {
      Get.snackbar('Nom déjà utilisé', 'Choisissez un autre nom de boutique.');
      return;
    }
    _workspaces.switchTo(id);
  }

  void _showAccessInfo() {
    Get.dialog<void>(
      AlertDialog(
        title: const Text('Utilisateurs et rôles'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Propriétaire — accès complet aux ventes, rapports et réglages.',
            ),
            SizedBox(height: 10),
            Text(
              'Gérant — gère les produits, le stock, les clients et les dépenses.',
            ),
            SizedBox(height: 10),
            Text('Caissier — enregistre les ventes à la caisse.'),
            SizedBox(height: 14),
            Text(
              'L’invitation de nouveaux utilisateurs sera activée avec le backend.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez vous reconnecter pour accéder à votre boutique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _auth.logout();
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(
            '$number. $title',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .5),
          ),
        ),
        child,
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    ),
  );
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.name,
    required this.location,
    required this.active,
    required this.onTap,
  });

  final String name;
  final String location;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: active ? AppColors.surfaceTint : Colors.white,
        border: Border.all(
          color: active ? AppColors.success : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                if (location.isNotEmpty)
                  Text(location, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Chip(
            label: Text(active ? 'Active' : 'Ouvrir'),
            visualDensity: VisualDensity.compact,
            backgroundColor: active ? AppColors.primary : AppColors.background,
            labelStyle: TextStyle(
              color: active ? Colors.white : AppColors.text,
              fontSize: 11,
            ),
            side: BorderSide.none,
          ),
        ],
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.title, required this.permissions});

  final String title;
  final String permissions;

  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 5),
        Text(permissions, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _PreferenceDescription extends StatelessWidget {
  const _PreferenceDescription({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      Text(description, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _AddShopDialog extends StatefulWidget {
  const _AddShopDialog();

  @override
  State<_AddShopDialog> createState() => _AddShopDialogState();
}

class _AddShopDialogState extends State<_AddShopDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajouter une boutique'),
    content: TextField(
      controller: _name,
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
        onPressed: () => Get.back<String>(result: _name.text.trim()),
        child: const Text('Ajouter'),
      ),
    ],
  );
}

String _currencyName(String code) => code == 'XOF' ? 'FCFA' : code;

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
