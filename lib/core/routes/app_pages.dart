import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../modules/cashier/bindings/cashier_binding.dart';
import '../../modules/cashier/views/cart_view.dart';
import '../../modules/cashier/views/cashier_view.dart';
import '../../modules/auth/views/login_view.dart';
import '../../modules/auth/views/register_view.dart';
import '../../modules/auth/views/password_recovery_view.dart';
import '../../modules/auth/views/shop_setup_view.dart';
import '../../modules/auth/views/shop_success_view.dart';
import '../../modules/clients/bindings/clients_binding.dart';
import '../../modules/clients/views/clients_view.dart';
import '../../modules/expenses/bindings/expenses_binding.dart';
import '../../modules/expenses/views/expenses_view.dart';
import '../../modules/home/bindings/home_binding.dart';
import '../../modules/home/views/home_view.dart';
import '../../modules/products/bindings/products_binding.dart';
import '../../modules/products/views/products_view.dart';
import '../../modules/stock/bindings/stock_binding.dart';
import '../../modules/stock/views/stock_view.dart';
import '../../modules/sales/bindings/sales_binding.dart';
import '../../modules/sales/views/sale_confirmation_view.dart';
import '../../modules/sales/views/sale_receipt_view.dart';
import '../../modules/settings/views/settings_view.dart';
import '../../modules/shared/views/feature_placeholder_view.dart';
import '../../modules/welcome/views/welcome_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage<void>(name: AppRoutes.welcome, page: () => const WelcomeView()),
    GetPage<void>(name: AppRoutes.shopSetup, page: () => const ShopSetupView()),
    GetPage<void>(
      name: AppRoutes.shopSuccess,
      page: () => const ShopSuccessView(),
    ),
    GetPage<void>(name: AppRoutes.login, page: () => const LoginView()),
    GetPage<void>(name: AppRoutes.register, page: () => const RegisterView()),
    GetPage<void>(
      name: AppRoutes.passwordRecovery,
      page: () => const PasswordRecoveryView(),
    ),
    GetPage<void>(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.sales,
      page: () => const CashierView(),
      binding: CashierBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.products,
      page: () => const ProductsView(),
      binding: ProductsBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.stock,
      page: () => const StockView(),
      binding: StockBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.clients,
      page: () => const ClientsView(),
      binding: ClientsBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.debts,
      page: () => const DebtsView(),
      binding: ClientsBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.expenses,
      page: () => const ExpensesView(),
      binding: ExpensesBinding(),
    ),
    _placeholder(
      AppRoutes.reports,
      'Rapports',
      'Les rapports seront disponibles dans un prochain point du planning.',
      Icons.bar_chart_outlined,
    ),
    GetPage<void>(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: HomeBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.basket,
      page: () => const CartView(),
      binding: CashierBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.saleConfirmation,
      page: () => const SaleConfirmationView(),
      binding: SalesBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.saleReceipt,
      page: () => const SaleReceiptView(),
      binding: SalesBinding(),
    ),
  ];

  static GetPage<void> _placeholder(
    String route,
    String title,
    String description,
    IconData icon,
  ) => GetPage<void>(
    name: route,
    page: () => FeaturePlaceholderView(
      title: title,
      description: description,
      icon: icon,
    ),
  );
}
