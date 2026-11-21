import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import 'auth_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _auth = Get.find<AuthController>();

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _auth.login(phone: _phoneController.text, pin: _pinController.text);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: isMobile
          ? AppBar(
              leading: IconButton(
                onPressed: () => Get.offAllNamed<void>(AppRoutes.welcome),
                icon: const Icon(Icons.arrow_back),
              ),
              title: const AuthBrand(compact: true),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile) ...[
                  const AuthBrand(),
                  const SizedBox(height: 18),
                ],
                Text(
                  'Connexion à BoutikFaso',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Accédez à votre boutique et à vos ventes.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                AuthCard(
                  width: 430,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Numéro de téléphone',
                            hintText: '+226 70 22 44 11',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) {
                            final digits =
                                value?.replaceAll(RegExp(r'\D'), '') ?? '';
                            if (digits.length < 8 || digits.length > 15) {
                              return 'Entrez un numéro de téléphone valide.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        PinField(controller: _pinController),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                Get.toNamed<void>(AppRoutes.passwordRecovery),
                            child: const Text('Code oublié ?'),
                          ),
                        ),
                        Obx(() {
                          final error = _auth.errorMessage.value;
                          if (error.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              error,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          );
                        }),
                        Obx(
                          () => SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _auth.isBusy.value ? null : _submit,
                              child: _auth.isBusy.value
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Se connecter'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              const Text('Nouvelle boutique ? '),
                              TextButton(
                                onPressed: () =>
                                    Get.toNamed<void>(AppRoutes.shopSetup),
                                child: const Text('Créer ma boutique'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
