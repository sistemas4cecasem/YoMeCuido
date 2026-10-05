import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_spacing.dart';

class PrivacyPartnerLinks extends StatelessWidget {
  const PrivacyPartnerLinks({super.key});

  Future<void> _openWebsite(BuildContext context, String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // A missing browser or platform error should not interrupt the notice.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir el sitio web. Intenta nuevamente.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _logo(
          context,
          'CECASEM',
          'assets/images/brand/cecasem_logo.png',
          'https://cecasem.com/',
        ),
        const SizedBox(width: AppSpacing.md),
        _logo(
          context,
          'Observatorio de Trata de Personas',
          'assets/images/brand/observatorio_logo.png',
          'https://observatoriotratabolivia.org/',
        ),
      ],
    );
  }

  Widget _logo(BuildContext context, String name, String asset, String url) {
    return Expanded(
      child: Semantics(
        link: true,
        label: 'Abrir sitio web de $name en el navegador',
        child: Tooltip(
          message: 'Visitar $name',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: () => _openWebsite(context, url),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Image.asset(
                asset,
                height: 80,
                width: double.infinity,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
