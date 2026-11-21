import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_widgets.dart';

class ShopSuccessView extends StatelessWidget {
  const ShopSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final raw = Get.arguments;
    final data = raw is Map ? raw : const <String, dynamic>{};
    final name = data['merchant_name']?.toString() ?? 'Votre boutique';
    final type = data['business_type']?.toString() ?? 'Commerce';
    final manager = data['manager_name']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final district = data['district']?.toString() ?? '';
    final location = [
      city,
      district,
    ].where((part) => part.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(title: const AuthBrand(compact: true)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LinearProgressIndicator(
                    value: 1,
                    minHeight: 4,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  const SizedBox(height: 20),
                  const _SuccessStepLabel(),
                  const SizedBox(height: 14),
                  const _SuccessMark(),
                  const SizedBox(height: 22),
                  Text(
                    'Votre boutique est prête !',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tout est configuré pour suivre vos ventes, vos stocks et vos clients en toute sérénité.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  AuthCard(
                    width: 500,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    type,
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _SummaryLine(label: 'Responsable', value: manager),
                        const SizedBox(height: 8),
                        _SummaryLine(label: 'Localisation', value: location),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 500,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Get.offAllNamed<void>(AppRoutes.home),
                      child: const Text('Accéder à ma boutique'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Vous pourrez modifier ces informations à tout moment dans les paramètres.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessStepLabel extends StatelessWidget {
  const _SuccessStepLabel();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'ÉTAPE 7 SUR 7',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 88,
    height: 88,
    decoration: const BoxDecoration(
      color: AppColors.surfaceTint,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.check_circle_rounded,
      color: AppColors.success,
      size: 60,
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(
        child: Text(
          value.isEmpty ? '—' : value,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    ],
  );
}
