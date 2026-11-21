import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import 'auth_widgets.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _auth = Get.find<AuthController>();
  late final String _merchantName;
  late final String _address;
  late final String? _email;
  late final Map<String, dynamic> _shopSetup;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    final data = arguments is Map ? arguments : const <String, dynamic>{};
    _shopSetup = Map<String, dynamic>.from(data);
    _merchantName = data['merchant_name']?.toString() ?? '';
    _address = data['merchant_address']?.toString() ?? '';
    _email = data['email']?.toString();
    _fullName.text = data['manager_name']?.toString() ?? '';
    _phone.text = data['merchant_phone']?.toString() ?? '';
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _auth.register(
      merchantName: _merchantName,
      fullName: _fullName.text,
      address: _address,
      phone: _phone.text,
      pin: _pin.text,
      email: _email,
      shopSetup: _shopSetup,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    return Scaffold(
      appBar: isMobile
          ? AppBar(
              leading: IconButton(
                onPressed: () => Get.back<void>(),
                icon: const Icon(Icons.arrow_back),
              ),
              title: const AuthBrand(compact: true),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 18 : 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile) ...[
                  const AuthBrand(),
                  const SizedBox(height: 20),
                ],
                const _RegistrationStepLabel(),
                const SizedBox(height: 14),
                Text(
                  'Créer votre compte commerçant',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ces informations vous permettront de vous connecter à Boutik Faso.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                AuthCard(
                  width: 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ShopSummary(name: _merchantName, address: _address),
                      const SizedBox(height: 18),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _fullName,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Votre nom complet',
                                hintText: 'Ex. : Moussa Kaboré',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+ ]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Numéro de téléphone',
                                hintText: '+226 70 00 00 00',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: _validatePhone,
                            ),
                            const SizedBox(height: 14),
                            PinField(controller: _pin),
                            const SizedBox(height: 10),
                            Obx(() {
                              final error = _auth.errorMessage.value;
                              if (error.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  error,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              );
                            }),
                            Obx(
                              () => SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: _auth.isBusy.value
                                      ? null
                                      : _submit,
                                  child: _auth.isBusy.value
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Créer mon compte et ma boutique',
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  const Text('Vous avez déjà un compte ? '),
                                  TextButton(
                                    onPressed: () =>
                                        Get.offNamed<void>(AppRoutes.login),
                                    child: const Text('Se connecter'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
}

class _RegistrationStepLabel extends StatelessWidget {
  const _RegistrationStepLabel();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'INSCRIPTION DU RESPONSABLE',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ShopSummary extends StatelessWidget {
  const _ShopSummary({required this.name, required this.address});

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.store_outlined, color: AppColors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Votre boutique' : name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(address, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Get.back<void>(),
          child: const Text('Modifier'),
        ),
      ],
    ),
  );
}
