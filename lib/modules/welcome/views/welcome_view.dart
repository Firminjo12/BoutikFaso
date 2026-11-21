import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/views/auth_widgets.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(isWide: isWide)),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 24 : 20,
                      30,
                      isWide ? 24 : 20,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isWide)
                          const _DesktopHero()
                        else
                          const _MobileHero(),
                        const SizedBox(height: 26),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final count = constraints.maxWidth >= 850
                                ? 4
                                : constraints.maxWidth >= 560
                                ? 2
                                : 1;
                            return GridView.count(
                              crossAxisCount: count,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: count == 1 ? 3.3 : 1.65,
                              children: const [
                                _FeatureCard(
                                  icon: Icons.point_of_sale_outlined,
                                  title: 'Caisse en 3 clics',
                                  body: 'Espèces, Orange Money ou Moov Money, avec reçus simples.',
                                  tint: AppColors.surfaceTint,
                                  color: AppColors.success,
                                ),
                                _FeatureCard(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Stock toujours à jour',
                                  body: 'Chaque vente et mouvement met votre stock à jour.',
                                  tint: Color(0xFFE8F7EE),
                                  color: AppColors.success,
                                ),
                                _FeatureCard(
                                  icon: Icons.menu_book_outlined,
                                  title: 'Carnet de dettes clair',
                                  body: 'Suivez les crédits, remboursements et soldes clients.',
                                  tint: Color(0xFFEAF1FF),
                                  color: Color(0xFF3972C6),
                                ),
                                _FeatureCard(
                                  icon: Icons.wifi_off_rounded,
                                  title: 'Pas de vente en ligne',
                                  body: 'Boutik Faso vous aide à gérer votre commerce physique, ses ventes et ses crédits.',
                                  tint: Color(0xFFEAF1FF),
                                  color: Color(0xFF3972C6),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Boutik Faso · Votre boutique, mieux organisée.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Conçu pour les commerçants du Burkina Faso',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 20,
            vertical: 14,
          ),
          child: Row(
            children: [
              const AuthBrand(compact: true),
              const Spacer(),
              if (isWide) ...[
                TextButton(
                  onPressed: () => Get.toNamed<void>(AppRoutes.login),
                  child: const Text('Se connecter'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Get.toNamed<void>(AppRoutes.shopSetup),
                  child: const Text('Créer ma boutique'),
                ),
              ] else
                TextButton(
                  onPressed: () => Get.toNamed<void>(AppRoutes.login),
                  child: const Text('Connexion'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DesktopHero extends StatelessWidget {
  const _DesktopHero();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        flex: 6,
        child: Padding(
          padding: const EdgeInsets.only(right: 44, top: 18, bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _OfflinePill(),
              const SizedBox(height: 16),
              Text(
                'Gérez votre boutique simplement, sans cahier ni calculatrice.',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 38, height: 1.15),
              ),
              const SizedBox(height: 12),
              Text(
                'Boutik Faso aide les commerçants au Burkina Faso à suivre leur stock, enregistrer leurs ventes et gérer les crédits clients. Les ventes se font directement dans votre commerce.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.55),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => Get.toNamed<void>(AppRoutes.shopSetup),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Commencer gratuitement'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(210, 48),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Get.toNamed<void>(AppRoutes.login),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(150, 48),
                    ),
                    child: const Text('J’ai déjà un compte'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const Expanded(flex: 5, child: _ShopPreview()),
    ],
  );
}

class _MobileHero extends StatelessWidget {
  const _MobileHero();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _OfflinePill(),
      const SizedBox(height: 14),
      Text(
        'Votre boutique organisée.',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontSize: 30),
      ),
      const SizedBox(height: 8),
      Text(
        'Enregistrez vos ventes, suivez votre stock et gardez une trace des crédits clients depuis votre téléphone.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: () => Get.toNamed<void>(AppRoutes.shopSetup),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: const Text('Créer ma boutique'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Get.toNamed<void>(AppRoutes.login),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: const Text('J’ai déjà une boutique'),
      ),
    ],
  );
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
          SizedBox(width: 6),
          Text(
            'Gestion de votre commerce au quotidien',
            style: TextStyle(fontSize: 12, color: AppColors.success),
          ),
        ],
      ),
    ),
  );
}

class _ShopPreview extends StatelessWidget {
  const _ShopPreview();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Épicerie Wend-Panga',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Exemple de journée en caisse',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const _PreviewTag('Ma boutique'),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _PreviewMetric(
                  label: 'Ventes du jour',
                  value: '48 500 F',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _PreviewMetric(
                  label: 'Crédits à suivre',
                  value: '14 200 F',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: AppColors.success,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ventes enregistrées dans la boutique',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '7 ventes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.success),
      ),
    ),
  );
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.tint,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
