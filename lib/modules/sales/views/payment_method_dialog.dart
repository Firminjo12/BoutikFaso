import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../clients/controllers/clients_controller.dart';
import '../../clients/models/client.dart';
import '../models/sale.dart';

class PaymentMethodDialog extends StatefulWidget {
  const PaymentMethodDialog({required this.total, super.key});

  final int total;

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  PaymentMethod _method = PaymentMethod.cash;
  String? _clientId;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final clientsController = Get.find<ClientsController>();
    return AlertDialog(
      title: const Text('Mode de paiement'),
      content: SizedBox(
        width: width < 520 ? width - 72 : 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total à encaisser',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFcfa(widget.total),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choisissez le mode de paiement',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: _method == method,
                    onSelected: (_) => setState(() => _method = method),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Obx(() {
              final clients = clientsController.clients.toList();
              if (_method == PaymentMethod.credit && _clientId == null) {
                _clientId = clientsController.selectedClientId.value;
              }
              final validClientId =
                  clients.any((client) => client.id == _clientId)
                  ? _clientId
                  : null;
              return DropdownButtonFormField<String?>(
                initialValue: validClientId,
                decoration: InputDecoration(
                  labelText: _method == PaymentMethod.credit
                      ? 'Client requis pour le crédit'
                      : 'Associer à un client (facultatif)',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                items: [
                  if (_method != PaymentMethod.credit)
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sans client'),
                    ),
                  for (final client in clients)
                    DropdownMenuItem<String?>(
                      value: client.id,
                      child: Text(
                        '${client.name} · ${client.phone}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _clientId = value),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final client = await showDialog<Client>(
                    context: context,
                    builder: (_) => const ClientFormDialog(),
                  );
                  if (client != null && mounted) {
                    setState(() => _clientId = client.id);
                  }
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ajouter un client'),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _method == PaymentMethod.credit
                  ? 'Le montant sera ajouté au solde dû du client.'
                  : 'La vente et le mode choisi seront enregistrés sur cet appareil. '
                        'Le total d’achats du client sera mis à jour si vous en sélectionnez un. '
                        'Aucune transaction Orange Money ou Moov Money n’est déclenchée.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back<void>, child: const Text('Annuler')),
        FilledButton.icon(
          onPressed: _method == PaymentMethod.credit && _clientId == null
              ? null
              : () => Get.back<CheckoutPayment>(
                  result: CheckoutPayment(method: _method, clientId: _clientId),
                ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirmer la vente'),
        ),
      ],
    );
  }
}

class ClientFormDialog extends StatefulWidget {
  const ClientFormDialog({super.key});

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouveau client'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nom complet'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Téléphone'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Get.back<void>(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final controller = Get.find<ClientsController>();
          final ok = controller.addClient(name: _name.text, phone: _phone.text);
          if (ok) {
            final client = controller.selectedClient;
            Get.back<void>();
            Get.back<Client>(result: client);
          } else {
            Get.snackbar(
              'Client non ajouté',
              'Le nom et un numéro unique sont requis.',
            );
          }
        },
        child: const Text('Ajouter'),
      ),
    ],
  );
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
