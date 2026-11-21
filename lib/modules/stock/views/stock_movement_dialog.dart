import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/stock_controller.dart';
import '../models/stock_movement.dart';

class StockMovementDialog extends StatefulWidget {
  const StockMovementDialog({super.key});

  @override
  State<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<StockMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  final _stockController = Get.find<StockController>();
  String? _productId;
  StockMovementType _type = StockMovementType.entry;

  @override
  void initState() {
    super.initState();
    _productId =
        _stockController.productsController.products.firstOrNull?.id;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hasProducts = _stockController.productsController.products.isNotEmpty;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: width < 560 ? width - 40 : 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Ajouter un mouvement',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: Get.back<void>,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!hasProducts)
                  const Text('Ajoutez d’abord un produit au catalogue.')
                else ...[
                  SegmentedButton<StockMovementType>(
                    segments: const [
                      ButtonSegment(
                        value: StockMovementType.entry,
                        label: Text('Entrée'),
                        icon: Icon(Icons.add_circle_outline),
                      ),
                      ButtonSegment(
                        value: StockMovementType.exit,
                        label: Text('Sortie'),
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      ButtonSegment(
                        value: StockMovementType.loss,
                        label: Text('Perte'),
                        icon: Icon(Icons.warning_amber_rounded),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) =>
                        setState(() => _type = selection.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _productId,
                    decoration: const InputDecoration(
                      labelText: 'Produit',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      for (final product
                          in _stockController.productsController.products)
                        DropdownMenuItem(
                          value: product.id,
                          child: Text(
                            '${product.name} · ${product.quantity} en stock',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _productId = value);
                    },
                    validator: (value) =>
                        value == null ? 'Choisissez un produit' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Quantité',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (value) {
                      final quantity = int.tryParse(value ?? '');
                      if (quantity == null || quantity <= 0) {
                        return 'Saisissez une quantité supérieure à zéro';
                      }
                      final product = _stockController.productsController.products
                          .firstWhereOrNull((item) => item.id == _productId);
                      if (_type != StockMovementType.entry &&
                          product != null &&
                          quantity > product.quantity) {
                        return 'Le stock disponible est de ${product.quantity}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: switch (_type) {
                        StockMovementType.entry => 'Fournisseur ou note (facultatif)',
                        StockMovementType.exit => 'Motif ou note (facultatif)',
                        StockMovementType.loss => 'Motif de la perte',
                      },
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                    validator: (value) => _type == StockMovementType.loss &&
                            (value == null || value.trim().isEmpty)
                        ? 'Indiquez le motif de la perte'
                        : null,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back<void>,
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: hasProducts ? _save : Get.back<void>,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final recorded = _stockController.recordMovement(
      productId: _productId!,
      type: _type,
      quantity: int.parse(_quantityController.text),
      note: _noteController.text,
    );
    Get.back<bool>(result: recorded);
  }
}
