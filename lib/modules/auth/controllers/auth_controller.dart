import 'package:get/get.dart';

import '../../../core/workspace/merchant_workspace_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../home/bindings/home_binding.dart';
import '../repositories/auth_repository.dart';

class AuthController extends GetxController {
  AuthController({required this.repository});

  final AuthRepository repository;
  final isBusy = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      if (await repository.restoreSession() &&
          Get.currentRoute == AppRoutes.welcome) {
        Get.offAllNamed<void>(AppRoutes.home);
      }
    } on Object {
      // La page d’accueil reste disponible si le stockage sécurisé est inaccessible.
    }
  }

  Future<bool> login({required String phone, required String pin}) async {
    errorMessage.value = '';
    isBusy.value = true;
    try {
      await repository.login(phone: phone, pin: pin);
      Get.offAllNamed<void>(AppRoutes.home);
      return true;
    } on Object catch (error) {
      errorMessage.value = AuthRepository.messageFor(error);
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> register({
    required String merchantName,
    required String fullName,
    required String address,
    required String phone,
    required String pin,
    String? email,
    Map<String, dynamic>? shopSetup,
  }) async {
    errorMessage.value = '';
    isBusy.value = true;
    try {
      await repository.register(
        merchantName: merchantName,
        fullName: fullName,
        address: address,
        phone: phone,
        pin: pin,
        email: email,
      );
      final setup = shopSetup ?? <String, dynamic>{};
      HomeBinding().dependencies();
      Get.find<MerchantWorkspaceController>().updateWorkspaceSettings(
        name: merchantName,
        phone: phone,
        location: setup['merchant_address']?.toString() ?? address,
        currencyCode: setup['currency']?.toString() ?? 'XOF',
        lowStockThreshold: setup['stock_threshold'] as int?,
        acceptedPaymentMethods: (setup['payment_methods'] as List?)
            ?.cast<String>(),
        creditSalesEnabled: setup['credit_enabled'] as bool?,
      );
      Get.offAllNamed<void>(
        AppRoutes.shopSuccess,
        arguments: setup.isEmpty
            ? <String, dynamic>{'merchant_name': merchantName}
            : setup,
      );
      return true;
    } on Object catch (error) {
      errorMessage.value = AuthRepository.messageFor(error);
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> logout() async {
    await repository.clearSession();
    Get.offAllNamed<void>(AppRoutes.welcome);
  }

  void clearError() => errorMessage.value = '';
}
