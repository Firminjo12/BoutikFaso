import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../controllers/clients_controller.dart';
import '../models/client.dart';

class ClientsView extends GetView<ClientsController> {
  const ClientsView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Clients',
    child: LayoutBuilder(
      builder: (context, constraints) => Obx(() {
        final wide = constraints.maxWidth >= 820;
        final selected = controller.selectedClient;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Carnet clients',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showClientForm(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Nouveau client'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Clients',
                      value: '${controller.clients.length}',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'Dettes en cours',
                      value: _money(controller.totalOutstanding),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => controller.searchQuery.value = value,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher par nom ou téléphone',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 360,
                            child: _clientList(context, dense: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: selected == null
                                ? const Center(
                                    child: Text('Sélectionnez un client'),
                                  )
                                : _ClientDetails(client: selected),
                          ),
                        ],
                      )
                    : _clientList(context),
              ),
            ],
          ),
        );
      }),
    ),
  );

  Widget _clientList(
    BuildContext context, {
    bool dense = false,
  }) => ListView.separated(
    itemCount: controller.filteredClients.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final client = controller.filteredClients[index];
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Text(
              client.name.isEmpty ? '?' : client.name[0].toUpperCase(),
            ),
          ),
          title: Text(
            client.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${client.phone}\nSolde dû : ${_money(client.outstandingBalance)}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          selected: controller.selectedClientId.value == client.id,
          onTap: () {
            controller.selectedClientId.value = client.id;
            if (!dense) {
              Get.to<void>(() => _ClientDetailPage(clientId: client.id));
            }
          },
        ),
      );
    },
  );

  Future<void> _showClientForm(BuildContext context, [Client? client]) async {
    final name = TextEditingController(text: client?.name ?? '');
    final phone = TextEditingController(text: client?.phone ?? '');
    final address = TextEditingController(text: client?.address ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client == null ? 'Nouveau client' : 'Modifier le client'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom complet'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: address,
                decoration: const InputDecoration(
                  labelText: 'Adresse (facultatif)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final ok = client == null
                  ? controller.addClient(
                      name: name.text,
                      phone: phone.text,
                      address: address.text,
                    )
                  : controller.updateClient(
                      id: client.id,
                      name: name.text,
                      phone: phone.text,
                      address: address.text,
                    );
              Navigator.pop(context, ok);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
    address.dispose();
    if (result == false) {
      Get.snackbar(
        'Client non enregistré',
        'Vérifiez les champs et l’unicité du numéro.',
      );
    }
  }
}

class _ClientDetailPage extends GetView<ClientsController> {
  const _ClientDetailPage({required this.clientId});
  final String clientId;
  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Fiche client',
    child: Obx(() {
      final client = controller.clientById(clientId);
      return client == null
          ? const Center(child: Text('Client introuvable'))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: _ClientDetails(client: client),
            );
    }),
  );
}

class _ClientDetails extends GetView<ClientsController> {
  const _ClientDetails({required this.client});
  final Client client;
  @override
  Widget build(BuildContext context) {
    final activity = controller.transactionsFor(client.id);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: client.name,
            subtitle: '${client.phone} · ${client.address}',
            child: Column(
              children: [
                _DetailRow(
                  label: 'Achats cumulés',
                  value: _money(client.totalPurchases),
                ),
                const Divider(),
                _DetailRow(
                  label: 'Solde restant dû',
                  value: _money(client.outstandingBalance),
                  highlight: true,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (client.outstandingBalance > 0)
                      FilledButton.icon(
                        onPressed: () => _repayment(context, client),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Enregistrer un remboursement'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Get.offNamed<void>(AppRoutes.sales),
                      icon: const Icon(Icons.point_of_sale_outlined),
                      label: const Text('Nouvelle vente'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Historique',
            child: activity.isEmpty
                ? const Text('Aucune activité enregistrée.')
                : Column(
                    children: [
                      for (final item in activity)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            item.type == ClientTransactionType.repayment
                                ? Icons.call_received
                                : Icons.shopping_bag_outlined,
                            color: item.type == ClientTransactionType.repayment
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                          title: Text(item.description),
                          subtitle: Text(_date(item.date)),
                          trailing: Text(
                            '${item.type == ClientTransactionType.repayment ? '−' : '+'}${_money(item.amount)}',
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class DebtsView extends GetView<ClientsController> {
  const DebtsView({super.key});
  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Dettes',
    child: Obx(() {
      final debtors = controller.clients
          .where((client) => client.outstandingBalance > 0)
          .toList();
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Carnet des dettes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: 'Total des dettes',
                value: _money(controller.totalOutstanding),
                icon: Icons.account_balance_wallet_outlined,
              ),
              _Metric(
                label: 'Clients endettés',
                value: '${controller.clientsWithDebt}',
                icon: Icons.people_outline,
              ),
              _Metric(
                label: 'Remboursements aujourd’hui',
                value: _money(controller.repaymentsToday),
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Soldes à recouvrer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (debtors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucune dette en cours.'),
              ),
            ),
          for (final client in debtors)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(client.name[0].toUpperCase()),
                ),
                title: Text(client.name),
                subtitle: Text(client.phone),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _money(client.outstandingBalance),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remboursement',
                      onPressed: () => _repayment(context, client),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                onTap: () => Get.toNamed<void>(AppRoutes.clients),
              ),
            ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Derniers remboursements',
            child: _RepaymentHistory(),
          ),
        ],
      );
    }),
  );
}

class _RepaymentHistory extends GetView<ClientsController> {
  @override
  Widget build(BuildContext context) {
    final items = controller.transactions
        .where((item) => item.type == ClientTransactionType.repayment)
        .toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    if (items.isEmpty) return const Text('Aucun remboursement enregistré.');
    return Column(
      children: [
        for (final item in items.take(8))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(controller.clientById(item.clientId)?.name ?? 'Client'),
            subtitle: Text('${item.description} · ${_date(item.date)}'),
            trailing: Text(_money(item.amount)),
          ),
      ],
    );
  }
}

Future<void> _repayment(BuildContext context, Client client) async {
  final amount = TextEditingController();
  final note = TextEditingController();
  var method = 'Espèces';
  final controller = Get.find<ClientsController>();
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Remboursement · ${client.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Solde dû : ${_money(client.outstandingBalance)}'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant reçu (F CFA)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Mode reçu'),
                items: const [
                  DropdownMenuItem(value: 'Espèces', child: Text('Espèces')),
                  DropdownMenuItem(
                    value: 'Orange Money',
                    child: Text('Orange Money'),
                  ),
                  DropdownMenuItem(
                    value: 'Moov Money',
                    child: Text('Moov Money'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => method = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Note (facultatif)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(amount.text.replaceAll(' ', ''));
              if (value == null ||
                  value <= 0 ||
                  value > client.outstandingBalance) {
                Get.snackbar(
                  'Montant invalide',
                  'Le montant doit être positif et ne pas dépasser le solde dû.',
                );
                return;
              }
              if (controller.recordRepayment(
                clientId: client.id,
                amount: value,
                method: method,
                note: note.text,
              )) {
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
  amount.dispose();
  note.dispose();
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.primary : null,
          ),
        ),
      ],
    ),
  );
}

String _money(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+$)'), (_) => ' ')} F';
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
