import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';

import '../controllers/products_controller.dart';
import '../models/product.dart';
import '../widgets/product_image.dart';

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({this.product, super.key});

  final Product? product;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _saleController = TextEditingController();
  final _quantityController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _category;
  String? _imagePath;

  ProductsController get _productsController => Get.find<ProductsController>();

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController.text = product?.name ?? '';
    _skuController.text = product?.sku ?? '';
    _purchaseController.text = product?.purchasePrice.toString() ?? '';
    _saleController.text = product?.salePrice.toString() ?? '';
    _quantityController.text = product?.quantity.toString() ?? '';
    _thresholdController.text = product?.alertThreshold.toString() ?? '5';
    _descriptionController.text = product?.description ?? '';
    _category = product?.category ?? _productsController.categories.first;
    _imagePath = product?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _purchaseController.dispose();
    _saleController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = screenWidth < 660 ? screenWidth - 40 : 620.0;
    final isEditing = widget.product != null;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: width,
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
                      child: Text(
                        isEditing
                            ? 'Modifier un produit'
                            : 'Ajouter un produit',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: Get.back<void>,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth > 480;
                        final fieldWidth = twoColumns
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 14,
                          children: [
                            _imagePicker(constraints.maxWidth),
                            _field(
                              width: constraints.maxWidth,
                              label: 'Nom du produit',
                              controller: _nameController,
                              validator: _requiredText,
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: Obx(
                                () => DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    _productsController.categories.length,
                                  ),
                                  initialValue: _category,
                                  decoration: const InputDecoration(
                                    labelText: 'Catégorie',
                                  ),
                                  items: [
                                    for (final category
                                        in _productsController.categories)
                                      DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _category = value);
                                    }
                                  },
                                  validator: (value) => value == null
                                      ? 'Choisissez une catégorie'
                                      : null,
                                ),
                              ),
                            ),
                            _field(
                              width: fieldWidth,
                              label: 'Code produit / SKU',
                              controller: _skuController,
                            ),
                            _field(
                              width: fieldWidth,
                              label: 'Prix d’achat (FCFA)',
                              controller: _purchaseController,
                              numeric: true,
                              validator: _requiredNumber,
                            ),
                            _field(
                              width: fieldWidth,
                              label: 'Prix de vente (FCFA)',
                              controller: _saleController,
                              numeric: true,
                              validator: _requiredNumber,
                            ),
                            _field(
                              width: fieldWidth,
                              label: isEditing
                                  ? 'Quantité en stock'
                                  : 'Quantité initiale',
                              controller: _quantityController,
                              numeric: true,
                              validator: _requiredNumber,
                            ),
                            _field(
                              width: fieldWidth,
                              label: 'Seuil d’alerte',
                              controller: _thresholdController,
                              numeric: true,
                              validator: _requiredNumber,
                            ),
                            _field(
                              width: constraints.maxWidth,
                              label: 'Description (facultative)',
                              controller: _descriptionController,
                              maxLines: 3,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back<void>,
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        isEditing ? 'Enregistrer' : 'Ajouter le produit',
                      ),
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

  Widget _imagePicker(double width) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photo du produit'),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 86,
                height: 86,
                child: ProductImage(
                  imagePath: _imagePath,
                  placeholder: Container(
                    color: const Color(0xFFF0F4F1),
                    child: const Icon(Icons.add_a_photo_outlined, size: 30),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _imagePath == null ? 'Choisir une image' : 'Changer',
                    ),
                  ),
                  if (_imagePath != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _imagePath = null),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Retirer'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Formats acceptés : JPG, PNG ou WebP.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Future<void> _pickImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path != null && mounted) {
      setState(() => _imagePath = path);
    }
  }

  Widget _field({
    required double width,
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    bool numeric = false,
    int maxLines = 1,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Ce champ est obligatoire' : null;

  String? _requiredNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ce champ est obligatoire';
    }
    if (int.tryParse(value) == null) {
      return 'Entrez un nombre entier valide';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.product;
    final product = Product(
      id: previous?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      category: _category,
      sku: _skuController.text.trim(),
      purchasePrice: int.parse(_purchaseController.text),
      salePrice: int.parse(_saleController.text),
      quantity: int.parse(_quantityController.text),
      alertThreshold: int.parse(_thresholdController.text),
      description: _descriptionController.text.trim(),
      imagePath: _imagePath,
    );
    Get.back<Product>(result: product);
  }
}
