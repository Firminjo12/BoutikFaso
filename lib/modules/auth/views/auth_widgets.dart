import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 32 : 38,
        height: compact ? 32 : 38,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          Icons.storefront_rounded,
          size: compact ? 19 : 22,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 9),
      Text(
        'Boutik Faso',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.text),
      ),
    ],
  );
}

class PinField extends StatefulWidget {
  const PinField({required this.controller, this.validator, super.key});

  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscure,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    textInputAction: TextInputAction.done,
    maxLength: 6,
    decoration: InputDecoration(
      labelText: 'Code PIN',
      counterText: '',
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Afficher le code' : 'Masquer le code',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator:
        widget.validator ??
        (value) {
          if (value == null ||
              value.length != 6 ||
              int.tryParse(value) == null) {
            return 'Saisissez les 6 chiffres de votre code.';
          }
          return null;
        },
  );
}

class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, this.width = 440, super.key});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: Card(
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}
