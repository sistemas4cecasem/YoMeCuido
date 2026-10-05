import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'privacy_partner_links.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_scaffold.dart';

class PrivacyNoticeScreen extends StatefulWidget {
  const PrivacyNoticeScreen({this.onDeleteAccount, super.key});

  final VoidCallback? onDeleteAccount;

  @override
  State<PrivacyNoticeScreen> createState() => _PrivacyNoticeScreenState();
}

class _PrivacyNoticeScreenState extends State<PrivacyNoticeScreen> {
  late Future<_PrivacyNotice> _notice = _loadNotice();

  Future<_PrivacyNotice> _loadNotice() async {
    final source = await rootBundle.loadString(
      'assets/data/privacy_notice.json',
    );
    final data = jsonDecode(source) as Map<String, dynamic>;
    final sections = data['sections'] as List<dynamic>;
    return _PrivacyNotice(
      title: data['title'] as String,
      intro: data['intro'] as String,
      sections: sections
          .map((entry) {
            final section = entry as Map<String, dynamic>;
            return _PrivacySection(
              title: section['title'] as String,
              body: section['body'] as String,
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.privacyTitle,
      child: FutureBuilder<_PrivacyNotice>(
        future: _notice,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(AppStrings.contentLoadError),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () => setState(() => _notice = _loadNotice()),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text(AppStrings.retry),
                  ),
                ],
              ),
            );
          }
          final notice = snapshot.data;
          if (notice == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              Text(
                notice.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(notice.intro),
              const SizedBox(height: AppSpacing.md),
              for (final section in notice.sections) ...[
                Card(
                  child: Padding(
                    padding: AppInsets.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(section.body),
                        if (section.title == 'Responsable y contacto') ...[
                          const SizedBox(height: AppSpacing.md),
                          const PrivacyPartnerLinks(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (widget.onDeleteAccount != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: widget.onDeleteAccount,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text(AppStrings.deleteAccount),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _PrivacyNotice {
  const _PrivacyNotice({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<_PrivacySection> sections;
}

class _PrivacySection {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;
}
