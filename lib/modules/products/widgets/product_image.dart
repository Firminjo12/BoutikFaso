import 'dart:io';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.imagePath,
    required this.placeholder,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? imagePath;
  final Widget placeholder;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null || path.isEmpty) return placeholder;
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
