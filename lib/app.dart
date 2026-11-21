import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/controllers/auth_controller.dart';
import 'modules/auth/repositories/auth_repository.dart';

class BoutikFasoApp extends StatelessWidget {
  const BoutikFasoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Boutik Faso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.welcome,
      initialBinding: BindingsBuilder(() {
        Get.put<AuthRepository>(AuthRepository(), permanent: true);
        Get.put<AuthController>(
          AuthController(repository: Get.find<AuthRepository>()),
          permanent: true,
        );
      }),
      getPages: AppPages.pages,
    );
  }
}
