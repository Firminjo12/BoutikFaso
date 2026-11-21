import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_widgets.dart';

class PasswordRecoveryView extends StatefulWidget {
  const PasswordRecoveryView({super.key});

  @override
  State<PasswordRecoveryView> createState() => _PasswordRecoveryViewState();
}

class _PasswordRecoveryViewState extends State<PasswordRecoveryView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  int _step = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  void _savePin() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Get.snackbar(
      'Réinitialisation indisponible',
      'Le service de récupération n’est pas encore connecté. Votre PIN n’a pas été modifié.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.text,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    return Scaffold(
      appBar: isMobile
          ? AppBar(
              leading: IconButton(
                onPressed: _step == 0
                    ? Get.back
                    : () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back),
              ),
              title: const AuthBrand(compact: true),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (!isMobile) _DesktopHeader(onLogin: _backToLogin),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMobile) ...[
                        const AuthBrand(),
                        const SizedBox(height: 20),
                      ],
                      _Progress(step: _step),
                      const SizedBox(height: 20),
                      AuthCard(
                        width: 430,
                        child: Form(
                          key: _formKey,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: switch (_step) {
                              0 => _phoneStep(),
                              1 => _codeStep(),
                              _ => _pinStep(),
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 430,
                        child: Text(
                          'Parcours d’interface : aucun SMS n’est envoyé et le PIN ne sera pas changé tant que le service backend ne sera pas connecté.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isMobile)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Boutik Faso · Gestion sécurisée de votre boutique',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _phoneStep() => Column(
    key: const ValueKey('phone'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Récupérer mon compte',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Réinitialisez le code PIN associé à votre compte. Nous vous enverrons un code de vérification.',
      ),
      const SizedBox(height: 20),
      const Text('Numéro de téléphone'),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('+226'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              autofocus: false,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              decoration: const InputDecoration(
                hintText: '70 22 44 11',
                counterText: '',
              ),
              validator: (value) => (value?.length ?? 0) == 8
                  ? null
                  : 'Entrez les 8 chiffres du numéro.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      FilledButton(onPressed: _continue, child: const Text('Recevoir le code')),
      const Divider(height: 28),
      TextButton(
        onPressed: _backToLogin,
        child: const Text('Retour à la connexion'),
      ),
    ],
  );

  Widget _codeStep() => Column(
    key: const ValueKey('code'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Vérifier votre numéro',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text('Saisissez le code SMS envoyé au +226 ${_phoneController.text}.'),
      const SizedBox(height: 20),
      const Text('Code de vérification'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 6,
        decoration: const InputDecoration(
          hintText: '••••••',
          counterText: '',
          prefixIcon: Icon(Icons.sms_outlined),
        ),
        validator: (value) => (value?.length ?? 0) == 6
            ? null
            : 'Saisissez les 6 chiffres du code.',
      ),
      const SizedBox(height: 14),
      FilledButton(onPressed: _continue, child: const Text('Vérifier le code')),
      TextButton(
        onPressed: () => setState(() => _step = 0),
        child: const Text('Modifier le numéro'),
      ),
    ],
  );

  Widget _pinStep() => Column(
    key: const ValueKey('new-pin'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Choisissez un nouveau code PIN',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Créez un nouveau code à 6 chiffres pour protéger votre compte.',
      ),
      const SizedBox(height: 20),
      const Text('Nouveau code PIN'),
      const SizedBox(height: 8),
      PinField(controller: _pinController),
      const SizedBox(height: 16),
      const Text('Confirmer le code PIN'),
      const SizedBox(height: 8),
      PinField(
        controller: _confirmationController,
        validator: (value) => value == _pinController.text
            ? null
            : 'Les deux codes PIN doivent être identiques.',
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _savePin,
        child: const Text('Enregistrer mon nouveau code'),
      ),
      const Divider(height: 28),
      TextButton(
        onPressed: _backToLogin,
        child: const Text('Retour à la connexion'),
      ),
    ],
  );

  void _backToLogin() => Get.offNamed<void>(AppRoutes.login);
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1160),
      child: Row(
        children: [
          const AuthBrand(compact: true),
          const Spacer(),
          TextButton(
            onPressed: onLogin,
            child: const Text('Retour à la connexion'),
          ),
        ],
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['1. Numéro', '2. Code SMS', '3. Nouveau PIN'];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: index == step ? AppColors.surface : AppColors.background,
              border: Border.all(
                color: index == step ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: index == step ? FontWeight.w700 : FontWeight.w500,
                color: index == step ? AppColors.primary : AppColors.muted,
              ),
            ),
          ),
      ],
    );
  }
}
