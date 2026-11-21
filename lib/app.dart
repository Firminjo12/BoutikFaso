import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

class BoutikFasoApp extends StatelessWidget {
  const BoutikFasoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Boutik Faso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
    );
  }
}
