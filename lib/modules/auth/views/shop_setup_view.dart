import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_widgets.dart';

class ShopSetupView extends StatefulWidget {
  const ShopSetupView({super.key});

  @override
  State<ShopSetupView> createState() => _ShopSetupViewState();
}

class _ShopSetupViewState extends State<ShopSetupView> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _managerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController(text: 'Ouagadougou');
  final _district = TextEditingController();
  final _address = TextEditingController();

  static const _businessTypes = [
    'Alimentation générale',
    'Boutique de vêtements',
    'Cosmétique & beauté',
    'Électronique',
    'Pharmacie',
    'Quincaillerie',
    'Restaurant',
    'Autre',
  ];
  static const _paymentTypes = [
    'Espèces',
    'Orange Money',
    'Moov Money',
    'Telecel Money',
  ];

  int _step = 0;
  String? _businessType;
  String? _logoName;
  Uint8List? _logoBytes;
  final _payments = <String>{'Espèces', 'Orange Money'};
  int _stockThreshold = 5;
  bool _creditEnabled = true;
  bool _isPickingLogo = false;

  @override
  void dispose() {
    _shopName.dispose();
    _managerName.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _district.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    setState(() => _isPickingLogo = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result.isNotEmpty && mounted) {
        final file = result.first;
        final size = await file.length();
        if (size != null && size > 5 * 1024 * 1024) {
          Get.snackbar(
            'Image trop volumineuse',
            'Choisissez une image de 5 Mo maximum.',
          );
          return;
        }
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _logoName = file.name;
          _logoBytes = bytes;
        });
      }
    } on Object {
      if (mounted) {
        Get.snackbar('Image non ajoutée', 'Vous pourrez réessayer plus tard.');
      }
    } finally {
      if (mounted) setState(() => _isPickingLogo = false);
    }
  }

  void _next() {
    if (_step == 1 && !_formKey.currentState!.validate()) return;
    if (_step == 1 && _businessType == null) {
      Get.snackbar(
        'Type de commerce requis',
        'Choisissez le type de votre boutique.',
      );
      return;
    }
    if (_step == 2 && !_formKey.currentState!.validate()) return;
    if (_step == 3 && !_formKey.currentState!.validate()) return;
    if (_step == 4 && _payments.isEmpty) {
      Get.snackbar(
        'Paiement requis',
        'Choisissez au moins un mode de paiement.',
      );
      return;
    }
    if (_step == 5) {
      Get.toNamed<void>(AppRoutes.register, arguments: _draft);
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      Get.offAllNamed<void>(AppRoutes.welcome);
      return;
    }
    setState(() => _step--);
  }

  void _skip() {
    if (_step == 3) {
      _city.clear();
      _district.clear();
      _address.clear();
    }
    setState(() => _step++);
  }

  Map<String, dynamic> get _draft {
    final locality = [
      _district.text.trim(),
      _city.text.trim(),
      'Burkina Faso',
    ].where((part) => part.isNotEmpty).join(', ');
    final address = [
      locality,
      _address.text.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');
    return {
      'merchant_name': _shopName.text.trim(),
      'merchant_address': address,
      'merchant_phone': _phone.text.trim(),
      'manager_name': _managerName.text.trim(),
      'email': _email.text.trim(),
      'business_type': _businessType ?? 'Autre',
      'logo_name': _logoName,
      'city': _city.text.trim(),
      'district': _district.text.trim(),
      'extra_address': _address.text.trim(),
      'currency': 'XOF',
      'payment_methods': _payments.toList(),
      'stock_threshold': _stockThreshold,
      'credit_enabled': _creditEnabled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AuthBrand(compact: true),
        actions: [
          if (_step <= 5)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text(
                  'Étape ${_step + 1} sur 7',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 7,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: AppColors.border,
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 18 : 28,
                        22,
                        isMobile ? 18 : 28,
                        16,
                      ),
                      child: _buildStep(context, isMobile),
                    ),
                  ),
                ),
                _footer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, bool isMobile) {
    switch (_step) {
      case 0:
        return _welcomeStep(context);
      case 1:
        return _businessStep(context, isMobile);
      case 2:
        return _managerStep(context);
      case 3:
        return _locationStep(context, isMobile);
      case 4:
        return _preferencesStep(context);
      default:
        return _reviewStep(context);
    }
  }

  Widget _welcomeStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        height: 190,
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.storefront_rounded,
          size: 96,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 22),
      Text(
        'Bienvenue sur BoutikFaso',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        'Tout ce qu’il faut pour gérer votre commerce, au même endroit.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 18),
      const _BenefitTile(
        icon: Icons.inventory_2_outlined,
        text: 'Gérez vos produits et votre stock.',
      ),
      const SizedBox(height: 10),
      const _BenefitTile(
        icon: Icons.show_chart_rounded,
        text: 'Suivez vos ventes et vos bénéfices.',
      ),
      const SizedBox(height: 10),
      const _BenefitTile(
        icon: Icons.shield_outlined,
        text: 'Gardez le contrôle de votre activité.',
      ),
    ],
  );

  Widget _businessStep(BuildContext context, bool isMobile) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepHeading(
        title: 'Parlons de votre boutique',
        subtitle: 'Commençons par donner une identité à votre commerce.',
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: _shopName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nom de la boutique *',
          hintText: 'Épicerie Wend-Panga',
          prefixIcon: Icon(Icons.store_outlined),
        ),
        validator: _required,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _isPickingLogo ? null : _pickLogo,
        icon: _isPickingLogo
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt_outlined),
        label: Text(
          _logoName == null ? 'Ajouter le logo (facultatif)' : _logoName!,
        ),
      ),
      if (_logoBytes != null) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            _logoBytes!,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Text('Type de commerce *', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 9),
      GridView.builder(
        itemCount: _businessTypes.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: isMobile ? 2.3 : 1.9,
        ),
        itemBuilder: (context, index) {
          final type = _businessTypes[index];
          final selected = type == _businessType;
          return InkWell(
            onTap: () => setState(() => _businessType = type),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.surfaceTint : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
      if (_businessType == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Choisissez un type de commerce.',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
    ],
  );

  Widget _managerStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepHeading(
        title: 'Qui gère cette boutique ?',
        subtitle: 'Ces informations permettent d’identifier le responsable du commerce.',
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: _managerName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nom et prénom du responsable *',
          prefixIcon: Icon(Icons.person_outline),
        ),
        validator: _required,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Numéro de téléphone *',
          hintText: '+226 70 22 44 11',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        validator: _validatePhone,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email (facultatif)',
          hintText: 'exemple@boutique.bf',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: _validateEmail,
      ),
    ],
  );

  Widget _locationStep(BuildContext context, bool isMobile) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepHeading(
        title: 'Où se trouve votre boutique ?',
        subtitle: 'Ajoutez une localisation pour retrouver facilement votre commerce.',
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_on, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Burkina Faso', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (isMobile) ...[
        _locationField(_city, 'Ville *', 'Ouagadougou'),
        const SizedBox(height: 12),
        _locationField(_district, 'Quartier / secteur *', 'Secteur 15'),
      ] else
        Row(
          children: [
            Expanded(child: _locationField(_city, 'Ville *', 'Ouagadougou')),
            const SizedBox(width: 12),
            Expanded(
              child: _locationField(
                _district,
                'Quartier / secteur *',
                'Secteur 15',
              ),
            ),
          ],
        ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _address,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Adresse complémentaire (facultatif)',
          hintText: 'Près du marché, face à la pharmacie',
          prefixIcon: Icon(Icons.place_outlined),
        ),
      ),
    ],
  );

  Widget _locationField(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextFormField(
    controller: controller,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(labelText: label, hintText: hint),
    validator: _required,
  );

  Widget _preferencesStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepHeading(
        title: 'Personnalisons votre gestion',
        subtitle: 'Définissez vos préférences de vente et d’alerte de stock.',
      ),
      const SizedBox(height: 18),
      _PreferenceCard(
        title: 'Devise principale',
        description: 'Franc CFA (XOF · Burkina Faso)',
        trailing: Text('FCFA', style: Theme.of(context).textTheme.titleSmall),
        icon: Icons.currency_exchange_outlined,
      ),
      const SizedBox(height: 12),
      Text(
        'Modes de paiement acceptés',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final method in _paymentTypes)
            FilterChip(
              label: Text(method),
              selected: _payments.contains(method),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _payments.add(method);
                } else {
                  _payments.remove(method);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _PreferenceCard(
        title: 'Seuil d’alerte stock',
        description: 'Prévenir dès ce nombre d’unités',
        icon: Icons.notifications_active_outlined,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _stockThreshold > 1
                  ? () => setState(() => _stockThreshold--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_stockThreshold',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              onPressed: () => setState(() => _stockThreshold++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _PreferenceCard(
        title: 'Autoriser la vente à crédit',
        description: 'Enregistrer les dettes clients dans votre carnet.',
        icon: Icons.menu_book_outlined,
        trailing: Switch(
          value: _creditEnabled,
          onChanged: (value) => setState(() => _creditEnabled = value),
        ),
      ),
    ],
  );

  Widget _reviewStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepHeading(
        title: 'Vérifiez vos informations',
        subtitle: 'Relisez les détails avant de finaliser votre boutique.',
      ),
      const SizedBox(height: 18),
      _ReviewCard(
        title: _shopName.text,
        subtitle: _businessType ?? 'Type de commerce non sélectionné',
        icon: Icons.store_outlined,
        onEdit: () => setState(() => _step = 1),
      ),
      const SizedBox(height: 10),
      _ReviewCard(
        title: _managerName.text,
        subtitle:
            '${_phone.text}${_email.text.trim().isEmpty ? '' : '\n${_email.text.trim()}'}',
        icon: Icons.person_outline,
        onEdit: () => setState(() => _step = 2),
      ),
      const SizedBox(height: 10),
      _ReviewCard(
        title: _district.text.trim().isEmpty
            ? 'Localisation non précisée'
            : '${_city.text} · ${_district.text}',
        subtitle: _address.text.trim().isEmpty
            ? 'Burkina Faso'
            : _address.text.trim(),
        icon: Icons.location_on_outlined,
        onEdit: () => setState(() => _step = 3),
      ),
      const SizedBox(height: 10),
      _ReviewCard(
        title: 'Préférences commerciales',
        subtitle:
            'FCFA · ${_payments.isEmpty ? 'Aucun paiement choisi' : _payments.join(', ')}\nSeuil stock : $_stockThreshold · Crédit ${_creditEnabled ? 'activé' : 'désactivé'}',
        icon: Icons.tune_rounded,
        onEdit: () => setState(() => _step = 4),
      ),
      const SizedBox(height: 14),
      Text(
        'L’inscription du compte responsable sera la dernière étape.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _footer(BuildContext context) {
    final isWelcome = _step == 0;
    final isReview = _step == 5;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _next,
                child: Text(
                  isWelcome
                      ? 'Créer ma boutique'
                      : isReview
                      ? 'Continuer vers l’inscription'
                      : 'Continuer',
                ),
              ),
            ),
            if (_step == 3 || _step == 4)
              TextButton(
                onPressed: _skip,
                child: const Text('Passer cette étape'),
              ),
            if (isWelcome)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Quelques étapes suffisent pour commencer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().length < 2
      ? 'Ce champ est obligatoire.'
      : null;

  String? _validatePhone(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    return digits.length >= 8 && digits.length <= 15
        ? null
        : 'Entrez un numéro de téléphone valide.';
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return GetUtils.isEmail(value.trim()) ? null : 'Adresse e-mail invalide.';
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 5),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    ),
  );
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.trailing,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        TextButton(onPressed: onEdit, child: const Text('Modifier')),
      ],
    ),
  );
}
